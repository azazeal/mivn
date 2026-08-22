-- :checkhealth mivn: does the language-server setup actually work?
--
-- The trap this exists for: executable() answers "is there a file", not
-- "does it run". A rustup shim with no component behind it is an executable
-- that recurses until rustup gives up, so the server table said on while
-- nothing worked. Each installed binary is run once here, with a version
-- flag and a timeout, and what it answers is what gets reported.
--
-- Nothing here installs anything, so a server that is off is a tool missing
-- from the environment the editor was launched with rather than anything
-- this config can fix.

local M = {}

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
  -- workspace's is whatever `go` PATH resolves to.
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
      "It cannot type-check the newer language, and the errors it invents blame your code. Rebuild it against this toolchain."
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

  health.start("language servers")

  for name, entry in vim.spairs(lsp.servers) do
    check_binary(name, entry.binary, entry.probe)
  end

  check_gopls_toolchain()

  -- What earlier versions of this config left on disk. Nothing here deletes
  -- anything on its way out, and once the code that knew a path is gone, no
  -- other code will ever look at it again. Two retirements so far: the server
  -- store (2026-08-15), and the patched SchemaStore catalog that taplo needed
  -- before it was built from master (2026-08-16).
  local leftovers = {}
  for _, path in ipairs({
    vim.fs.joinpath(vim.fn.stdpath("data"), "servers"),
    vim.fs.joinpath(vim.fn.stdpath("state"), "lsp-consent.json"),
    vim.fs.joinpath(vim.fn.stdpath("cache"), "schemastore-taplo.json"),
  }) do
    if vim.uv.fs_stat(path) then
      leftovers[#leftovers + 1] = path
    end
  end

  if #leftovers > 0 then
    health.warn(
      ("earlier versions of this config left these behind: %s"):format(table.concat(leftovers, ", ")),
      ("Nothing reads them now; `rm -r %s` reclaims the space"):format(table.concat(leftovers, " "))
    )
  end

  health.start("tree-sitter")

  -- The failure this exists for is silent by construction. Queries are not
  -- copied into the install directory, they are symlinked into the plugin's
  -- own, so a plugin that moves leaves the parser working and every capture
  -- resolving to nothing: highlighting turns on, colours nothing, and reads
  -- as "the colorscheme forgot this language". That is what the move off
  -- lazy.nvim left behind, 30 languages deep.
  --
  -- The same comparison nvim-treesitter makes for itself (`needs_update` in
  -- its install.lua): where the link goes, against where it should go.
  -- :MivnUpdateGrammars is the repair, since update reinstalls what fails
  -- this test while install skips anything whose parser is already there.
  local grammars = require("mivn.treesitter")
  local installed = grammars.installed()
  local broken = {}

  for _, lang in ipairs(installed) do
    if not vim.uv.fs_realpath(grammars.queries_of(lang)) then
      broken[#broken + 1] = lang
    end
  end

  if #broken > 0 then
    local one = #broken == 1
    health.warn(
      ("%d %s %s a parser but no queries: %s"):format(
        #broken,
        one and "grammar" or "grammars",
        one and "has" or "have",
        table.concat(broken, ", ")
      ),
      ":MivnUpdateGrammars relinks them"
    )
  else
    health.ok(("%d grammars, all with their queries"):format(#installed))
  end

  health.start("workspace trust")
  local trust = require("mivn.trust")

  -- The workspace, which is the same directory :MivnTrust would act on, so
  -- what this reports and what that changes cannot be two different places.
  local here = trust.here()
  local state, decided_by = trust.status(here)
  if state == "allowed" then
    health.ok(("%s runs language servers%s"):format(here, decided_by ~= here and (", trusted at " .. decided_by) or ""))
  else
    health.warn(
      ("this workspace %s, so no server runs in it: %s"):format(
        state == "denied" and "is denied" or "has not been trusted",
        here
      ),
      ":MivnTrust allows it, :MivnTrust deny refuses it for good"
    )
  end

  -- info for the same reason check_binary uses it: these rows scan by name.
  for _, entry in ipairs(trust.decided()) do
    health.info(("%s: %s (%s)"):format(entry.path, entry.state, entry.by == "mivn" and "this config" or ":MivnTrust"))
  end

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
      check_binary(ft, binary, lsp.probes[binary])
    end
  end
  -- gci is additional, not essential: gopls already formats and organizes
  -- imports, gci only re-groups them into the configured blocks.
  check_binary("gci", "gci", lsp.probes["gci"])
end

return M
