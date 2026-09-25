-- The buffer tab bar: one tab per listed buffer. Vim's own tabs are window
-- layouts and have nothing to do with it.

local M = {}

local project = require("mivn.project")
local tabline = require("mini.tabline")
local tree = require("mivn.tree")

tabline.setup({
  show_icons = true,

  -- It owns 'showtabline', so the bar is always there rather than showing up
  -- with a second buffer and pushing everything down.
  set_vim_settings = true,

  -- A space either side of mini's own label, so a tab is a block I can see
  -- the edges of.
  format = function(buf_id, label)
    return " " .. tabline.default_format(buf_id, label) .. " "
  end,
})

--- Where the tabs begin -------------------------------------------------------
--
-- The tabs start where the buffers do, not over the file tree. Neovim's
-- tabline is one line for the whole screen, so this pads it with a segment as
-- wide as the tree and coloured like it, with the project's name in it. The
-- width is read on every redraw, so a resized tree keeps the tabs lined up.

-- What mini.tabline put in 'tabline', read before this replaces it rather
-- than written out, so an upgrade can move it.
local mini_tabline = vim.o.tabline

local function mini_string()
  local expr = mini_tabline:match("^%%!(.*)$")
  if not expr then
    return mini_tabline
  end

  -- not guarded: a broken tabline should say so, as it would without this
  return vim.api.nvim_eval(expr)
end

--- How many columns the file tree holds on the left of the current tab, or 0
--- when there is no tree beside the buffers.
local function tree_columns()
  local win = tree.window()

  -- leftmost only: padding the left edge cannot clear a tree anywhere else
  if not win or vim.fn.win_screenpos(win)[2] ~= 1 then
    return 0
  end

  -- the separator belongs to neither window, so the buffers start past it
  return vim.api.nvim_win_get_width(win) + 1
end

--- The tree's columns with the project's name in them, exactly `columns` cells
--- wide whatever the name, so the tabs never move. The last cell stays blank,
--- over the window separator.
local function nameplate(columns)
  local name = project.name(columns - 2)
  local blank = columns - 1 - vim.fn.strdisplaywidth(name)

  -- NOTE: what this returns is scanned for `%` items, so a directory called
  -- `50%` would be read as one.
  name = name:gsub("%%", "%%%%")

  return "%#MivnTablineProject# " .. name .. "%#MivnTablineTreeFill#" .. string.rep(" ", blank)
end

--- The tabline, as 'tabline' evaluates it on every redraw.
function M.render()
  local columns = tree_columns()

  -- no tree, no nameplate: mini's own line, byte for byte
  if columns == 0 then
    return mini_string()
  end

  -- NOTE: the `%<` puts the cut after the nameplate. mini fits its line to the
  -- whole screen, so with enough buffers open the two are too wide together,
  -- and without it the nameplate is cut first and the tabs slide over the
  -- tree, where a click lands on the wrong buffer.
  return nameplate(columns) .. "%<" .. mini_string()
end

-- What a `%!` expression returns is scanned for `%` items again, which is what
-- makes the highlight groups in render() and mini's line work.
vim.o.tabline = "%!v:lua.require'mivn.tabline'.render()"

return M
