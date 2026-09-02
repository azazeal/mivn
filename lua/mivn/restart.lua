-- :restart: the panels around the session it now carries, and the refusal
-- when the window is not on this machine.
--
-- :restart spawns the new Neovim on the machine the *server* runs on and
-- hands every UI that server's listen address (:h :restart). With the window
-- on another machine (Neovide over ssh), that address names a socket on the
-- wrong filesystem: the window dies trying to connect, and the new server
-- lingers headless with nothing ever attaching. Both halves are measured,
-- not assumed: gui.txt documents the same-system limit, and a UI-less
-- :restart observably leaves a dangling `nvim --embed --headless` behind.
-- Nothing running inside Neovim can relaunch a UI on another machine, so
-- refusing loudly is the whole feature.
--
-- Remote is declared, or failing that sniffed. $MIVN_REMOTE_UI set to
-- anything nonempty is the supported knob for launchers (README.md).
-- The fallback recognizes Neovide's remote clipboard bridge: it registers
-- g:clipboard with name "neovide" exactly when its remote flag is on, which
-- its --wsl and --server modes both set. The sniff breaks if
-- g:neovide_no_custom_clipboard disables the bridge, which is what the
-- explicit variable is for. Checked when a restart is attempted rather than
-- at startup, since Neovide wires its clipboard around config-load time.

local MESSAGE = "This editor runs on another machine, and :restart cannot reattach a remote window. "
  .. "Close the window and open the project again."

local function remote_ui()
  if (vim.env.MIVN_REMOTE_UI or "") ~= "" then
    return true
  end

  return (vim.g.clipboard or {}).name == "neovide"
end

vim.api.nvim_create_user_command("MivnRestartRemote", function()
  vim.notify(MESSAGE, vim.log.levels.WARN)
end, { desc = "What :restart becomes when the window is remote" })

--- The panels, and the order they are put back in ------------------------------
--
-- Since Neovim 0.12.5 a bang-less :restart carries the session across: it
-- writes one with :mksession, restarts, sources it, and the layout, the open
-- files and the folds are all back. The panels are the one thing that cannot
-- ride along, because a session names a window's buffer by file and a panel
-- has no file: the tree comes back as an empty buffer named NvimTree_1,
-- writable and listed in the tab bar, and the terminal as a second shell.
--
-- So the panels step out of the way before the session is written and are put
-- back once it has been sourced. That is also the only honest answer for the
-- terminal: a shell does not survive the editor it runs in, so it comes back
-- empty either way.
--
-- The order is the one they open in by hand: the tree takes the left edge for
-- the full height, the terminal the bottom edge for the full width, under the
-- tree.
local PANELS = {
  { name = "tree", module = "mivn.tree" },
  { name = "terminal", module = "mivn.terminal" },
}

--- Put the panels named in `names` back, then land where the session left me.
---
--- Run by the *new* editor, once :restart has sourced the session; restart()
--- below arranges the handoff. `names` is comma-joined rather than a list
--- because what crosses is :restart's [command] tail, which is one Ex command
--- line and not a Lua value.
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

  -- Both panels take the cursor as they open: the tree does not reliably
  -- honour `focus = false` (see lua/mivn/tree.lua) and the terminal lands
  -- typing on purpose. The session already said which window I was in, and it
  -- gets the last word.
  if vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_set_current_win(win)
  end
  vim.cmd.stopinsert()
end

-- The same rewrite the tree's :bd guard uses: a user command cannot shadow a
-- built-in, so the command line is changed the moment before it runs. `rest`
-- is the shortest spelling that resolves to :restart (`res` is :resize;
-- measured with fullcommand()), and whatever follows the word is :restart's
-- own [+cmd][command] tail.
--
-- Only the bare bang-less spelling is taken, since that is the one wanting a
-- session. `:restart!` is the way to skip one and needs no help.
vim.api.nvim_create_autocmd("CmdlineLeavePre", {
  group = vim.api.nvim_create_augroup("mivn.restart", { clear = true }),
  desc = "Refuse :restart when the window is remote, and let the panels out of the session",
  callback = function()
    if vim.fn.getcmdtype() ~= ":" then
      return
    end

    -- WARN: nothing below may return setcmdline's result. It answers 0 on
    -- success, every number is true in Lua, and an autocmd callback returning
    -- true deletes itself.
    local word, bang, tail = vim.fn.getcmdline():match("^%s*(%l+)(!?)(.*)$")
    if not (word and #word >= 4 and ("restart"):find(word, 1, true) == 1) then
      return
    end

    if remote_ui() then
      vim.fn.setcmdline("MivnRestartRemote")
    elseif bang == "" and tail:match("^%s*$") then
      vim.fn.setcmdline("MivnRestart")
    elseif bang == "" then
      -- A [+cmd] or a [command] of my own. There is one [command] slot and it
      -- would have to carry both mine and the reopen, so a tail keeps its
      -- command and gives up the session.
      vim.fn.setcmdline("restart!" .. tail)
    end
  end,
})

--- Restart, keeping the session and the panels; ZR and :restart both land
--- here, the key through lua/mivn/keymaps.lua and the command through the
--- rewrite above.
---
--- ZR is :restart's Normal-mode spelling, but the key cannot simply be fed
--- back through: the panels have to be closed first, and the reopen has to
--- ride along in the [command] tail, which only the command form can carry.
local function restart()
  if remote_ui() then
    vim.notify(MESSAGE, vim.log.levels.WARN)
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

  -- A restart that runs never comes back from this line, so reaching the next
  -- one means it was refused; unsaved work is the usual reason. :restart says
  -- so itself and then raises as well, and the pcall is what keeps its own
  -- message from arriving buried in a Lua traceback. The panels go back the
  -- way they were, since nothing happened.
  local names = table.concat(open, ",")
  if not pcall(vim.cmd, ("restart lua require('mivn.restart').reopen(%q)"):format(names)) then
    reopen(names)
  end
end

vim.api.nvim_create_user_command("MivnRestart", restart, {
  desc = "What :restart becomes: the panels step aside so the session can be written",
})

return { restart = restart, reopen = reopen }
