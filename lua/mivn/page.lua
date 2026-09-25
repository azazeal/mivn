-- PageUp and PageDown that always go somewhere. With a page to scroll they are
-- Vim's own. Without one, where Vim's PageUp does nothing and its PageDown
-- drags the last line to the top, they move the cursor to the first or last
-- line and leave the view.

--- Move the cursor to `line`, keeping the column as far as the line allows.
---
--- NOTE: not `gg` or `G`, which are jumps that Ctrl+B and Ctrl+F are not, and
--- which answer to 'startofline'.
local function goto_line(line)
  vim.api.nvim_win_set_cursor(0, { line, vim.api.nvim_win_get_cursor(0)[2] })
end

--- Whether the completion menu has a match highlighted. Only then does the menu
--- get PageUp and PageDown, as with Enter, since with 'autocomplete' it is open
--- through most of Insert mode.
local function in_menu()
  if vim.fn.pumvisible() == 0 then
    return false
  end

  return vim.fn.complete_info({ "selected" }).selected ~= -1
end

--- Move the highlight a page through the menu, clamped to its ends: past them
--- Vim's ring lands on "what I typed", which drops me out of the menu.
local function page_menu(step)
  local pum = vim.fn.pum_getpos() -- `height` is the page, `size` the whole list
  local at = vim.fn.complete_info({ "selected" }).selected

  local to
  if step > 0 then
    to = math.min(at + pum.height, pum.size - 1)
  else
    to = math.max(at - pum.height, 0)
  end

  -- highlight only, so the line stays as I typed it
  vim.api.nvim_select_popupmenu_item(to, false, false, {})
end

local function page(step)
  local scroll = step > 0 and "<C-f>" or "<C-b>"

  return function()
    if in_menu() then
      return page_menu(step)
    end

    -- NOTE: a menu I have not stepped into is in the way, so it goes, back to
    -- what I typed. It has to be the API (item -1 with `finish` is Ctrl+E),
    -- which Vim applies as this returns; a fed Ctrl+E runs after the cursor has
    -- moved below and rewrites the text wherever it landed.
    local dismissed = vim.fn.pumvisible() == 1
    if dismissed then
      vim.api.nvim_select_popupmenu_item(-1, false, true, {})
    end

    -- NOTE: the question is whether the cursor is more than a page from the
    -- edge, not whether the view can scroll, since Ctrl+B scrolls a short file
    -- that is wholly on screen and leaves the cursor put. Wrapped lines make
    -- the page too big, which only errs toward the edge.
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
      -- a count can only be typed outside Insert, so feeding it back is safe
      local count = vim.v.count1 > 1 and tostring(vim.v.count1) or ""

      -- in Insert, Ctrl+F reindents the line ('indentkeys'), hence Ctrl+O
      local keys = count .. scroll
      if vim.api.nvim_get_mode().mode:sub(1, 1) == "i" then
        keys = "<C-o>" .. keys
      end

      vim.api.nvim_feedkeys(vim.keycode(keys), "n", false)
      return
    end

    local to = step > 0 and last or 1

    -- after the dismissal lands, or what I typed goes back in the wrong place
    if dismissed then
      vim.schedule(function()
        goto_line(to)
      end)
      return
    end

    goto_line(to)
  end
end

--- The shifted pair: the same distance, selecting what it crosses.
---
--- NOTE: not page() inside a selection. 'keymodel' would run Vim's own page key
--- for the shifted one, so the selection is opened here, and its "stopsel" ends
--- a selection on Ctrl+F, so the cursor moves by a page and the view follows
--- rather than scrolling first.
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

return {
  down = page(1),
  up = page(-1),
  select_down = select_page(1),
  select_up = select_page(-1),
}
