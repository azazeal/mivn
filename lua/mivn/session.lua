-- The session: what happens when buffers and windows run out.
--
-- - A session the banner claimed keeps living: closing the last file lands back
--   on the banner, and only a quit command ends the editor. An unclaimed
--   session (`git commit`, `nvim file.txt`) ends when its last file closes,
--   which is what the tool waiting on $EDITOR needs.
-- - The tree is never the only window. A layout that collapses to just the tree
--   heals with an editing window beside it, unsaved work first, unless a quit
--   command asked for that collapse; then the session ends, as stock Vim
--   answers `:q` on a last window.
-- - The blank [No Name] buffers Neovim makes when the last listed buffer goes
--   are reaped: deleted while something real is on screen, unlisted when the
--   blank is all that is left.

local M = {}

--- Whether Neovim started with nothing to edit: no arguments, or exactly one
--- naming a directory.
function M.empty_start()
  if vim.fn.argc() > 1 then
    return false
  end

  -- argv(n) is a string, but it shares one annotation with argv()
  local arg = vim.fn.argv(0) --[[@as string]]
  return vim.fn.argc() == 0 or vim.fn.isdirectory(arg) == 1
end

--- Every buffer that counts as something I am editing: an empty 'buftype' and
--- either a file name or unsaved changes.
---
--- NOTE: not keyed on 'buflisted'. netrw flips that flag on its own buffer as
--- it redraws, so a rule trusting it reads state that moves underneath it.
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

--- Reap every blank listed buffer no window shows, except `except`. `mode` is
--- "delete" while something real is on screen, and "unlist" when the blank may
--- be all that is left, where deleting it would only make Neovim add the next.
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
--- Unsaved first, since the heal follows a quit refused over unsaved work; most
--- recently used breaks the tie.
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

--- The layout rule: the tree is never the only window.
---
--- A window holding the tree cannot show a file, since nvim-tree takes its
--- buffer back, and `:q` on the last file window is enough to land there. With
--- quit intent behind the close the session ends instead; a quitall Vim refuses
--- (unsaved work somewhere) falls through to the heal, so that work gets a
--- window to be seen in.
local function heal(quit_asked)
  if vim.v.exiting ~= vim.NIL then
    return
  end

  -- floats do not count: a picker or a hover comes and goes
  local windows = vim.tbl_filter(function(win)
    return vim.api.nvim_win_get_config(win).relative == ""
  end, vim.api.nvim_list_wins())

  local tree = require("mivn.tree")
  if #windows ~= 1 or tree.window() ~= windows[1] then
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

  -- the split halved it, and panels keep their width
  if vim.api.nvim_win_is_valid(windows[1]) then
    vim.api.nvim_win_set_width(windows[1], tree.WIDTH)
  end
end

local group = vim.api.nvim_create_augroup("mivn.session", { clear = true })

local quitting = false

-- NOTE: quit intent is a flag lowered on the next tick of the event loop, not a
-- timer. The window close a quit causes runs inside the same command, so a
-- plugin closing a window later never reads as me quitting, and a refused quit
-- closes nothing and the flag just expires.
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
  -- NOTE: the flag is read here, while the closing command still runs; by the
  -- time the heal runs it is down again. The heal is deferred because the
  -- closed window stays in the window list until afterwards.
  callback = function()
    local quit_asked = quitting
    vim.schedule(function()
      heal(quit_asked)
    end)
  end,
})

-- The blank buffer Neovim leaves behind is where `:bd` on the last file puts
-- me: in a claimed session the banner comes back, in an unclaimed one the
-- session ends. The quit has no bang, so unsaved work keeps blocking it.
--
-- NOTE: keyed on arriving at a buffer, not on one being deleted. The delete
-- events fire while the window is still on its way somewhere, so a deferred
-- check sees whatever Neovim fell back to mid-flight; BufEnter is settled.
vim.api.nvim_create_autocmd("BufEnter", {
  group = group,
  callback = function(ev)
    if vim.v.exiting ~= vim.NIL then
      return
    end
    -- NOTE: UI sessions only. vim.pack.update() runs the event loop in the
    -- middle of its work, where this rule sees a blank unclaimed session and
    -- would quit a headless editor from inside the update.
    if #vim.api.nvim_list_uis() == 0 then
      return
    end

    -- NOTE: not while Neovim is still starting. The blank buffer it holds
    -- before the argument list is opened looks exactly like the one `:bd`
    -- leaves, and quitting there means a file named on the command line never
    -- opens. Under `--embed` (Neovide) the wait for the UI gives this a tick
    -- before the file arrives. Startup is the dashboard's VimEnter anyway.
    if vim.v.vim_did_enter == 0 then
      return
    end

    local dashboard = require("mivn.dashboard")

    -- already on the banner, which would otherwise trigger itself again
    if vim.bo[ev.buf].filetype == dashboard.FILETYPE then
      return
    end
    if not M.is_blank(ev.buf) or #M.real_buffers() > 0 then
      return
    end

    -- NOTE: one banner at a time. `:bd` in the tree deletes the tree's own
    -- buffer and leaves its window holding a blank one, which would open a
    -- second banner. Skipping whenever a tree window exists would be wrong: the
    -- tree is open in the ordinary case too.
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

      -- quitall: the tree or a split may still be open, and :quit closes one
      vim.cmd.quitall()
    end)
  end,
})

--- Close every listed file buffer, sparing `keep` when one is named, and leave
--- the panels standing. Without `force`, unsaved buffers are kept and counted
--- rather than stopping at the first one the way :%bd would.
local function close_files(force, keep)
  local closed, kept = 0, 0

  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if b ~= keep and vim.api.nvim_buf_is_loaded(b) and vim.bo[b].buflisted and vim.bo[b].buftype == "" then
      -- NOTE: asked before it is tried, not tried under a pcall. The E89 a
      -- modified buffer raises still reaches whoever ran the command, next to a
      -- message saying it was handled.
      if force or not vim.bo[b].modified then
        vim.api.nvim_buf_delete(b, { force = force })
        closed = closed + 1
      else
        kept = kept + 1
      end
    end
  end

  if kept > 0 then
    vim.notify(("%d buffers closed; %d with unsaved changes kept."):format(closed, kept))
  end

  -- NOTE: the BufEnter rule brings the banner back only when the current window
  -- fell to a blank buffer. Run from a panel, the emptied window is another
  -- one, so it is found here.
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
end

-- `:%bd` walks every buffer number, panels included, so the rewrite below sends
-- it here instead.
vim.api.nvim_create_user_command("MivnBdAll", function(cmd)
  close_files(cmd.bang)
end, {
  bang = true,
  desc = "What :%bd becomes: close the file buffers, leave the panels",
})

-- Close everything except what I am looking at. Vim's own spelling,
-- `:%bd|e#|bd#`, leans on the alternate file being the one wanted and leaves
-- the jumplist looking odd.
--
-- Run from a panel, which is no file, the buffer kept is the alternate one, the
-- file I last looked at.
vim.api.nvim_create_user_command("MivnBdOthers", function(cmd)
  local here = vim.api.nvim_get_current_buf()
  if vim.bo[here].buftype ~= "" or not vim.bo[here].buflisted then
    here = vim.fn.bufnr("#")
  end

  close_files(cmd.bang, here)
end, {
  bang = true,
  desc = "Close every file buffer except this one",
})

-- `:bda` and `:bdo`, since a user command has to start with a capital. Both are
-- free: Vim's own shortest forms are `bd` for bdelete and `bufd` for bufdo.
local SHORTHAND = {
  bda = "MivnBdAll",
  bdo = "MivnBdOthers",
}

local cmdline = require("mivn.cmdline")

cmdline.rewrite(function(line)
  local short, bang = line:match("^(bd%l)(!?)$")
  if SHORTHAND[short] then
    return SHORTHAND[short] .. bang
  end

  -- the % spelling only; `:1,$bd` and friends run untouched
  local word, all = line:match("^%%(%l+)(!?)$")
  if cmdline.spells(word, "bdelete", 2) then
    return "MivnBdAll" .. all
  end

  return nil
end)

return M
