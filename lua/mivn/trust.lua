-- Whether the workspace may have code run for it.
--
-- A language server is not a viewer. rust-analyzer builds the crate, build
-- scripts and proc macros included; expert compiles the Elixir project, which
-- runs mix.exs and its macros; gopls drives the go command, and a toolchain
-- line in a go.mod has it fetch and run another one. So opening somebody else's
-- repository runs their code, and until the workspace is trusted no server
-- starts and nothing formats on save. Files still open and tree-sitter still
-- colors them.
--
-- The workspace is the directory the editor was opened in, not the root a
-- server picks for itself out of whatever markers it likes, which can land
-- above the checkout, beside it, or in the standard library. One answer covers
-- everything inside it, and a file reached from outside it (a dependency's
-- source, the standard library, another project opened without moving there)
-- rides on the same answer, since one window is one project here.
--
-- Nothing is trusted ahead of time. A standing list of directories to skip the
-- question for is one clone in the wrong place away from running code I never
-- looked at, and being asked costs once per checkout.
--
-- Decisions live in Neovim's own trust list, the file `:trust` writes, so it
-- holds these and the exrc ones together. A directory is trusted by name and
-- not by content, which is Neovim's rule for directories and the only one that
-- works here: a repository changes with every pull.
--
-- This is a gate, not a sandbox: a server that does start runs as me and
-- reaches whatever I can.

local M = {}

--- `path` as the trust list spells it, or nil when it does not exist.
local function real(path)
  if type(path) ~= "string" or path == "" then
    return nil
  end

  return vim.uv.fs_realpath(vim.fs.normalize(path))
end

local LIST = vim.fs.joinpath(vim.fn.stdpath("state"), "trust")

--- The trust list, as a map from path to what was decided about it.
---
--- NOTE: read by hand and not through vim.secure.read, which prompts for any
--- path it does not know and would put an exrc dialog in front of a language
--- server. Writes still go through vim.secure, so there is one writer.
local function decisions()
  local list = {}

  local file = io.open(LIST, "r")
  if not file then
    return list
  end

  for line in file:lines() do
    local decision, path = line:match("^(%S+) (.+)$")
    if decision then
      list[path] = decision
    end
  end

  file:close()

  return list
end

--- What was decided about `dir`: "allowed", "denied" or "unknown", and the
--- directory that decided it. The nearest answer at or above `dir` wins, so a
--- decision about a checkout covers everything inside it; Neovim's own list
--- only matches a path exactly.
function M.status(dir)
  local path = real(dir)
  if not path then
    return "unknown"
  end

  local list = decisions()

  while path do
    if list[path] == "!" then
      return "denied", path
    elseif list[path] then
      return "allowed", path
    end

    local parent = vim.fs.dirname(path)
    if parent == path then
      return "unknown"
    end

    path = parent
  end

  return "unknown"
end

--- Whether `dir` may have code run for it.
function M.allows(dir)
  return (M.status(dir)) == "allowed"
end

--- Every directory decided about, either way, as `{ path, state }` entries
--- sorted by path.
function M.decided()
  local list = {}

  for path, decision in pairs(decisions()) do
    -- a file's entry is its hash and a denied one is "!" either way, so only
    -- the disk can tell a directory apart
    if vim.fn.isdirectory(path) == 1 and (decision == "directory" or decision == "!") then
      list[#list + 1] = {
        path = path,
        state = decision == "!" and "denied" or "allowed",
      }
    end
  end

  table.sort(list, function(a, b)
    return a.path < b.path
  end)

  return list
end

--- The workspace: the editor's global working directory. `:cd` moves it; a
--- window's `:lcd` does not, since that is a place to look at a file from and
--- not a claim about whose code this is.
function M.workspace()
  return real(vim.fn.getcwd(-1, -1)) or vim.fn.getcwd(-1, -1)
end

--- The servers being gated, and whether they are on right now.
local servers, running = {}, false

--- Workspaces already told about this session, so moving back and forth between
--- two of them is not a line each time.
local told = {}

--- The filetypes some server would have covered, the only ones where a server
--- not running is worth a word.
---
--- Built once and kept: reading `vim.lsp.config[name]` searches the runtime
--- path for `lsp/<name>.lua` and merges, and Neovim keeps that only for an
--- enabled config, i.e. for none of them in an untrusted workspace. The set
--- cannot change, since `servers` is fixed once gate() has run.
local filetypes_covered

local function covered()
  if filetypes_covered then
    return filetypes_covered
  end

  filetypes_covered = {}

  for _, name in ipairs(servers) do
    for _, filetype in ipairs(vim.lsp.config[name].filetypes or {}) do
      filetypes_covered[filetype] = true
    end
  end

  return filetypes_covered
end

--- Say once per workspace that nothing runs here, and only once a buffer turns
--- up that something would have run for.
local function tell(filetype)
  local workspace = M.workspace()
  if running or told[workspace] or not covered()[filetype] then
    return
  end
  told[workspace] = true

  local news = M.status(workspace) == "denied"
      and "is denied, so no language server runs here. :MivnTrust forget reopens the question."
    or "has not been trusted, so no language server runs here. :MivnTrust allows it."

  vim.notify(("%s %s"):format(workspace, news), vim.log.levels.WARN)
end

--- Start or stop every server to match the workspace. Enabling re-runs the
--- FileType hook over the buffers already open, so trusting a workspace needs
--- no restart.
local function apply()
  local allowed = M.allows(M.workspace())
  if allowed == running then
    return
  end

  running = allowed
  vim.lsp.enable(servers, allowed)

  if not allowed then
    -- NOTE: disabling above already asks these to stop, but a server leaves
    -- when it gets round to it and Neovim's timeout for that is off by default;
    -- leaving a workspace must stop its code now. Killing also keeps the exit
    -- quiet: Neovim reports a server that left on its own, not one it killed,
    -- and gopls leaves with 2 when the client in front of its daemon shuts
    -- down.
    for _, client in ipairs(vim.lsp.get_clients()) do
      if vim.tbl_contains(servers, client.name) then
        client:stop(true)
      end
    end
  end
end

--- Hold `names` to the workspace's answer, now and whenever it changes.
function M.gate(names)
  servers = names

  local group = vim.api.nvim_create_augroup("mivn.trust", { clear = true })

  vim.api.nvim_create_autocmd("DirChanged", {
    group = group,
    pattern = "global",
    callback = function()
      apply()
      tell(vim.bo.filetype)
    end,
  })

  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    callback = function(ev)
      tell(ev.match)
    end,
  })

  apply()
end

--- The directory meant when none is named: the one that decided the workspace's
--- answer, or the workspace itself when nothing has.
function M.here()
  local workspace = M.workspace()
  local _, where = M.status(workspace)

  return where or workspace
end

local ACTIONS = { "allow", "deny", "forget", "status" }

--- Record `action` about `dir` and act on it now, with no restart.
local function decide(action, dir)
  local path = real(dir)
  if not path or vim.fn.isdirectory(path) ~= 1 then
    vim.notify(("%s is not a directory"):format(dir or "?"), vim.log.levels.ERROR)
    return
  end

  if action == "status" then
    local state, where = M.status(path)
    local detail = where and where ~= path and (" (from %s)"):format(where) or ""
    vim.notify(("%s: %s%s"):format(path, state, detail))
    return
  end

  local ok, err = vim.secure.trust({ action = action == "forget" and "remove" or action, path = path })
  if not ok then
    vim.notify(("could not %s %s: %s"):format(action, path, err), vim.log.levels.ERROR)
    return
  end

  -- what was said before may no longer hold
  told = {}

  if action == "allow" then
    vim.notify(("%s is trusted. Starting its language servers."):format(path))
  else
    vim.notify(("%s is %s."):format(path, action == "deny" and "denied" or "back to being unknown"))
  end

  apply()
end

vim.api.nvim_create_user_command("MivnTrust", function(opts)
  local action = opts.fargs[1] or "allow"
  if not vim.tbl_contains(ACTIONS, action) then
    vim.notify(("%s is not one of %s"):format(action, table.concat(ACTIONS, ", ")), vim.log.levels.ERROR)
    return
  end

  decide(action, opts.fargs[2] or M.here())
end, {
  nargs = "*",
  complete = function(lead, line)
    -- the second argument is a directory, the first one of ACTIONS
    if line:match("^%s*%S+%s+%S+%s") then
      return vim.fn.getcompletion(lead, "dir")
    end

    return vim.tbl_filter(function(action)
      return vim.startswith(action, lead)
    end, ACTIONS)
  end,
  desc = "Trust this directory for language servers (allow|deny|forget|status)",
})

return M
