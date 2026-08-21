-- Whether the workspace may have code run for it.
--
-- A language server is not a viewer. rust-analyzer builds the crate to answer
-- anything about it, build scripts and proc macros included; expert compiles
-- the Elixir project, which is mix.exs and its macros running; gopls drives
-- the go command, and a toolchain line in a go.mod has it fetch and run
-- another one. Opening somebody else's repository therefore runs their code,
-- and the cooldown that guards the tools says nothing about it: this code
-- arrived with the project, not with the tool.
--
-- The workspace is the directory the editor was opened in, and it is the
-- whole of the question. Not the root a server picks for itself: those are a
-- different thing, chosen per server out of whatever markers each one likes,
-- and they land above the checkout, beside it, or in the standard library.
-- Helix and VS Code both draw the line here, and Helix says so outright by
-- keeping workspace root and language-server root apart on purpose.
--
-- So: one answer per workspace, everything inside it covered, and a file
-- reached from outside it, a dependency's source or the standard library,
-- carried by the same answer rather than asked about again. Until that answer
-- is yes, no server starts at all and nothing formats on save; `:MivnTrust`
-- is how it gets given. Everything else is untouched either way: files open,
-- tree-sitter colours them, and the editor is an editor.
--
-- What this gives up, knowingly: opening a file from some other project
-- without moving there rides on this workspace's answer. VS Code has a
-- setting for exactly that case and defaults it to asking; here one window is
-- one project, so it is not worth the machinery.
--
-- Decisions live in Neovim's own trust list, the file `:trust` writes, so one
-- list holds these and the exrc ones together and `:trust` still reads. A
-- directory in it is trusted by name rather than by content, which is
-- Neovim's own rule for directories and the only workable one here: a
-- repository's contents change with every pull.
--
-- WARN: this is a gate, not a sandbox. It decides whether the servers start
-- at all. Ones that do run as me and reach whatever I can.

local M = {}

--- Mine, and trusted without being asked about. Everything I write lives
--- under one of these, so the question is only ever put about a checkout of
--- somebody else's, which is what ~/projects/oss is full of.
---
--- The trade is deliberate: a hostile repository cloned into one of these is
--- trusted by being there. That is the same trust I extend by putting it
--- there in the first place.
local MINE = {
  "~/projects/azazeal",
  "~/projects/nefeloma",
  "~/projects/smallstep.com",
}

--- `path` as the trust list spells it, or nil when it does not exist.
local function real(path)
  if type(path) ~= "string" or path == "" then
    return nil
  end

  return vim.uv.fs_realpath(vim.fs.normalize(path))
end

local mine = {}
for _, path in ipairs(MINE) do
  local resolved = real(vim.fn.expand(path))
  if resolved then
    mine[resolved] = true
  end
end

--- The trust list, path to what was decided about it.
---
--- Read here rather than through vim.secure.read, which prompts for anything
--- it does not find and would put an exrc dialog in front of a language
--- server. Recording still goes through vim.secure, so there is one writer.
local LIST = vim.fs.joinpath(vim.fn.stdpath("state"), "trust")

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

--- What was decided about `dir`: "allowed", "denied" or "unknown", the
--- directory that decided it, and whether that decision is one of mine to
--- take back ("list") or one this file makes ("mivn").
---
--- The nearest answer wins, so trusting a checkout covers everything inside
--- it and denying one covers everything inside that. Neovim's list matches a
--- path exactly, and walking up is what turns it into the question I mean to
--- be answering, which is whose repository this is.
function M.status(dir)
  local path = real(dir)
  if not path then
    return "unknown"
  end

  local list = decisions()

  while path do
    if list[path] == "!" then
      return "denied", path, "list"
    elseif list[path] then
      return "allowed", path, "list"
    elseif mine[path] then
      return "allowed", path, "mivn"
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

--- Every directory decided about, whichever way, for `:checkhealth mivn`.
---
--- The ones written into this file are in there too, since a list of what
--- runs code for me that leaves out three entries is worse than none.
function M.decided()
  local list = {}

  for path in pairs(mine) do
    list[#list + 1] = { path = path, state = "allowed", by = "mivn" }
  end

  for path, decision in pairs(decisions()) do
    -- A file's entry is its hash, and a denied one is "!" whether it is a
    -- file or a directory, so what it is on disk is the only way to tell.
    if not mine[path] and vim.fn.isdirectory(path) == 1 and (decision == "directory" or decision == "!") then
      list[#list + 1] = {
        path = path,
        state = decision == "!" and "denied" or "allowed",
        by = "me",
      }
    end
  end

  table.sort(list, function(a, b)
    return a.path < b.path
  end)

  return list
end

--- The workspace: the directory the editor is working in. `:cd` moves it,
--- and moving it is opening another workspace.
---
--- The global one, so a window-local `:lcd` is a place to look at a file from
--- and not a claim about whose code this is.
function M.workspace()
  return real(vim.fn.getcwd(-1, -1)) or vim.fn.getcwd(-1, -1)
end

--- The servers being gated, and whether they are on right now.
local servers, running = {}, false

--- Workspaces already spoken about this session, so that moving back and
--- forth between two of them is not a line each time.
local told = {}

--- The filetypes some server would have covered. What makes a missing server
--- worth a word: opening a text file where nothing was going to run either
--- way is not news, and should read as an ordinary editor opening an
--- ordinary file.
local function covered()
  local filetypes = {}

  for _, name in ipairs(servers) do
    for _, filetype in ipairs(vim.lsp.config[name].filetypes or {}) do
      filetypes[filetype] = true
    end
  end

  return filetypes
end

--- Say once per workspace that nothing runs here, and only once a buffer
--- turns up that something would have run for.
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

--- Start or stop every server according to the workspace.
---
--- Enabling is also what re-runs the FileType hook over the buffers already
--- open, so a workspace trusted after the fact gets its servers without a
--- restart; disabling stops the clients started for the workspace being left.
local function apply()
  local allowed = M.allows(M.workspace())
  if allowed == running then
    return
  end

  running = allowed
  vim.lsp.enable(servers, allowed)

  if not allowed then
    -- Killed rather than asked to leave, and killed here rather than left to
    -- the disabling above: leaving a workspace means the code stops running
    -- now, not once a server feels like answering, and Neovim's own timeout
    -- for that is off by default. It also keeps the exit quiet, since Neovim
    -- reports a server that left on its own and not one that was killed, and
    -- gopls leaves with 2 when the client in front of its daemon shuts down.
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

--- The directory `:MivnTrust` and `:checkhealth mivn` mean when none is
--- named, which is the workspace, resolved to whatever decided it: a server
--- ends up rooted wherever it likes, and an answer named after one of those
--- would be an answer about the wrong directory.
function M.here()
  local workspace = M.workspace()
  local _, where, source = M.status(workspace)

  return source == "list" and where or workspace
end

local ACTIONS = { "allow", "deny", "forget", "status" }

--- Record `action` about `dir` and act on it now, rather than at the next
--- start: it is usually me changing my mind about a directory I am looking
--- at, and being told to restart at that point would be a poor answer.
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

  -- Whatever was said about it before, it is open again.
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
    -- The second argument is a directory; the first is one of the words.
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
