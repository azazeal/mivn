-- `:checkhealth mivn`: whether the language servers and formatters actually
-- run, whether the plugins on disk are the ones plugins.lua pins, and where the
-- workspace stands on trust.
--
-- executable() only says a file is there, not that it runs: a rustup shim with
-- no component behind it is executable and fails every time. So each binary
-- found is run once, with a version flag and a timeout or long enough to see it
-- stay up, and its answer is what gets reported. Nothing here installs
-- anything.

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

--- The line of a failed start that says what went wrong: the first naming an
--- error, since node opens with its own loader's file and line, else the first.
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

--- The command Neovim would start `name` with, with `path` as the binary. The
--- arguments matter: `expert` exits 2 without a transport flag. A `cmd` that is
--- a function (nvim-lspconfig's way to prefer a project's own copy) gives just
--- `path`, since that is the binary being asked about.
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

--- How long, in milliseconds, a server with no version flag has to stay up to
--- count as working. A launcher missing the code behind it dies in about 50.
local LIVENESS = 500

--- Start every server that has no version flag, all at once, so the wait for
--- them is paid once and not once per server. Returns them by name, and the
--- directory they run in, which the caller removes once check_liveness has seen
--- every one.
local function start_all(servers)
  local started = {}

  -- NOTE: not the editor's directory, since expert writes an `.expert/` log
  -- directory wherever it starts.
  local scratch = vim.fn.tempname()
  vim.fn.mkdir(scratch, "p")

  for name, entry in pairs(servers) do
    local path = entry.probe == false and vim.fn.exepath(entry.binary) or ""

    if path ~= "" then
      -- NOTE: stdin is a pipe held open, since a working server that reads
      -- end-of-file exits, which looks just like the failure being looked for.
      local ok, proc = pcall(vim.system, launch_argv(name, path), { text = true, stdin = true, cwd = scratch })
      started[name] = { ok = ok, proc = proc, at = vim.uv.hrtime() }
    end
  end

  return started, scratch
end

--- Report a server started by start_all(): healthy when it is still up after
--- LIVENESS, since a server with nothing to read should sit and wait.
local function check_liveness(label, binary, path, started)
  local health = vim.health

  if not started.ok then
    health.error(("%s: %s failed to start: %s"):format(label, binary, started.proc))
    return
  end

  -- NOTE: the second wait is not redundant. A server killed for outliving the
  -- first is reaped a moment later, and wait() returns nil until it is.
  local elapsed = (vim.uv.hrtime() - started.at) / 1e6
  local result = started.proc:wait(math.max(1, math.floor(LIVENESS - elapsed))) or started.proc:wait(1000)

  -- 124 is wait() timing out and killing it, i.e. the server was still up
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

--- Probe one binary and report it as a row named `label`.
---
--- NOTE: healthy rows go through info, not ok. vim.health.ok puts "✅ OK" in
--- front of the message, so a section read by name would start every row with
--- "OK".
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

--- Probe `binary` and report it as a row named `label`, the way every server
--- and formatter row is. `probe` is the arguments to ask with, `--version` when
--- nil.
function M.binary(label, binary, probe)
  check_binary(label, binary, probe, {})
end

local function check_update()
  local health = vim.health
  local update = require("mivn.update").report()

  health.start("mivn")

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
end

local function check_servers(lsp)
  vim.health.start("language servers")

  local started, scratch = start_all(lsp.servers)
  for name, entry in vim.spairs(lsp.servers) do
    check_binary(name, entry.binary, entry.probe, started)
  end

  -- every server above has been waited on, so nothing writes there any more
  vim.fn.delete(scratch, "rf")
end

--- What is on disk against what plugins.lua pins. vim.pack installs a plugin at
--- its pin and never looks at the clone again, so a pin moved by a pull leaves
--- the old checkout running and a plugin dropped from the list stays on disk,
--- and neither says so on its own.
local function check_plugins()
  local health = vim.health

  health.start("plugins")

  -- `info = false` skips asking every clone for tags and branches, unused here
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
end

--- Grammars that lost their queries, which fails in silence: the language turns
--- on and colors nothing.
local function check_grammars()
  local health = vim.health
  local grammars = require("mivn.treesitter")
  local installed = grammars.installed()
  local broken = grammars.broken()

  health.start("tree-sitter")

  if #broken == 0 then
    health.ok(("%d grammars, all with their queries"):format(#installed))
    return
  end

  local one = #broken == 1
  health.warn(
    ("%d %s %s a parser but no queries: %s"):format(
      #broken,
      one and "grammar" or "grammars",
      one and "has" or "have",
      table.concat(broken, ", ")
    ),
    ":MivnInstallGrammars reinstalls them"
  )
end

local function check_trust()
  local health = vim.health
  local trust = require("mivn.trust")

  health.start("workspace trust")

  -- the directory :MivnTrust acts on, so the two cannot disagree
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

  for _, entry in ipairs(trust.decided()) do
    health.info(("%s: %s"):format(entry.path, entry.state))
  end
end

local function check_clients()
  local health = vim.health
  local clients = vim.lsp.get_clients()

  health.start("clients in this session")

  if #clients == 0 then
    health.info("none attached; open a file a server covers, then rerun")
  end

  for _, client in ipairs(clients) do
    health.info(("%s, rooted at %s"):format(client.name, client.root_dir or "(no root)"))
  end
end

local function check_formatters(lsp)
  local seen = {}

  vim.health.start("external formatters")

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
end

--- What a language file checks for itself, under a section of its own.
local function check_languages(lsp)
  for language, check in vim.spairs(lsp.checks) do
    vim.health.start(language)
    check()
  end
end

function M.check()
  local lsp = require("mivn.lsp")

  check_update()
  check_servers(lsp)
  check_plugins()
  check_grammars()
  check_trust()
  check_clients()
  check_formatters(lsp)
  check_languages(lsp)
end

return M
