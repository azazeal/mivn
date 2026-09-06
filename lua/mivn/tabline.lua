-- The buffer tab bar.
--
-- Vim's vocabulary disagrees with every other editor's here: a Vim *tab* is a
-- window layout, not a file, so `:tabnew` has nothing to do with this bar.
-- What is shown are *buffers*, Vim's flat global list of open files.
--
-- Moving between them needs no new key: `]b` and `[b` are next and previous
-- buffer, `]B` and `[B` last and first, and <leader>b opens the picker.

local M = {}

local project = require("mivn.project")
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
-- is to pad it: a segment as wide as the tree, colored like it.
--
-- Those columns then carry the name of the directory the tree is rooted at,
-- since they are forfeited either way and nothing else on screen keeps saying
-- which project this window is once a file is open. lua/mivn/project.lua
-- decides the name; the strip only fits it.
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

--- The tree's columns, with the name of the directory it is rooted at in them.
---
--- Exactly `columns` cells wide whatever the name is, since a nameplate that
--- decided its own width would move the tabs every time I changed directory.
--- One cell of lead-in, the way every tab has one, and the last cell left
--- blank because the window separator is drawn underneath it.
local function nameplate(columns)
  local name = project.name(columns - 2)
  local blank = columns - 1 - vim.fn.strdisplaywidth(name)

  -- WARN: what this returns is scanned for `%` items, so a directory called
  -- `50%` would be read as one.
  name = name:gsub("%%", "%%%%")

  return "%#MivnTablineProject# " .. name .. "%#MivnTablineTreeFill#" .. string.rep(" ", blank)
end

--- The tabline, as 'tabline' evaluates it on every redraw.
function M.render()
  local columns = tree_columns()

  -- Byte for byte mini's own line when there is no tree. The nameplate goes
  -- with it: these are the tree's columns, and hiding the tree is asking for
  -- the width back.
  if columns == 0 then
    return mini_string()
  end

  -- WARN: `%<` and not the default, which is the start of the line. mini fits
  -- its own string to the whole screen rather than to what is left of it, so
  -- once enough buffers are open the two together are wider than the screen,
  -- and the first thing a tabline with no `%<` gives up is its start: the
  -- nameplate went first and the tabs slid over the tree, close enough to
  -- right that clicking one of those columns switched buffers. This is where
  -- the cut lands instead. It costs the `<` Neovim draws at the point, in the
  -- colour of the tab that follows it.
  return nameplate(columns) .. "%<" .. mini_string()
end

-- The result of a `%!` expression is itself scanned for `%` items, which is
-- what keeps the highlight group above and everything mini emits working
-- through one more layer of indirection.
vim.o.tabline = "%!v:lua.require'mivn.tabline'.render()"

return M
