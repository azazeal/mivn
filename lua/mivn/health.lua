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
-- knows the servers the config ships; a `probe` field under the `lsp`
-- overrides in local.lua wins over it for that server.
local PROBES = {
  ["gopls"] = { "version" },
  ["templ"] = { "version" },
  ["terraform-ls"] = { "version" },

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

--- The probe for `server` running as `binary`: the override's `probe`
--- field when it is set, the built-in table otherwise. Managed binaries
--- arrive as absolute paths while the table is keyed by name, hence the
--- basename fallback.
local function probe_for(server, binary)
  local o = (require("mivn.overrides").lsp or {})[server]
  if type(o) == "table" and o.probe ~= nil then
    return o.probe
  end

  local probe = PROBES[binary]
  if probe == nil then
    probe = PROBES[vim.fs.basename(binary)]
  end

  return probe
end

--- Probe one binary; report through vim.health.
---
--- The healthy rows go through info, not ok, on purpose: vim.health.ok
--- hard-codes "✅ OK" in front of the message, so every row would read
--- "OK name" when the section is a table scanned by name. Info rows keep
--- the name first; the loud levels, prefix and all, are kept for rows
--- that are actually trouble.
local function check_binary(label, binary, probe)
  local health = vim.health

  local path = vim.fn.exepath(binary)
  if path == "" then
    health.info(("%s: off (%s is not on PATH)"):format(label, binary))
    return
  end

  if probe == false then
    health.info(("%s: found at %s; it has no version flag to probe"):format(label, path))
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

  health.info(("%s: %s"):format(label, first_line(result.stdout, result.stderr, path)))
end

--- The Go language version named anywhere in `text`, patch dropped, or nil.
--- Both `go version` and gopls answer with a `go1.26.5` somewhere in a line.
local function go_language_version(text)
  local found = (text or ""):match("go(%d+%.%d+)")
  return found and vim.version.parse(found, { strict = false }) or nil
end

--- Whether gopls can understand the toolchain it is pointed at.
---
--- gopls type-checks with the go/types compiled into it, so the Go that built
--- it sets the language version ceiling, whatever the project asks for. A
--- gopls behind its toolchain reports errors on code that builds, and says
--- nothing about why: measured 2026-08-14, gopls built with go1.24.6 calls
--- `new(42)` "42 is not a type" in a module declaring go 1.26, which compiles
--- and runs. Nothing in gopls warns about this; its own version policy only
--- looks for a Go that is too old.
---
--- Newer is fine in the other direction, since go/types applies the rules of
--- the version in go.mod, so this only ever compares the two minors.
local function check_gopls_toolchain()
  local health = vim.health

  if vim.fn.exepath("gopls") == "" or vim.fn.exepath("go") == "" then
    return
  end

  --- What `cmd` printed, or nil unless it ran and succeeded.
  local function output(cmd)
    local ok, result = pcall(function()
      return vim.system(cmd, { text = true }):wait(5000)
    end)

    return ok and result.code == 0 and result.stdout or nil
  end

  -- gopls carries the Go it was built with in its own version report; the
  -- workspace's is whatever `go` PATH resolves to, which is mise's answer.
  local reported = output({ "gopls", "version", "-json" })
  local decoded = reported and select(2, pcall(vim.json.decode, reported))

  local built = type(decoded) == "table" and go_language_version(decoded.GoVersion)
  local using = go_language_version(output({ "go", "version" }))

  if not built or not using then
    return
  end

  if vim.version.lt(built, using) then
    health.warn(
      ("gopls was built with Go %d.%d and this workspace runs %d.%d"):format(
        built.major,
        built.minor,
        using.major,
        using.minor
      ),
      "It cannot type-check the newer language, and the errors it invents blame your code. Rebuild it: `mise install --force go:golang.org/x/tools/gopls`"
    )
  else
    health.info(
      ("gopls was built with Go %d.%d, and this workspace runs %d.%d"):format(
        built.major,
        built.minor,
        using.major,
        using.minor
      )
    )
  end
end

function M.check()
  local health = vim.health
  local lsp = require("mivn.lsp")
  local store = require("mivn.store")
  local managed = require("mivn.lsp.managed")

  health.start("mivn")
  local update = require("mivn.update").report()
  if not update.current then
    health.info("no release tag here, so this config is not checked for updates")
  elseif not update.latest then
    health.info(("%s; the remote has not answered yet"):format(update.current))
  elseif vim.version.gt(update.latest, update.current) then
    health.warn(
      ("%s is out, and this is %s"):format(update.latest, update.current),
      ":MivnUpdate takes it, then :restart"
    )
  else
    health.ok(("%s, the newest release"):format(update.current))
  end

  health.start("the workspace's environment")
  local mise = require("mivn.env")
  local env = mise.state()

  if vim.fn.executable("mise") ~= 1 then
    health.info("mise is not here, so this environment is whatever started Neovim")
  elseif #env.asks > 0 then
    for _, root in ipairs(env.asks) do
      health.warn(("%s is not trusted"):format(vim.fn.fnamemodify(root, ":~")), ":MivnEnv asks about it")
    end
  else
    health.ok(("mise, read in %.0fms: %d variables set"):format(env.ms, vim.tbl_count(env.applied)))

    -- Which version of what, so "the server disagrees with my terminal" has
    -- an answer here instead of in a second shell.
    for name, versions in vim.spairs(mise.tools() or {}) do
      local first = versions[1] or {}
      local missing = first.installed == false and "; not installed, `mise install` fetches it" or ""
      health.info(("%s: %s%s"):format(name, first.version or "?", missing))
    end
  end

  health.start("managed language servers")
  local target, why = store.supported()
  if not target then
    health.warn("this host is unsupported: " .. why, "the `path` escape hatch under `lsp` in local.lua still works")
  else
    health.ok("platform " .. target)
    for _, tool in ipairs({ "curl", "tar" }) do
      if vim.fn.executable(tool) ~= 1 then
        health.error(("%s is missing, and installs need it"):format(tool))
      end
    end
  end

  -- Which of them run confined, so a sandbox that quietly stopped applying
  -- is visible rather than assumed.
  local sandbox = require("mivn.sandbox")
  local confined = {}
  for name in vim.spairs(store.manifest) do
    if sandbox.covers(name) then
      confined[#confined + 1] = name
    end
  end

  if #confined == 0 then
    health.warn("nothing is sandboxed", "mise is what applies it; `sandbox = false` in local.lua turns it off")
  else
    health.ok(("sandboxed: %s"):format(table.concat(confined, ", ")))
  end

  for name in vim.spairs(store.manifest) do
    local cmd = store.resolve(name)
    if cmd then
      check_binary(name, cmd[1], probe_for(name, cmd[1]))
    else
      health.info(("%s: %s"):format(name, managed.state(name)))
    end
  end

  health.start("language servers on PATH")
  for server, binary in vim.spairs(lsp.servers) do
    check_binary(server, binary, probe_for(server, binary))
  end

  check_gopls_toolchain()

  health.start("clients in this session")
  local clients = vim.lsp.get_clients()
  if #clients == 0 then
    health.info("none attached; open a file a server covers, then rerun")
  end
  -- info for the same reason check_binary uses it: these rows scan by name.
  for _, client in ipairs(clients) do
    health.info(("%s, rooted at %s"):format(client.name, client.root_dir or "(no root)"))
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
      check_binary(ft, binary, PROBES[binary])
    end
  end
  -- gci is additional, not essential: gopls already formats and organizes
  -- imports, gci only re-groups them into the configured blocks.
  check_binary("gci", "gci", PROBES["gci"])
end

return M
