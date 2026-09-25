-- Which JSON Schema belongs to which file.
--
-- yaml-language-server carries SchemaStore's catalog itself, so a file it knows
-- by name validates the moment it opens. vscode-json-language-server does not,
-- since in VS Code the catalog comes from the extension around it: on its own
-- it validates a file with a `$schema` key and nothing else. This is that
-- missing half, SchemaStore's catalog cached on disk.
--
-- The network is never on the startup path. The cache is read if it is there
-- and refreshed in the background when it is stale, so a first run goes without
-- name-matched schemas and nothing else.

local M = {}

local CATALOG = "https://www.schemastore.org/api/json/catalog.json"
local CACHE = vim.fs.joinpath(vim.fn.stdpath("cache"), "schemastore.json")
local TTL = 7 * 24 * 60 * 60

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

--- Fetch the catalog into the cache, atomically, and say nothing either way: a
--- machine with no network keeps whatever it already had, and a first run
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

      -- parsed before it is kept, so a captive portal's login page is never the
      -- catalog
      local ok = pcall(vim.json.decode, slurp(staging) or "")
      if ok then
        vim.uv.fs_rename(staging, CACHE)
      else
        vim.uv.fs_unlink(staging)
      end
    end
  )
end

--- The catalog as vscode-json-language-server wants it under `json.schemas`: a
--- list of `{ fileMatch, url }`, empty until the first fetch lands. Entries
--- without a fileMatch are for `$schema` alone, which the server handles.
--- Reading it (470KB, some 1400 entries) is a startup cost, so ask only as the
--- server starts.
function M.json()
  if stale() then
    vim.schedule(refresh)
  end

  -- decode raises on the empty string a first run reads
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
