-- The session: one owner for what happens when buffers and windows run out.
--
-- Three modules used to fight Neovim's endgame each in its own corner: the
-- dashboard decided when the banner comes back and when closing the last
-- file quits, the tree healed collapsed layouts and read quit intent off a
-- wall clock, and the terminal swept up the blank buffers its exit left
-- behind. Same states, three owners, coordinated by scheduling accidents.
-- This module is the one owner. The rules:
--
-- - A session the banner claimed keeps living, the way Zed and VS Code do:
--   closing the last file lands back on the banner, and only a quit
--   command ends the editor. An unclaimed session (`git commit`,
--   `nvim file.txt`) ends when its last file closes, which is what the
--   tool waiting on $EDITOR needs.
-- - The tree is never the only window. A layout that collapses to just the
--   tree heals with an editing window beside it, unsaved work first,
--   unless a quit command asked for exactly that collapse; then the
--   session ends, the same answer stock Vim gives `:q` on a last window.
-- - The blank [No Name] buffers Neovim conjures when the last listed
--   buffer goes are reaped: deleted while something real is on screen,
--   unlisted when the blank is all that is left.
--
-- Quit intent is a flag QuitPre raises and the next event-loop tick
-- lowers, not a timer: the window close a quit causes runs inside the same
-- command, so WinClosed reads the flag synchronously and cannot confuse a
-- plugin closing a window with me quitting. A refused quit (unsaved work)
-- closes nothing, and the flag simply expires.

local M = {}

--- Whether Neovim started with nothing to edit: no arguments, or exactly
--- one naming a directory. The dashboard and the tree both key their
--- startup on this one answer.
function M.empty_start()
  if vim.fn.argc() > 1 then
    return false
  end

  -- argv() returns a list and argv(n) a string, under one annotation, so
  -- the cast says which call this is.
  local arg = vim.fn.argv(0) --[[@as string]]
  return vim.fn.argc() == 0 or vim.fn.isdirectory(arg) == 1
end

--- Every buffer that counts as something I am actually editing.
---
--- Not keyed on 'buflisted': netrw flips that flag on its own buffer as it
--- redraws, so a rule trusting it reads state that moves underneath it. A
--- real buffer has an empty 'buftype' and either a file name or unsaved
--- changes.
function M.real_buffers()
  local banner = require("mivn.dashboard").FILETYPE

  return vim.tbl_filter(function(buf)
    return vim.api.nvim_buf_is_loaded(buf)
      and vim.bo[buf].buftype == ""
      and vim.bo[buf].filetype ~= banner
      and (vim.api.nvim_buf_get_name(buf) ~= "" or vim.bo[buf].modified)
  end, vim.api.nvim_list_bufs())
end

--- Is this the blank buffer Neovim leaves behind when nothing is open?
function M.is_blank(buf)
  if vim.bo[buf].buftype ~= "" or vim.bo[buf].modified then
    return false
  end
  if vim.api.nvim_buf_get_name(buf) ~= "" then
    return false
  end

  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  return #lines <= 1 and (lines[1] or "") == ""
end

--- Reap every blank listed buffer nothing shows, except `except`.
---
--- Two modes, because deleting is only safe while some other buffer
--- exists to take its place: "delete" while something real is on screen,
--- "unlist" when the blank may be all that is left and deleting it would
--- just conjure the next one into the tab bar.
function M.reap_blanks(mode, except)
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if
      b ~= except
      and vim.api.nvim_buf_is_loaded(b)
      and vim.bo[b].buflisted
      and vim.bo[b].buftype == ""
      and not vim.bo[b].modified
      and vim.api.nvim_buf_get_name(b) == ""
      and vim.fn.bufwinid(b) == -1
    then
      if mode == "delete" then
        pcall(vim.api.nvim_buf_delete, b, { force = true })
      else
        vim.bo[b].buflisted = false
      end
    end
  end
end

--- The buffer to put back in front of me, or nil for the landing buffer.
---
--- Unsaved first: the heal runs after a quit was refused over unsaved
--- work, so that work is what the window is for. Most recently used breaks
--- the tie.
local function last_real_buffer()
  local best, best_key = nil, -1

  for _, info in ipairs(vim.fn.getbufinfo({ buflisted = 1 })) do
    local modified = vim.bo[info.bufnr].modified
    local ok = vim.api.nvim_buf_is_valid(info.bufnr)
      and vim.bo[info.bufnr].buftype == ""
      and (info.name ~= "" or modified)

    local key = info.lastused + (modified and 2 ^ 40 or 0)
    if ok and key > best_key then
      best, best_key = info.bufnr, key
    end
  end

  return best
end

--- The layout invariant: the tree is never the only window.
---
--- A window holding the tree cannot show a file, since nvim-tree takes its
--- buffer back, so a layout that is nothing but the tree is one I cannot
--- type my way out of, and `:q` on the last file window is enough to land
--- there. With quit intent behind the close the session ends instead; a
--- quitall Vim refuses (unsaved work somewhere) falls through to the heal,
--- so that work gets a window to be seen in.
local function heal(quit_asked)
  if vim.v.exiting ~= vim.NIL then
    return
  end

  -- Floating windows do not count: a picker or a hover comes and goes.
  local windows = vim.tbl_filter(function(win)
    return vim.api.nvim_win_get_config(win).relative == ""
  end, vim.api.nvim_list_wins())

  if #windows ~= 1 then
    return
  end

  local tree = windows[1]
  if vim.bo[vim.api.nvim_win_get_buf(tree)].filetype ~= "NvimTree" then
    return
  end

  if quit_asked and pcall(vim.cmd.quitall) then
    return
  end

  vim.cmd("rightbelow vsplit")
  local win = vim.api.nvim_get_current_win()

  local buf = last_real_buffer()
  if buf then
    vim.api.nvim_win_set_buf(win, buf)
  else
    require("mivn.dashboard").open()
  end

  -- The split halved it. Panels keep their width.
  if vim.api.nvim_win_is_valid(tree) then
    vim.api.nvim_win_set_width(tree, require("mivn.tree").WIDTH)
  end
end

local group = vim.api.nvim_create_augroup("mivn.session", { clear = true })

local quitting = false

vim.api.nvim_create_autocmd("QuitPre", {
  group = group,
  desc = "Remember, for one tick, that window closes come from a quit",
  callback = function()
    quitting = true
    vim.schedule(function()
      quitting = false
    end)
  end,
})

vim.api.nvim_create_autocmd("WinClosed", {
  group = group,
  desc = "Heal a layout that collapsed to just the tree",
  -- The flag is read here, synchronously, while the closing command is
  -- still the one running; the heal itself is deferred because the closed
  -- window is still in the window list until afterwards.
  callback = function()
    local quit_asked = quitting
    vim.schedule(function()
      heal(quit_asked)
    end)
  end,
})

-- The blank buffer Neovim leaves behind is where `:bd` on the last file
-- puts me: in a claimed session the banner comes back, in an unclaimed one
-- the session ends. No bang on the quit, ever: unsaved work keeps blocking
-- it, and `:bd` refuses a modified buffer anyway, so this path is only
-- reachable after a deliberate write or a deliberate `!`.
--
-- Keyed on arriving at a buffer rather than on one being deleted: the
-- delete events fire while the window is still on its way somewhere, so a
-- deferred check sees whatever Neovim fell back to mid-flight. BufEnter is
-- settled.
vim.api.nvim_create_autocmd("BufEnter", {
  group = group,
  callback = function(ev)
    if vim.v.exiting ~= vim.NIL then
      return
    end
    -- UI sessions only. A headless run is automation, and this hook firing
    -- there is not hypothetical: vim.pack.update() pumps the event loop
    -- mid-command (vim.wait under the hood), this callback saw a blank
    -- unclaimed session and quitall'd nvim from inside the update. That is
    -- how the weekly plugin-update job went green while updating nothing.
    if #vim.api.nvim_list_uis() == 0 then
      return
    end

    local dashboard = require("mivn.dashboard")

    -- Already there. Without this the landing buffer re-triggers itself.
    if vim.bo[ev.buf].filetype == dashboard.FILETYPE then
      return
    end
    if not M.is_blank(ev.buf) or #M.real_buffers() > 0 then
      return
    end

    -- One at a time. `:bd` with the cursor in the tree deletes the tree's
    -- own buffer and leaves its window holding a blank one, which would
    -- otherwise open a second banner. Not also skipping when a tree window
    -- exists: the tree is open in the ordinary case too, and testing for
    -- it would stop the banner coming back after `:bd` on the last file.
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == dashboard.FILETYPE then
        return
      end
    end

    vim.schedule(function()
      if vim.api.nvim_get_current_buf() ~= ev.buf or not M.is_blank(ev.buf) then
        return
      end

      if dashboard.claimed() then
        dashboard.open()
        return
      end

      -- quitall, not quit: the tree or a split may still be open, and
      -- closing one window would leave the session hanging on the rest.
      vim.cmd.quitall()
    end)
  end,
})

-- `:%bd` means "close everything", but its range walks every buffer
-- number, panels included, so it used to take the tree down with the
-- files. The rewrite below (the same CmdlineLeavePre move restart.lua and
-- the tree's :bd guard make) sends it here instead: every listed file
-- buffer goes, the panels stand, and the BufEnter rule above brings the
-- banner back on its own.
--
-- Without the bang, unsaved buffers are kept and counted rather than
-- stopping at the first one the way :%bd would; the bang takes them too.
vim.api.nvim_create_user_command("MivnBdAll", function(cmd)
  local closed, kept = 0, 0

  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(b) and vim.bo[b].buflisted and vim.bo[b].buftype == "" then
      if pcall(vim.api.nvim_buf_delete, b, { force = cmd.bang }) then
        closed = closed + 1
      else
        kept = kept + 1
      end
    end
  end

  if kept > 0 then
    vim.notify(("%d buffers closed; %d with unsaved changes kept."):format(closed, kept))
  end

  -- The BufEnter rule brings the banner back only when the *current*
  -- window fell to a blank buffer. Run from a panel (cursor parked in the
  -- tree), the emptied window is some other one, so it is found by hand:
  -- measured, not hypothetical.
  vim.schedule(function()
    local dashboard = require("mivn.dashboard")
    if not dashboard.claimed() or #M.real_buffers() > 0 then
      return
    end

    for _, w in ipairs(vim.api.nvim_list_wins()) do
      if vim.api.nvim_win_get_config(w).relative == "" and M.is_blank(vim.api.nvim_win_get_buf(w)) then
        vim.api.nvim_set_current_win(w)
        dashboard.open()
        return
      end
    end
  end)
end, {
  bang = true,
  desc = "What :%bd becomes: close the file buffers, leave the panels",
})

vim.api.nvim_create_autocmd("CmdlineLeavePre", {
  group = group,
  desc = "Rewrite :%bd to close files but not panels",
  callback = function()
    if vim.fn.getcmdtype() ~= ":" then
      return
    end

    -- The % spelling only, and any prefix of "bdelete" at least two
    -- letters long. `:1,$bd` and friends run untouched: narrow on purpose,
    -- the way the tree's :bd guard is.
    local word, bang = vim.fn.getcmdline():match("^%%(%l+)(!?)$")
    if word and #word >= 2 and ("bdelete"):find(word, 1, true) == 1 then
      vim.fn.setcmdline("MivnBdAll" .. bang)
    end
  end,
})

return M
