-- The window title: what Neovide writes in its title bar, and what a
-- terminal writes on its tab.
--
-- Neovim ships with 'title' off, so nothing is written at all and a terminal
-- tab keeps the name of whatever started the editor. Neovide wanted an
-- answer and wrote its own: 'title' on, 'titlestring' set to `%F`. It does
-- look first and leaves both alone if either was already set, but its Lua
-- runs before this config (it talks to Neovim over RPC before attaching its
-- UI, and an embedded Neovim waits for that attach before reading a config),
-- so what settles it here is the later write and not the check.
--
-- `%F` is the file's absolute path, which puts the one word that identifies
-- the window last, where a taskbar cuts it off, and the banner has no file
-- at all, so an empty editor came out titled `[Scratch]`: Neovim's name for
-- a buffer with no name and nothing on disk behind it.
--
-- Not gated on `vim.g.neovide` the way the zoom keys are (lua/mivn/zoom.lua).
-- A terminal tab wants the same line, and since Neovim leaves 'title' off,
-- gating would mean foot and tmux keep getting nothing.
--
-- What it says follows the status line's rules (lua/mivn/statusline.lua):
-- the file when there is one, the project when there is not.

local M = {}

local SEPARATOR = " · "

--- The project: the name of the working directory, and nothing above it.
---
--- What tells two windows apart when both hold a `main.go`. The directory
--- alone, rather than the status line's `parent/dir`: the parent is a name
--- only where projects are filed under one, and the title has less room to
--- spend on a word that may say nothing.
local function project()
  local name = vim.fs.basename(vim.fn.getcwd())

  -- The root has no name of its own to show.
  return name ~= "" and name or "/"
end

--- What the current buffer is, or nil for the ones that are only ever a
--- window onto the project: the banner, the tree, an empty buffer.
---
--- The file is its name alone, not its path: a title is read at a glance in
--- a switcher, and the directories in front of the name are the part that
--- gets cut.
local function subject()
  -- `:t` of `term://<cwd>//<pid>:/bin/bash` is the shell's name, which is
  -- what the status line shows for a terminal too.
  if vim.bo.buftype == "terminal" then
    return vim.fn.expand("%:t")
  end

  if vim.bo.buftype == "help" then
    return "help " .. vim.fn.expand("%:t:r")
  end

  if vim.bo.buftype == "quickfix" then
    return "quickfix"
  end

  local name = vim.fn.expand("%:t")
  if vim.bo.buftype ~= "" or name == "" then
    return nil
  end

  -- `[+]` with no space in front of it, the way the status line's `%m`
  -- renders it, so the two say unsaved the same way.
  return vim.bo.modified and (name .. "[+]") or name
end

--- The title of the window as it stands.
---
--- Called through 'titlestring' below, so it runs on every redraw that
--- touches the title and does no work heavier than reading the buffer.
function M.render()
  local what = subject()
  if not what then
    return project()
  end

  return what .. SEPARATOR .. project()
end

vim.o.title = true

-- No truncation on this side. Neovim otherwise cuts the title to 'titlelen'
-- percent of the *editor's* columns (85 by default), and it cuts from the
-- front, so an 80-column window would spend the file name to keep the
-- project. Whoever draws the title is the one that knows how much room it
-- has, and every one of them cuts the tail.
vim.o.titlelen = 0

-- Plain `%{}` and not `%{%...%}`: the result is inserted as it stands rather
-- than read back as more status-line items, so a file called `50%.md` is a
-- file called `50%.md`.
vim.o.titlestring = "%{v:lua.require'mivn.title'.render()}"

return M
