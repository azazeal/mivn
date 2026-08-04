-- PageUp and PageDown, made to always go somewhere.
--
-- Vim's own pair scrolls the view and lets the cursor follow, which is kept.
-- What is not kept is what they do once there is no page left to scroll.
-- Measured on a 20-line file in a 23-line window: PageUp moves nothing at all,
-- and PageDown reaches the last line but drags the view along, leaving that
-- one line and 22 rows of empty. So when there is a page, scroll it; when
-- there is not, move the cursor to the first or last line and leave the view.

--- Move the cursor to `line`, keeping the column.
---
--- nvim_win_set_cursor rather than `gg` or `G`: those are jumps, so they would
--- push an entry onto the jumplist that Ctrl+B and Ctrl+F never push, and they
--- answer to 'startofline'. It clamps the column to the target line by itself.
local function goto_line(line)
  vim.api.nvim_win_set_cursor(0, { line, vim.api.nvim_win_get_cursor(0)[2] })
end

--- Whether the completion menu has a match highlighted.
---
--- Vim hands the menu PageUp and PageDown whenever it is open, and with
--- 'autocomplete' that is most of Insert mode, which is how these keys came to
--- do nothing while typing. So the menu only gets them once I have stepped
--- into it with an arrow, the same rule Enter follows.
local function in_menu()
  if vim.fn.pumvisible() == 0 then
    return false
  end

  return vim.fn.complete_info({ "selected" }).selected ~= -1
end

--- A page of the menu, clamped to its ends.
---
--- Vim's menu is a ring with "what I typed" as one more entry on it, so a page
--- past the end lands on nothing selected, which would silently drop me out of
--- the menu and leave the next Enter breaking the line.
local function page_menu(step)
  local pum = vim.fn.pum_getpos() -- `height` is the page, `size` the whole list
  local at = vim.fn.complete_info({ "selected" }).selected

  local to
  if step > 0 then
    to = math.min(at + pum.height, pum.size - 1)
  else
    to = math.max(at - pum.height, 0)
  end

  -- `false` for insert: the highlight moves and the line is left alone, which
  -- is what keeps Enter free until I commit.
  vim.api.nvim_select_popupmenu_item(to, false, false, {})
end

local function page(step)
  local scroll = vim.keycode(step > 0 and "<C-f>" or "<C-b>")

  return function()
    if in_menu() then
      return page_menu(step)
    end

    -- A menu I have not stepped into is in the way rather than in use, so it
    -- goes. Only when one is open: Ctrl+E without a menu copies the character
    -- from the line below instead.
    local keys = vim.fn.pumvisible() == 1 and vim.keycode("<C-e>") or ""

    -- Whether the cursor is still more than a page from the edge it heads for.
    -- "Can the view still scroll" is not the question: with a short file
    -- wholly on screen Ctrl+B does scroll, and leaves the cursor put.
    --
    -- The page is the window height, in screen rows rather than buffer lines,
    -- so wrapped lines make this an over-estimate. It only errs toward taking
    -- the edge, which is where the key was going anyway.
    local from = vim.api.nvim_win_get_cursor(0)[1]
    local last = vim.api.nvim_buf_line_count(0)
    local reach = vim.api.nvim_win_get_height(0) * vim.v.count1

    local room
    if step > 0 then
      room = from + reach < last
    else
      room = from - reach > 1
    end

    if room then
      -- A count belongs to the scroll. It can only be typed outside Insert
      -- mode, so feeding the digits back is safe wherever it is not 1.
      local count = vim.v.count1 > 1 and tostring(vim.v.count1) or ""
      vim.api.nvim_feedkeys(keys .. count .. scroll, "n", false)
      return
    end

    if keys ~= "" then
      vim.api.nvim_feedkeys(keys, "n", false)
    end

    if step > 0 then
      goto_line(last)
    else
      goto_line(1)
    end
  end
end

-- Normal, Visual and Insert. Select mode is left to Vim: there an unshifted key
-- ends the selection first ('keymodel' has "stopsel"), and taking the key would
-- take that with it.
vim.keymap.set({ "n", "x", "i" }, "<PageDown>", page(1), {
  desc = "A page down, or the last line when there is no page left",
})

vim.keymap.set({ "n", "x", "i" }, "<PageUp>", page(-1), {
  desc = "A page up, or the first line when there is no page left",
})

--- The shifted pair, selecting what the unshifted one flies over. Two things
--- keep it from simply running page() inside a selection. 'keymodel' takes
--- the raw shifted key and would run Vim's own page motion, the one whose
--- edge behavior this module exists to fix, so the selection has to be
--- opened here for the clamped version to apply at all. And "stopsel" ends a
--- selection on Ctrl+F itself, measured on stock nvim, so the scroll branch
--- would cut the selection short from inside it; the cursor moves by the
--- page instead, and the view chases it.
local function select_page(step)
  return function()
    if vim.api.nvim_get_mode().mode == "n" then
      vim.cmd("normal! v")
    end

    local from = vim.api.nvim_win_get_cursor(0)[1]
    local last = vim.api.nvim_buf_line_count(0)
    local reach = vim.api.nvim_win_get_height(0) * vim.v.count1

    if step > 0 then
      goto_line(math.min(from + reach, last))
    else
      goto_line(math.max(from - reach, 1))
    end
  end
end

-- Not Insert: from there 'keymodel' still opens the selection itself, with the
-- unclamped motion. Reproducing the open would mean leaving Insert by hand and
-- re-anchoring the exclusive selection, and a page-selection mid-typing is not
-- worth that trade yet; TODO.md if the edge ever bites there.
vim.keymap.set({ "n", "x" }, "<S-PageDown>", select_page(1), {
  desc = "Select a page down, to the last line when there is no page left",
})

vim.keymap.set({ "n", "x" }, "<S-PageUp>", select_page(-1), {
  desc = "Select a page up, to the first line when there is no page left",
})
