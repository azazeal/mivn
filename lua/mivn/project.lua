-- What to call the directory I am working in: the last part of its path, with
-- `~` for my home and `/` for the root. The tab bar, the status line and the
-- window title all show it, so it is decided once, here.

local M = {}

-- Marks a name that did not fit, in the one cell left to say so with.
local ELLIPSIS = "…"

--- The name as it stands, or nil when the directory has changed under it.
local cached = nil

local function read()
  -- NOTE: the global working directory and not the window's. An `:lcd` is a
  -- place to look at a file from, not a change of project.
  local last = vim.fn.fnamemodify(vim.fn.getcwd(-1, -1), ":~:t")

  -- `:t` of the root is empty
  return last ~= "" and last or "/"
end

--- `text`, or as much of it as fits in `columns` cells with the ellipsis.
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

--- What to call the directory this editor is working in. Given `columns`, a
--- name wider than that is cut to fit and ends in an ellipsis.
function M.name(columns)
  cached = cached or read()

  return columns and clip(cached, columns) or cached
end

-- Read once per directory rather than on every redraw. A window's `:lcd`
-- fires `DirChanged` too, which costs one read of the same answer.
vim.api.nvim_create_autocmd("DirChanged", {
  group = vim.api.nvim_create_augroup("mivn.project", { clear = true }),
  callback = function()
    cached = nil
  end,
})

return M
