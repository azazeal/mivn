-- :checkhealth mivn: does the language-server setup actually work?
--
-- The trap this exists for: executable() answers "is there a file", not
-- "does it run". A rustup shim with no component behind it is an executable
-- that recurses until rustup gives up, so the server table said on while
-- nothing worked. Each installed binary is run once here, with a version
-- flag and a timeout, and what it answers is what gets reported.

local M = {}

-- How to ask each binary for its version. Most take --version; the ones
-- that differ are named, and `false` means the binary has no harmless
-- one-shot flag at all, so it is only looked up, never run. This table only
-- knows the servers the config ships; local.lua's `lsp_probes` merges over
-- it, so a server added there can bring its own flag (or a `false`) along.
local PROBES = {
  ["gopls"] = { "version" },
  ["templ"] = { "version" },

  -- Not --version: superhtml prints "unrecognized subcommand" for it and
  -- still exits 0, which would read as its version line.
  ["superhtml"] = { "version" },

  ["expert"] = false,
  ["golangci-lint-langserver"] = false,
}

--- The first line worth showing from a probe's output.
local function first_line(...)
  for _, text in ipairs({ ... }) do
    for line in (text or ""):gmatch("[^\r\n]+") do
      line = vim.trim(line)
      if line ~= "" then
        return line
      end
    end
  end

  return ""
end

local probes = vim.tbl_extend("force", PROBES, require("mivn.overrides").lsp_probes or {})

--- Probe one binary; report through vim.health.
local function check_binary(label, binary)
  local health = vim.health

  local path = vim.fn.exepath(binary)
  if path == "" then
    health.info(("%s: off (%s is not on PATH)"):format(label, binary))
    return
  end

  local probe = probes[binary]
  if probe == false then
    health.ok(("%s: %s (found; it has no version flag to probe)"):format(label, path))
    return
  end

  local cmd = { path, unpack(probe or { "--version" }) }
  local ok, result = pcall(function()
    return vim.system(cmd, { text = true, timeout = 3000 }):wait()
  end)

  if not ok then
    health.error(("%s: %s failed to start: %s"):format(label, binary, result))
    return
  end

  if result.signal ~= 0 then
    health.warn(
      ("%s: %s answered nothing within 3s"):format(label, binary),
      "It may not support a version flag, or it may hang; try running it by hand."
    )
    return
  end

  if result.code ~= 0 then
    health.warn(
      ("%s: %s exited %d: %s"):format(label, binary, result.code, first_line(result.stderr, result.stdout)),
      "A wrapper can be broken while the file itself is executable; rustup shims do this."
    )
    return
  end

  health.ok(("%s: %s"):format(label, first_line(result.stdout, result.stderr, path)))
end

function M.check()
  local health = vim.health
  local lsp = require("mivn.lsp")

  health.start("language servers")
  for server, binary in vim.spairs(lsp.servers) do
    check_binary(server, binary)
  end

  health.start("clients in this session")
  local clients = vim.lsp.get_clients()
  if #clients == 0 then
    health.info("none attached; open a file a server covers, then rerun")
  end
  for _, client in ipairs(clients) do
    health.ok(("%s, rooted at %s"):format(client.name, client.root_dir or "(no root)"))
  end

  health.start("external formatters")
  local seen = {}
  for ft, spec in vim.spairs(lsp.formatters) do
    if type(spec) == "function" then
      spec = spec(0)
    end

    local binary = spec and spec[1]
    if binary and not seen[binary] then
      seen[binary] = true
      check_binary(ft, binary)
    end
  end
  check_binary("go imports", "gci")
end

return M
