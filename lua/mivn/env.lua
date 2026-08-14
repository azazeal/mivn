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
-- 2026-08-15: `mise env --json` answers in 6ms here, and refuses in 6ms.
-- `:checkhealth mivn` reports what it cost, so the day it stops being cheap
-- is visible.

local M = {}

-- Neovim's own. Nothing a workspace ships gets to move them.
local KEEP = {
  MYVIMRC = true,
  NVIM = true,
  NVIM_APPNAME = true,
  NVIM_LOG_FILE = true,
  VIM = true,
  VIMRUNTIME = true,
}

local IGNORED = vim.fs.joinpath(vim.fn.stdpath("state"), "env-ignored.json")

--- What happened, for :checkhealth mivn and :MivnEnv. `asks` holds the config
--- roots that need an answer before any of this workspace's variables can be
--- read; mise refuses the lot when one of them is untrusted.
local state = {
  applied = {},
  asks = {},
  ms = 0,
}

local function slurp(path)
  local file = io.open(path, "r")
  if not file then
    return nil
  end

  local body = file:read("*a")
  file:close()

  return body
end

--- The roots I have said no to. Only a no is remembered: mise keys its own
--- approval to the trust root's contents, and a yes remembered here would
--- outlive an edit to the config, which is what that check exists to catch.
local ignored
local function load_ignored()
  if not ignored then
    local ok, decoded = pcall(vim.json.decode, slurp(IGNORED) or "")
    ignored = ok and type(decoded) == "table" and decoded or {}
  end

  return ignored
end

local function ignore(path)
  load_ignored()[path] = true

  vim.fn.mkdir(vim.fs.dirname(IGNORED), "p")
  local file = assert(io.open(IGNORED, "w"))
  file:write(vim.json.encode(ignored), "\n")
  file:close()
end

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

--- Trust ----------------------------------------------------------------------
--
-- mise decides by content, so asking it for the environment is the only honest
-- test: a config carrying only min_version, plain [tools] versions and plain
-- [tasks] is read with no trust at all, since nothing in it runs at load time,
-- while templates, tool options, [env] and `_.source` are refused until
-- trusted. Measured on 2026-08-14: `trust --show` calls ~/projects untrusted
-- for a leftover .tool-versions and `mise env --json` reads it anyway, so
-- gating on the first would hide an environment mise was willing to give.
--
-- mise's own prompt must never reach a terminal: asked there, a no puts the
-- config on its ignored list and it stops asking forever. Nothing here runs
-- mise interactively, and `trust --show` answers without prompting at all.

--- The config roots mise wants an answer about, nearest last, minus the ones
--- already answered with a no.
local function untrusted()
  local shown = mise({ "trust", "--show" })

  local roots = {}
  for line in ((shown or {}).stdout or ""):gmatch("[^\r\n]+") do
    -- mise writes these through its own display_path, which abbreviates the
    -- home directory back to a tilde. vim.system runs no shell, so an
    -- unexpanded one would reach `mise trust` as a literal directory name.
    local path = line:match("^(.*): untrusted$")
    path = path and vim.fs.normalize(path)

    if path and not load_ignored()[path] then
      roots[#roots + 1] = path
    end
  end

  return roots
end

--- Resolving ------------------------------------------------------------------

--- Put `vars` on the process.
local function apply(vars)
  for name, value in pairs(vars) do
    if not KEEP[name] then
      vim.env[name] = value ~= vim.NIL and value or nil
      state.applied[name] = true
    end
  end
end

--- Read the environment, apply it, and remember what still needs an answer.
function M.resolve()
  local started = vim.uv.hrtime()

  state.applied, state.asks = {}, {}

  local env = mise({ "env", "--json" })
  if env and env.code == 0 then
    apply(decode(env.stdout) or {})
  elseif env then
    -- It refused. A refusal with nothing untrusted behind it is some other
    -- problem, and not one a dialog can fix.
    state.asks = untrusted()

    -- `trust --show` names roots, which are directories; the refusal names
    -- the file it choked on. Keep it for the dialog, so "show it" opens a
    -- config rather than a directory listing.
    local named = (env.stderr or ""):match("Config files in (.-) are not trusted")
    state.named = named and vim.fs.normalize(named) or nil
  end

  state.ms = (vim.uv.hrtime() - started) / 1e6
end

--- Asking ---------------------------------------------------------------------

--- Ask about one root, then carry on to the next. A yes runs whatever the
--- config does, so the file itself is one keystroke away; taking that option
--- leaves the question unanswered and :MivnEnv asks it again.
local function ask(root)
  local choices = { "Trust it", "Show it first", "No, and do not ask again", "Ask me later" }
  local prompt = ("%s is not trusted, so this workspace has no environment."):format(vim.fn.fnamemodify(root, ":~"))

  vim.ui.select(choices, { prompt = prompt }, function(choice)
    -- Both answers that settle a root re-resolve and ask again, because one
    -- answer can leave the next root waiting: mise refuses the whole set
    -- until every one of them is trusted.
    if choice == choices[1] then
      local result = mise({ "trust", root })
      if not result or result.code ~= 0 then
        vim.notify(("Could not trust %s"):format(root), vim.log.levels.WARN)
        return
      end
    elseif choice == choices[2] then
      -- The file mise named when it refused, when it is one of this root's;
      -- the directory otherwise, which netrw lists.
      local target = state.named
      if not target or not vim.fs.relpath(root, target) then
        target = root
      end

      vim.cmd.split(vim.fn.fnameescape(target))
      return
    elseif choice == choices[3] then
      ignore(root)
    else
      return
    end

    M.resolve()
    if #state.asks > 0 then
      M.ask()
    elseif choice == choices[1] then
      vim.notify("Environment applied. Language servers already running keep the old one until :restart.")
    end
  end)
end

--- Ask about the first root still waiting, if any.
function M.ask()
  if state.asks[1] then
    ask(state.asks[1])
  end
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

-- The question waits for the UI. Startup is drawing a banner, and the answer
-- to it runs whatever a config from a directory I may have just cloned says.
vim.api.nvim_create_autocmd("VimEnter", {
  group = vim.api.nvim_create_augroup("mivn.env", { clear = true }),
  callback = function()
    vim.schedule(M.ask)
  end,
})

vim.api.nvim_create_user_command("MivnEnv", function()
  M.resolve()

  if #state.asks > 0 then
    M.ask()
    return
  end

  vim.notify(("Environment resolved in %.0fms; %d variables set."):format(state.ms, vim.tbl_count(state.applied)))
end, { desc = "Re-read the workspace's mise environment" })

return M
