-- :checkhealth mivn: does the language-server setup actually work, and is
-- what is on disk what plugins.lua says?
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

--- The line of a failed start that says what went wrong.
---
--- The first line is usually scaffolding: node opens with the file and line of
--- its own loader, and the sentence worth reading is four lines down. So the
--- first line naming a fault wins, and the plain first line is the fallback.
local function first_fault(...)
  for _, text in ipairs({ ... }) do
    for line in (text or ""):gmatch("[^\r\n]+") do
      line = vim.trim(line)
      if line:match("[Ee]rror") or line:match("FATAL") then
        return line
      end
    end
  end

  return first_line(...)
end

--- The command Neovim would actually start `name` with.
---
--- It has to be that one and not the bare binary, because the arguments
--- decide the answer: `expert` exits 2 without a transport flag, so starting
--- it on its own would condemn a server that works. mivn names `cmd` for some
--- servers and leaves the rest to nvim-lspconfig, and vim.lsp.config is where
--- the two meet.
---
--- nvim-lspconfig ships a function for some of them, to prefer a copy the
--- project carries. Those are left alone: the binary already found on PATH is
--- what this is asking about.
local function launch_argv(name, path)
  local configured = vim.lsp.config[name]
  local cmd = configured and configured.cmd

  if type(cmd) ~= "table" then
    return { path }
  end

  local argv = { path }
  for i = 2, #cmd do
    argv[#argv + 1] = cmd[i]
  end

  return argv
end

--- How long a server with no version flag has to stay up to count as working.
---
--- The failure this catches is immediate. A launcher whose package shipped
--- without the code behind it dies in about 50 milliseconds, measured, so half
--- a second is ten times the room it needs.
local LIVENESS = 500

--- Start every server that has no version flag, all at once, so the half
--- second each one has to prove itself is paid once and not once per server:
--- six of them held one after the other made this check take 4.4 seconds,
--- and together they take one (measured 2026-09-03). Each is looked at
--- again in check_liveness, in its turn, with however much of its half
--- second is left.
---
--- Returns the servers started, and the directory they were started in: the
--- caller removes it once every one of them has been looked at.
local function start_all(servers)
  local started = {}

  -- Somewhere of their own to start in, not the directory the editor is in:
  -- expert writes an `.expert/` log directory wherever it starts, which is
  -- how one turned up in this repository (measured 2026-09-03).
  local scratch = vim.fn.tempname()
  vim.fn.mkdir(scratch, "p")

  for name, entry in pairs(servers) do
    local path = entry.probe == false and vim.fn.exepath(entry.binary) or ""

    if path ~= "" then
      local ok, proc = pcall(vim.system, launch_argv(name, path), { text = true, stdin = true, cwd = scratch })
      started[name] = { ok = ok, proc = proc, at = vim.uv.hrtime() }
    end
  end

  return started, scratch
end

--- A server that answers no version flag, checked by starting it the way the
--- editor would and seeing whether it is still there a moment later.
---
--- "Found at <path>" was the old answer and it was worth very little. exepath
--- says a file exists; it does not say the file runs. Measured 2026-08-23,
--- when every published version of @zed-industries/vscode-langservers-extracted
--- carried launchers requiring a `lib/` the tarball did not hold: jsonls,
--- cssls and html were all reported found while none of the three could start,
--- and the first anyone knew of it was a server exiting 1 on opening a file.
---
--- Timing out is the healthy answer here, since a server with nothing to read
--- should sit and wait rather than return. stdin is a pipe held open for that
--- reason: closed, a working server would see end-of-file and exit for a good
--- reason, which is the same shape as the failure being looked for.
local function check_liveness(label, binary, path, started)
  local health = vim.health

  if not started.ok then
    health.error(("%s: %s failed to start: %s"):format(label, binary, started.proc))
    return
  end

  -- What is left of its half second; at least a moment, so that a server
  -- already past it is still asked rather than assumed. A server killed for
  -- outliving the wait is reaped a moment after, and wait() hands back
  -- nothing until it is, so the second wait is for that alone: it returns
  -- at once when the answer is already in.
  local elapsed = (vim.uv.hrtime() - started.at) / 1e6
  local result = started.proc:wait(math.max(1, math.floor(LIVENESS - elapsed))) or started.proc:wait(1000)

  -- 124 is what wait() reports when it runs out of patience and kills, which
  -- is to say the server was still running.
  if result.code == 124 then
    health.info(("%s: starts and keeps running (%s)"):format(label, path))
    return
  end

  health.error(
    ("%s: %s is on PATH but exits %d immediately: %s"):format(
      label,
      binary,
      result.code,
      first_fault(result.stderr, result.stdout)
    ),
    "The launcher is there and what it launches is not; check how its package was installed."
  )
end

--- Probe one binary; report through vim.health.
---
--- The healthy rows go through info, not ok, on purpose: vim.health.ok
--- hard-codes "✅ OK" in front of the message, so every row would read
--- "OK name" when the section is a table scanned by name. Info rows keep
--- the name first; the loud levels, prefix and all, are kept for rows
--- that are actually trouble.
local function check_binary(label, binary, probe, started)
  local health = vim.health

  local path = vim.fn.exepath(binary)
  if path == "" then
    health.info(("%s: off (%s is not on PATH)"):format(label, binary))
    return
  end

  if probe == false then
    return check_liveness(label, binary, path, started[label])
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
      "A wrapper can be broken while the file itself is executable: a rustup shim without its component, "
        .. "or a mise shim outside a project that pins the tool. The answer is about this directory."
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

  local started, scratch = start_all(lsp.servers)
  for name, entry in vim.spairs(lsp.servers) do
    check_binary(name, entry.binary, entry.probe, started)
  end

  -- Every server started above has been waited on by now, killed if it
  -- outlived its half second, so nothing is writing there any more. Removed
  -- here rather than left to Neovim's exit, since a session runs this more
  -- than once and each run would otherwise leave a directory behind.
  vim.fn.delete(scratch, "rf")

  check_gopls_toolchain()

  health.start("plugins")

  -- What is on disk against what plugins.lua pins. vim.pack installs a
  -- plugin at its pin and then never looks at the clone again: a pin moved
  -- by a pull leaves the old checkout running, and a plugin dropped from
  -- plugins.lua stays on disk and in the lock. Neither says anything on its
  -- own (measured 2026-09-03, a treesitter clone six commits behind its
  -- pin), so this is where they are said. `info = false` keeps vim.pack from
  -- asking every clone for its tags and branches, which nothing here reads.
  local plugins = vim.pack.get(nil, { info = false })
  local behind, orphans = {}, {}

  for _, plugin in ipairs(plugins) do
    if not plugin.active then
      orphans[#orphans + 1] = plugin.spec.name
    else
      local head = vim.system({ "git", "-C", plugin.path, "rev-parse", "HEAD" }, { text = true }):wait(3000)
      local rev = vim.trim(head.stdout or "")

      if head.code ~= 0 or rev ~= plugin.rev then
        behind[#behind + 1] = ("%s (%s, pinned at %s)"):format(
          plugin.spec.name,
          rev:sub(1, 7),
          (plugin.rev or "?"):sub(1, 7)
        )
      end
    end
  end

  if #behind > 0 then
    health.warn(
      ("not at their pins: %s"):format(table.concat(behind, ", ")),
      ":lua vim.pack.update(nil, { target = 'lockfile' }) checks the pins out"
    )
  end

  if #orphans > 0 then
    health.warn(
      ("on disk but not in plugins.lua: %s"):format(table.concat(orphans, ", ")),
      (":lua vim.pack.del({ %s }) removes them"):format(table.concat(
        vim.tbl_map(function(name)
          return ("%q"):format(name)
        end, orphans),
        ", "
      ))
    )
  end

  if #behind == 0 and #orphans == 0 then
    health.ok(("%d plugins, all at their pins"):format(#plugins))
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
  -- Every row is an answer I gave, since nothing is trusted ahead of time.
  for _, entry in ipairs(trust.decided()) do
    health.info(("%s: %s"):format(entry.path, entry.state))
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
      check_binary(ft, binary, lsp.probes[binary], {})
    end
  end
  -- gci is additional, not essential: gopls already formats and organizes
  -- imports, gci only re-groups them into the configured blocks.
  --
  -- $GOIMPORTNOGCI is lua/mivn/languages/go.lua's switch for a gci released
  -- before a standard library package it is now meeting, which it reads as
  -- third party. That module is asked rather than the variable, so what this
  -- row says and what saving does cannot drift apart.
  if require("mivn.languages.go").gci_off() then
    health.info("gci: off (turned off by $GOIMPORTNOGCI)")
  else
    check_binary("gci", "gci", lsp.probes["gci"], {})
  end
end

return M
