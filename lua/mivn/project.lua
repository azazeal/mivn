-- What to call the directory I am working in.
--
-- Three surfaces name it, and two of them are on screen at the same time, so
-- they had better say it the same way: the nameplate at the left end of the
-- tab strip (lua/mivn/tabline.lua), the status line where the file name would
-- go when the window holds no file (lua/mivn/statusline.lua), and the window
-- title (lua/mivn/title.lua). A nameplate reading `mivn` four rows above a
-- status line reading `azazeal/mivn` is a puzzle rather than an answer.
--
-- The name is the last part of the path, written home-relative, so my home
-- reads `~` instead of my user name and the root reads `/`. Neither of those
-- two is a case in here: they are what Vim's own `:~` and `:t` already leave
-- behind.
--
-- The last part alone, never the parent along with it. `nefeloma/web` does
-- tell itself apart from some other `web`, but only where projects are filed
-- under a name that means something, which is my machine and not everyone's.
-- `pwd` is the answer when the name on its own is not enough.

local M = {}

-- Marks a name that did not fit, in the one cell left to say so with.
local ELLIPSIS = "…"

--- The name as it stands, or nil when the directory has changed under it.
local cached = nil

local function read()
  -- The global working directory and not the window's: an `:lcd` is a place
  -- to look at a file from, not a claim about which project this window is.
  -- lua/mivn/trust.lua reads it this way for the same reason.
  local last = vim.fn.fnamemodify(vim.fn.getcwd(-1, -1), ":~:t")

  -- `:t` of the root is empty. It is the one directory whose name is the
  -- separator itself.
  return last ~= "" and last or "/"
end

--- `text`, or as much of it as fits in `columns` cells with the ellipsis.
---
--- Cells and not bytes, so a name in Japanese is cut where it looks cut
--- rather than two columns past it.
local function clip(text, columns)
  if vim.fn.strdisplaywidth(text) <= columns then
    return text
  end

  local room = columns - vim.fn.strdisplaywidth(ELLIPSIS)

  for n = vim.fn.strchars(text), 1, -1 do
    local head = vim.fn.strcharpart(text, 0, n)

    if vim.fn.strdisplaywidth(head) <= room then
      return head .. ELLIPSIS
    end
  end

  return ELLIPSIS
end

--- What to call the directory this editor is working in.
---
--- `columns` is how many cells the caller has for it, and only the tab strip
--- has a number: a name that does not fit is cut and marked. Left out, the
--- name comes back whatever length it is, which is what a surface that can
--- shorten a string itself wants.
function M.name(columns)
  cached = cached or read()

  return columns and clip(cached, columns) or cached
end

-- Read once per directory rather than per redraw: two of the three callers
-- rebuild many times a second and neither may do work. `DirChanged` is the
-- only event that can change the answer, and a window-local `:lcd` firing it
-- too costs one read that returns the same string.
vim.api.nvim_create_autocmd("DirChanged", {
  group = vim.api.nvim_create_augroup("mivn.project", { clear = true }),
  callback = function()
    cached = nil
  end,
})

return M
