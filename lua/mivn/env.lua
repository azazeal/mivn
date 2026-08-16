-- The workspace's environment, from mise.
--
-- The programs this config starts need the workspace's toolchain and never
-- ask for it: gopls and gci are on PATH, rust-analyzer shells out to cargo,
-- expert needs elixir and erlang. A Neovide started from a launcher never ran
-- a shell, so mise's activation hook never fired, and all of them get
-- whatever the desktop session had.
--
-- Resolved once, against the startup directory, the way lua/mivn/overrides.lua
-- resolves its own scopes: one Neovim is one workspace. Applied to the process
-- rather than to each language server, because the gci pass in lsp.lua is a
-- plain vim.system, `:terminal` wants the same environment, and so do the
-- external formatters.
--
-- Synchronous on purpose. Anything else races: a file named on the command
-- line reaches FileType during startup, and a server started before the
-- environment lands would have to be restarted to see it. Measured on
-- 2026-08-16: `mise env --json` answers in 30ms here, and refuses about as
-- fast; it was 6ms on 2026-08-15, against a smaller config and an older
-- mise. `:checkhealth mivn` reports what it cost, so the day it stops being
-- cheap is visible.
--
-- Trust is not this module's business. A directory I edit in is a directory
-- I have been in, and mise asks for trust there, once, and remembers it by
-- path: it re-reads the file afterwards without asking again, since the
-- content hash only matters under `paranoid`. So the editor expects an
-- answered directory and says so plainly when it finds otherwise, rather
-- than putting a dialog in front of a config I have not read. `mise trust`
-- belongs in the terminal that is already open.

local M = {}

local overrides = require("mivn.overrides")

-- Neovim's own. Nothing a workspace ships gets to move them.
local KEEP = {
  MYVIMRC = true,
  NVIM = true,
  NVIM_APPNAME = true,
  NVIM_LOG_FILE = true,
  VIM = true,
  VIMRUNTIME = true,
}

--- What happened, for :checkhealth mivn and :MivnEnv. `refused` is what mise
--- said when it would not answer, which is usually an untrusted directory
--- and occasionally a config it cannot parse.
local state = {
  applied = {},
  refused = nil,
  ms = 0,
}

--- What each name held before mise first set it, so a name that falls out of
--- a later answer goes back to the value the shell had rather than being
--- deleted. vim.NIL stands for "there was nothing here". Kept past the
--- restore, since the name can come back and leave again.
local original = {}

--- Run mise in the startup directory. Returns its result, or nil when mise is
--- not installed or takes longer than it should.
local function mise(args, timeout)
  if vim.fn.executable("mise") ~= 1 then
    return nil
  end

  local ok, result = pcall(function()
    return vim
      .system(vim.list_extend({ "mise" }, args), {
        text = true,
        cwd = vim.fn.getcwd(),
      })
      :wait(timeout or 5000)
  end)

  return ok and result or nil
end

local function decode(text)
  local ok, decoded = pcall(vim.json.decode, text or "")
  return ok and type(decoded) == "table" and decoded or nil
end

--- Put `vars` on the process.
local function apply(vars)
  for name, value in pairs(vars) do
    if not KEEP[name] then
      if original[name] == nil then
        original[name] = vim.env[name] or vim.NIL
      end

      vim.env[name] = value ~= vim.NIL and value or nil
      state.applied[name] = true
    end
  end
end

--- Read the environment and apply it, or remember why not.
function M.resolve()
  local started = vim.uv.hrtime()

  state.refused = nil

  local env = mise({ "env", "--json" })
  if env and env.code == 0 then
    -- The previous answer's names, kept so a variable this answer no longer
    -- carries goes back to what it was rather than being left stale: without
    -- this, deleting a line from mise.toml and running :MivnEnv changes
    -- nothing. On a refusal the record survives instead, since the variables
    -- do too.
    --
    -- Back to what it was, not gone: mise's answer usually *overrides*
    -- something the shell already exported, PATH first among them, and
    -- deleting one of those would leave the editor worse off than it was
    -- before mise said anything.
    local previous = state.applied
    state.applied = {}

    apply(decode(env.stdout) or {})

    for name in pairs(previous) do
      if not state.applied[name] then
        local was = original[name]
        vim.env[name] = was ~= vim.NIL and was or nil
      end
    end
  elseif env then
    -- mise's own words, minus its prefix and its two closing lines about the
    -- version and --verbose. The reason is rarely on the first line: an
    -- untrusted directory opens with "error parsing config file" and only
    -- says "are not trusted" underneath it.
    local said = {}
    for line in (env.stderr or ""):gmatch("[^\r\n]+") do
      line = vim.trim((line:gsub("^mise ERROR%s*", "")))
      if line ~= "" and not line:match("^Version:") and not line:match("^Run with") then
        said[#said + 1] = line
      end
    end

    state.refused = #said > 0 and table.concat(said, " ") or "mise would not answer"
  end

  state.ms = (vim.uv.hrtime() - started) / 1e6
end

--- The tools this workspace resolves to, as mise reports them, or nil when it
--- cannot say. For lua/mivn/health.lua.
function M.tools()
  local listed = mise({ "ls", "--current", "--json" })
  if not listed or listed.code ~= 0 then
    return nil
  end

  return decode(listed.stdout)
end

--- For lua/mivn/health.lua; nothing else reads this.
function M.state()
  return state
end

M.resolve()

-- Said once, after the UI is up, because an editor with no toolchain on PATH
-- is about to look broken in a dozen small ways and the reason should arrive
-- before the symptoms.
if state.refused and overrides.quiet ~= true then
  vim.api.nvim_create_autocmd("VimEnter", {
    group = vim.api.nvim_create_augroup("mivn.env", { clear = true }),
    callback = function()
      vim.schedule(function()
        vim.notify(
          ("No environment here: %s\nRun `mise trust` in this directory, then :MivnEnv."):format(state.refused),
          vim.log.levels.WARN
        )
      end)
    end,
  })
end

vim.api.nvim_create_user_command("MivnEnv", function()
  M.resolve()

  if state.refused then
    vim.notify(state.refused, vim.log.levels.WARN)
    return
  end

  -- A refreshed environment can change mise's answer about this directory,
  -- so the sandbox gets to try again too: this is the second half of the
  -- "`mise trust`, then :MivnEnv" advice above.
  require("mivn.lsp").rewrap()

  vim.notify(("Environment resolved in %.0fms; %d variables set."):format(state.ms, vim.tbl_count(state.applied)))
end, { desc = "Re-read the workspace's mise environment" })

return M
