-- The project's environment, from mise and direnv.
--
-- The programs this config starts need the project's toolchain and never ask
-- for it: gopls and gci live in the Go version's own bin, rust-analyzer
-- shells out to cargo, expert needs elixir and erlang, and the formatters are
-- whatever is on PATH. A Neovide started from a launcher never ran a shell,
-- so direnv never fired and mise never activated, and all of them get
-- whatever the desktop session had.
--
-- Resolved once, against the startup directory, the way lua/mivn/overrides.lua
-- resolves its own scopes: one Neovim is one project. Applied to the process
-- rather than to each language server, because the gci pass in lsp.lua is a
-- plain vim.system, `:terminal` wants the same environment, and so do the
-- external formatters.
--
-- Synchronous on purpose. Anything else races: a file named on the command
-- line reaches FileType during startup, and a server started before the
-- environment lands would have to be restarted to see it. Measured on
-- 2026-08-14: `direnv status --json` is 2ms, `direnv export json` 36ms on my
-- own .envrc, and mise documents 5-10ms for its own. `:checkhealth mivn`
-- reports what this cost, so the day it stops being cheap is visible.
--
-- Neither file is trusted blindly, and the asking is deliberately one-sided:
-- a no is remembered, a yes never is. direnv keys its approval to the file's
-- content hash and mise keys its own to the trust root, so a yes remembered
-- here would outlive an edit to either, which is the exact thing those hashes
-- exist to catch.

local M = {}

-- Neovim's own. Nothing a project ships gets to move them.
local KEEP = {
  MYVIMRC = true,
  NVIM = true,
  NVIM_APPNAME = true,
  NVIM_LOG_FILE = true,
  VIM = true,
  VIMRUNTIME = true,
}

local IGNORED = vim.fs.joinpath(vim.fn.stdpath("state"), "env-ignored.json")

--- What happened, for :checkhealth mivn and :MivnEnv. `asks` holds the files
--- that need an answer before their variables can be read.
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

--- The paths I have said no to, keyed by the file itself.
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

--- Run `cmd` in the startup directory. Returns its result, or nil when the
--- program is missing or takes longer than it should.
local function run(cmd, timeout)
  if vim.fn.executable(cmd[1]) ~= 1 then
    return nil
  end

  local ok, result = pcall(function()
    return vim
      .system(cmd, {
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

--- Put `vars` on the process. A JSON null means the variable goes away,
--- which is how direnv spells a variable its .envrc unset.
local function apply(vars)
  for name, value in pairs(vars) do
    if not KEEP[name] then
      vim.env[name] = value ~= vim.NIL and value or nil

      -- A set, not a list: mise and direnv both set PATH, and counting it
      -- twice would make the health line say more than happened.
      state.applied[name] = true
    end
  end
end

-- mise and direnv both build PATH by prepending to the one they were handed,
-- so an .envrc that says `use mise` hands back the entries mise already
-- added. Harmless but unreadable, and it grows on every re-run of :MivnEnv.
local function dedupe_path()
  local seen, kept = {}, {}
  for entry in (vim.env.PATH or ""):gmatch("[^:]+") do
    if not seen[entry] then
      seen[entry] = true
      kept[#kept + 1] = entry
    end
  end

  vim.env.PATH = table.concat(kept, ":")
end

--- mise -----------------------------------------------------------------------
--
-- Trust is content-aware, so asking mise for the environment is the only
-- honest test of it: a config carrying only min_version, plain [tools]
-- versions and plain [tasks] is read with no trust at all, since nothing in
-- it runs at load time, while templates, tool options (`postinstall` is one),
-- [env] and `_.source` are refused until trusted. Measured on 2026-08-14:
-- `trust --show` calls ~/projects untrusted for its .tool-versions and
-- `mise env --json` reads it anyway, so gating on the first would hide an
-- environment mise was willing to give.
--
-- mise's own prompt must never reach a terminal: asked there, a no puts the
-- config on its ignored list and it stops asking forever. Nothing here runs
-- mise interactively, and `trust --show` answers without prompting at all.

local function mise()
  local env = run({ "mise", "env", "--json" })
  if not env then
    return
  end

  if env.code == 0 then
    apply(decode(env.stdout) or {})
    return
  end

  -- It refused. `trust --show` names the config roots it wants an answer
  -- about, one `<path>: trusted` or `<path>: untrusted` line each, from here
  -- up. A failure with nothing untrusted in it is some other problem, and
  -- not one a dialog can fix.
  local shown = run({ "mise", "trust", "--show" })
  for line in ((shown or {}).stdout or ""):gmatch("[^\r\n]+") do
    -- mise writes these through its own display_path, which abbreviates the
    -- home directory back to a tilde. vim.system runs no shell, so an
    -- unexpanded one would reach `mise trust` as a literal directory name.
    local path = line:match("^(.*): untrusted$")
    path = path and vim.fs.normalize(path)

    if path and not load_ignored()[path] then
      state.asks[#state.asks + 1] = { kind = "mise", path = path }
      return
    end
  end
end

--- direnv ---------------------------------------------------------------------
--
-- `direnv status --json` answers with state.foundRC = { path, allowed },
-- where allowed is 0 for allowed, 1 for blocked and 2 for denied. The gate
-- matters: on a blocked directory `direnv export json` exits 1 and still
-- prints DIRENV_DIFF and DIRENV_WATCHES with none of the real variables, so
-- applying what it printed would leave this process believing direnv is
-- loaded while nothing was.
--
-- Runs after mise, and only then, so its diff composes over the PATH mise
-- just set rather than over the one Neovim started with.

local function direnv()
  local status = run({ "direnv", "status", "--json" })
  if not status or status.code ~= 0 then
    return
  end

  local found = ((decode(status.stdout) or {}).state or {}).foundRC
  if type(found) ~= "table" or not found.path then
    return
  end

  if found.allowed ~= 0 then
    -- 2 is denied, which is an answer already given.
    if found.allowed ~= 2 and not load_ignored()[found.path] then
      state.asks[#state.asks + 1] = { kind = "direnv", path = found.path }
    end

    return
  end

  local exported = run({ "direnv", "export", "json" })
  if exported and exported.code == 0 then
    apply(decode(exported.stdout) or {})
  end
end

--- Resolving and asking -------------------------------------------------------

--- Read both, apply what is trusted, and remember what still needs an answer.
function M.resolve()
  local started = vim.uv.hrtime()

  state.applied, state.asks = {}, {}
  mise()
  direnv()
  dedupe_path()

  state.ms = (vim.uv.hrtime() - started) / 1e6
end

local ALLOW = {
  mise = function(path)
    return { "mise", "trust", path }
  end,
  direnv = function(path)
    return { "direnv", "allow", path }
  end,
}

--- Ask about one file. A yes runs it, so the file itself is one keystroke
--- away; taking that option leaves the question unanswered and :MivnEnv asks
--- it again.
local function ask(pending)
  local choices = { "Allow it", "Show it first", "No, and do not ask again", "Ask me later" }

  vim.ui.select(choices, {
    prompt = ("%s is not trusted. Its tools and variables are not in use."):format(
      vim.fn.fnamemodify(pending.path, ":~")
    ),
  }, function(choice)
    if choice == choices[1] then
      local result = run(ALLOW[pending.kind](pending.path))
      if not result or result.code ~= 0 then
        vim.notify(("Could not trust %s"):format(pending.path), vim.log.levels.WARN)
        return
      end

      M.resolve()
      vim.notify("Environment applied. Language servers already running keep the old one until :restart.")
    elseif choice == choices[2] then
      vim.cmd.split(vim.fn.fnameescape(pending.path))
    elseif choice == choices[3] then
      ignore(pending.path)
    end
  end)
end

--- Ask about everything still waiting, one file at a time.
local function ask_all()
  local pending = table.remove(state.asks, 1)
  if pending then
    ask(pending)
  end
end

M.resolve()

-- The questions wait for the UI. Startup is drawing a banner, and the answer
-- to one of them runs a shell script from a directory I may have just cloned.
vim.api.nvim_create_autocmd("VimEnter", {
  group = vim.api.nvim_create_augroup("mivn.env", { clear = true }),
  callback = function()
    vim.schedule(ask_all)
  end,
})

vim.api.nvim_create_user_command("MivnEnv", function()
  M.resolve()

  if #state.asks > 0 then
    ask_all()
    return
  end

  vim.notify(("Environment resolved in %.0fms; %d variables set."):format(state.ms, vim.tbl_count(state.applied)))
end, { desc = "Re-read the project's mise and direnv environment" })

--- For lua/mivn/health.lua; nothing else reads this.
function M.state()
  return state
end

return M
