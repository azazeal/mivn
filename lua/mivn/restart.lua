-- :restart: the panels around the session it carries, and the refusal when the
-- window is not on this machine.
--
-- :restart starts the new Neovim on the machine the server runs on and hands
-- every UI that server's listen address (:h :restart). A window on another
-- machine cannot reach that address, so it dies and the new server lingers
-- headless. Nothing inside Neovim can relaunch a UI elsewhere, so refusing
-- loudly is the whole answer there.

local MESSAGE = "This editor runs on another machine, and :restart cannot reattach a remote window. "
  .. "Close the window and open the project again."

--- Whether the window is on another machine: declared by a nonempty
--- $MIVN_REMOTE_UI, or else read off Neovide's remote clipboard bridge, which
--- names g:clipboard "neovide" exactly when its remote flag is on (--wsl,
--- --server). g:neovide_no_custom_clipboard turns the bridge off, which is what
--- the variable is for.
---
--- NOTE: asked on every restart, never once at startup. Neovide sets up its
--- clipboard around the time the config loads, so an early answer can be wrong.
local function remote_ui()
  if (vim.env.MIVN_REMOTE_UI or "") ~= "" then
    return true
  end

  return (vim.g.clipboard or {}).name == "neovide"
end

vim.api.nvim_create_user_command("MivnRestartRemote", function()
  vim.notify(MESSAGE, vim.log.levels.WARN)
end, { desc = "What :restart becomes when the window is remote" })

--- The panels, and the order they are put back in -----------------------------
--
-- A bang-less :restart carries the session across, but a session names a
-- window's buffer by file and a panel has none: the tree would come back as an
-- empty, writable buffer named NvimTree_1 and the terminal as a second shell.
-- So the panels step aside before the session is written and are put back once
-- it has been sourced.
--
-- The order is the one they open in by hand: the tree takes the left edge for
-- the full height, the terminal the bottom edge for the full width, under the
-- tree.
local PANELS = {
  { name = "tree", module = "mivn.tree" },
  { name = "terminal", module = "mivn.terminal" },
}

--- Put the panels named in `names` back, then land where the session left me.
--- Run by the new editor once :restart has sourced the session. `names` is
--- comma-joined because it crosses in :restart's [command] tail, which is an Ex
--- command line and not a Lua value.
local function reopen(names)
  local wanted = {}
  for name in names:gmatch("[^,]+") do
    wanted[name] = true
  end

  local win = vim.api.nvim_get_current_win()

  for _, panel in ipairs(PANELS) do
    if wanted[panel.name] then
      require(panel.module).toggle()
    end
  end

  -- both panels take the cursor as they open; the session's window wins
  if vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_set_current_win(win)
  end
  vim.cmd.stopinsert()
end

-- :restart as typed. `rest` is the shortest spelling that resolves to it (`res`
-- is :resize), and whatever follows the word is :restart's own [+cmd][command]
-- tail. A remote window refuses every spelling; otherwise only the bare
-- bang-less one, the one wanting a session, is taken.
local cmdline = require("mivn.cmdline")

cmdline.rewrite(function(line)
  local word, bang, tail = line:match("^%s*(%l+)(!?)(.*)$")
  if not cmdline.spells(word, "restart", 4) then
    return nil
  end

  if remote_ui() then
    return "MivnRestartRemote"
  end

  if bang ~= "" then
    return nil
  end

  -- a tail of my own needs the one [command] slot the reopen rides in, so it
  -- gives up the session
  return tail:match("^%s*$") and "MivnRestart" or ("restart!" .. tail)
end)

--- Restart, keeping the session and the panels. `plain` is a restart without
--- the session, what `:restart!` and a counted ZR mean, and it needs none of
--- the panel work.
---
--- ZR cannot just be fed back as a key: the panels have to close first, and the
--- reopen rides in the [command] tail, which only the command form has.
local function restart(plain)
  if remote_ui() then
    vim.notify(MESSAGE, vim.log.levels.WARN)
    return
  end

  if plain then
    -- NOTE: :restart! refuses on unsaved work by raising, which arrives as a
    -- Lua traceback, and unlike the bang-less form it prints nothing itself. So
    -- the Vim error is picked out of the Lua one and said here.
    local ok, err = pcall(vim.cmd, "restart!")
    if not ok then
      vim.notify(err:match("E%d+:[^\n]*") or err, vim.log.levels.ERROR)
    end

    return
  end

  local open = {}
  for _, panel in ipairs(PANELS) do
    local module = require(panel.module)
    if module.is_open() then
      open[#open + 1] = panel.name
      module.toggle()
    end
  end

  -- NOTE: a restart that runs never returns from this call, so getting past it
  -- means it was refused, usually over unsaved work. :restart says why itself
  -- and then raises too; the pcall keeps that from arriving as a traceback. The
  -- panels go back, since nothing happened.
  local names = table.concat(open, ",")
  if not pcall(vim.cmd, ("restart lua require('mivn.restart').reopen(%q)"):format(names)) then
    reopen(names)
  end
end

-- NOTE: the callback cannot be `restart` itself. A command hands its callback a
-- table of what was typed, every table is true in Lua, and `plain` would be on
-- for every :restart, the one spelling that came here for a session.
vim.api.nvim_create_user_command("MivnRestart", function()
  restart(false)
end, {
  desc = "What :restart becomes: the panels step aside so the session can be written",
})

return { restart = restart, reopen = reopen }
