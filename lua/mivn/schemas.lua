-- Which JSON Schema belongs to which file.
--
-- Three things can associate a schema with a document, and only the first
-- comes free: a `$schema` key inside the file, a catalog matching the file's
-- name, or a hand-written mapping. yaml-language-server carries the catalog
-- itself, so a workflow file validates the moment it opens. The JSON server
-- does not: it is the same server VS Code uses, and in VS Code the catalog
-- comes from the extension around it, which is why a bare
-- vscode-json-language-server validates a file with `$schema` and ignores
-- `package.json` entirely (measured 2026-08-15).
--
-- So this is that missing half: SchemaStore's catalog, cached on disk, handed
-- to the server as `json.schemas`. Zed does the same thing by vendoring a
-- snapshot of it; VS Code downloads it.
--
-- Never on the startup path. The cache is read if it is there, refreshed in
-- the background when it is stale, and absent on a first run, which costs
-- that one session its name-matched schemas and nothing else. 470KB, a
-- little over 1400 entries.

local M = {}

local CATALOG = "https://www.schemastore.org/api/json/catalog.json"
local CACHE = vim.fs.joinpath(vim.fn.stdpath("cache"), "schemastore.json")
local TTL = 7 * 24 * 60 * 60

--- The same catalog, with one string changed, for taplo.
---
--- taplo cannot read the catalog as published. It checks the catalog's own
--- `$schema` field against a URL compiled into it, SchemaStore moved from
--- json.schemastore.org to www.schemastore.org, and the comparison is an
--- equality test, so every TOML file loses its schema:
---
---   failed to fetch catalog error=error decoding response body:
---   data did not match any variant of untagged enum SchemaCatalog
---
--- Fixed upstream on 2026-07-28 (`fix: update schemastore URL`) and not in
--- any release: taplo's newest is 0.10.0, from 2025-05-23, thirteen commits
--- behind. So this writes a copy with that one field set back to what 0.10.0
--- expects and points taplo at the file. Delete all of it the day taplo
--- releases; nothing else here depends on it.
local TAPLO = vim.fs.joinpath(vim.fn.stdpath("cache"), "schemastore-taplo.json")
local TAPLO_EXPECTS = "https://json.schemastore.org/schema-catalog.json"

local function slurp(path)
  local file = io.open(path, "r")
  if not file then
    return nil
  end

  local body = file:read("*a")
  file:close()

  return body
end

--- Whether the cached catalog is missing or old enough to replace.
local function stale()
  local stat = vim.uv.fs_stat(CACHE)
  return not stat or os.time() - stat.mtime.sec > TTL
end

--- Fetch the catalog into the cache, atomically, and say nothing either way:
--- a machine with no network keeps whatever it already had, and a first run
--- without one simply has no catalog.
local function refresh()
  if vim.fn.executable("curl") ~= 1 then
    return
  end

  local staging = CACHE .. ".new"
  vim.fn.mkdir(vim.fs.dirname(CACHE), "p")

  vim.system(
    { "curl", "--silent", "--show-error", "--fail", "--location", "--max-time", "20", "-o", staging, CATALOG },
    {
      text = true,
    },
    function(result)
      if result.code ~= 0 then
        vim.uv.fs_unlink(staging)
        return
      end

      -- Parsed before it is kept, so a captive portal's login page cannot
      -- become the catalog.
      local ok = pcall(vim.json.decode, slurp(staging) or "")
      if ok then
        vim.uv.fs_rename(staging, CACHE)
      else
        vim.uv.fs_unlink(staging)
      end
    end
  )
end

--- Write taplo's copy from the cached catalog. Cheap enough to redo whenever
--- the catalog is newer than it.
local function rewrite_for_taplo()
  local body = slurp(CACHE)
  if not body then
    return
  end

  local ok, decoded = pcall(vim.json.decode, body)
  if not ok or type(decoded) ~= "table" then
    return
  end

  decoded["$schema"] = TAPLO_EXPECTS

  local file = io.open(TAPLO, "w")
  if not file then
    return
  end

  file:write(vim.json.encode(decoded))
  file:close()
end

--- Where taplo should look, as a URL, or nil when there is no catalog yet.
function M.taplo()
  local catalog, patched = vim.uv.fs_stat(CACHE), vim.uv.fs_stat(TAPLO)
  if not catalog then
    return nil
  end

  if not patched or patched.mtime.sec < catalog.mtime.sec then
    rewrite_for_taplo()
  end

  return vim.uv.fs_stat(TAPLO) and ("file://" .. TAPLO) or nil
end

--- The catalog as vscode-json-language-server wants it under `json.schemas`:
--- a list of `{ fileMatch, url }`. Entries without a fileMatch are the ones
--- meant to be referenced by `$schema` alone, and the server finds those on
--- its own.
function M.json()
  if stale() then
    vim.schedule(refresh)
  end

  -- pcall, because decode raises on an empty string, which is what a first
  -- run reads.
  local ok, decoded = pcall(vim.json.decode, slurp(CACHE) or "", { luanil = { object = true } })
  if not ok or type(decoded) ~= "table" then
    return {}
  end

  local schemas = {}
  for _, entry in ipairs(decoded.schemas or {}) do
    if entry.url and entry.fileMatch then
      schemas[#schemas + 1] = { fileMatch = entry.fileMatch, url = entry.url }
    end
  end

  return schemas
end

return M
