-- The window title: what Neovide writes in its title bar, and what a
-- terminal writes on its tab. The file when there is one, then the project.
--
-- Neovide sets 'title' and 'titlestring' itself before this config runs, so
-- the later write here is what settles them. It is not only for Neovide:
-- stock Neovim leaves 'title' off, and a terminal tab would get nothing.

local project = require("mivn.project")

local M = {}

local SEPARATOR = " · "

--- What the current buffer is, a file by its name alone, or nil for the
--- banner, the tree and an empty buffer.
local function subject()
  -- `:t` of `term://<cwd>//<pid>:/bin/bash` is the shell's name
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

  -- `[+]` with no space, the way the status line's `%m` draws it
  return vim.bo.modified and (name .. "[+]") or name
end

--- The window title as it stands. 'titlestring' calls it on every redraw
--- that touches the title, so it only reads.
function M.render()
  local what = subject()
  if not what then
    return project.name()
  end

  return what .. SEPARATOR .. project.name()
end

vim.o.title = true

-- No cutting on this side. Neovim cuts from the front, which loses the file
-- name first, while whatever draws the title knows its own room and cuts the
-- tail.
vim.o.titlelen = 0

-- NOTE: Plain `%{}` and not `%{%...%}`, so the result goes in as it stands
-- rather than being read as more items, and a file called `50%.md` keeps its
-- name.
vim.o.titlestring = "%{v:lua.require'mivn.title'.render()}"

return M
