-- The buffer tab bar.
--
-- Vim's vocabulary disagrees with every other editor's here: a Vim *tab* is a
-- window layout, not a file, so `:tabnew` has nothing to do with this bar.
-- What is shown are *buffers*, Vim's flat global list of open files.
--
-- Moving between them needs no new key: `]b` and `[b` are next and previous
-- buffer, `]B` and `[B` last and first, and <leader>b opens the picker.

local M = {}

local tabline = require("mini.tabline")

tabline.setup({
  show_icons = true,

  -- Let it own 'showtabline' so the bar is always visible, rather than
  -- appearing only once a second buffer exists and shifting everything down.
  set_vim_settings = true,

  -- One space of padding either side of what mini would have drawn, so a tab
  -- is a block I can see the edges of. default_format is wrapped rather than
  -- replaced because it carries the icon and enough of the path to tell two
  -- files of the same name apart. Called once per displayed buffer per redraw,
  -- so it stays a concatenation around a call mini was going to make anyway.
  format = function(buf_id, label)
    return " " .. tabline.default_format(buf_id, label) .. " "
  end,
})

-- Stepping through the bar is Ctrl+Tab and Ctrl+Shift+Tab, in
-- lua/mivn/keymaps.lua with the note on why it cannot be plain Tab.
--
-- The landing buffer stays out of the bar by being unlisted; nothing to do.

--- Where the tabs begin -------------------------------------------------------
--
-- Tabs are chrome for the buffers, so the strip starts where the buffers do
-- rather than running across the top of the file tree. Neovim's tabline is a
-- single global line with no notion of a window, so the only way to get that
-- is to pad it: a blank segment as wide as the tree, colored like it.
--
-- Measured at render time rather than cached, so a resized tree keeps the tabs
-- lined up. This runs on every redraw, so it stays one pass over the windows.

-- Whatever mini.tabline put in 'tabline', captured before this replaces it. An
-- expression rather than a literal, so it has to be evaluated, and read here
-- rather than hard-coded so an upgrade can move the entry point.
local mini_tabline = vim.o.tabline

local function mini_string()
  local expr = mini_tabline:match("^%%!(.*)$")
  if not expr then
    return mini_tabline
  end

  -- Deliberately not guarded: a broken tabline should say so, exactly as it
  -- would have when Neovim was evaluating this expression itself.
  return vim.api.nvim_eval(expr)
end

--- How many columns the file tree holds on the left of the current tab, or 0
--- when there is no tree beside the buffers.
local function tree_columns()
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local buf = vim.api.nvim_win_get_buf(win)

    -- Leftmost only: padding the left edge cannot clear a tree elsewhere.
    if vim.bo[buf].filetype == "NvimTree" and vim.fn.win_screenpos(win)[2] == 1 then
      -- The vertical separator sits between the two windows and belongs to
      -- neither, so the buffers start one column past the tree's own width.
      return vim.api.nvim_win_get_width(win) + 1
    end
  end

  return 0
end

--- The tabline, as 'tabline' evaluates it on every redraw.
function M.render()
  local columns = tree_columns()

  -- Byte for byte mini's own line when there is no tree.
  if columns == 0 then
    return mini_string()
  end

  return "%#MivnTablineTreeFill#" .. string.rep(" ", columns) .. mini_string()
end

-- The result of a `%!` expression is itself scanned for `%` items, which is
-- what keeps the highlight group above and everything mini emits working
-- through one more layer of indirection.
vim.o.tabline = "%!v:lua.require'mivn.tabline'.render()"

return M
