-- Select mode's tint. Neovim paints Visual and Select with the one `Visual`
-- group, but in Select the next letter I type replaces what is picked out, so
-- the selection tells them apart by color, as the status line does.
--
-- `Visual` is global, so the swap goes through 'winhighlight' and only the
-- window in Select changes. Only one window can be in Select at a time, which
-- is why one saved value is enough.

local caret = require("mivn.caret")
local selection = require("mivn.selection")

local group = vim.api.nvim_create_augroup("mivn.select", { clear = true })

--- The window whose 'winhighlight' was swapped and what it held before. Nil
--- whenever Select is not the mode.
local restore = nil

--- The caret while Select lasts. 'guicursor' has no Select mode (asking for
--- `s` is E546) and draws Select with Visual's entry, so it is an override.
local CURSOR = "MivnCursorSelect"

vim.api.nvim_create_autocmd("ModeChanged", {
  group = group,
  callback = function(ev)
    -- the first letter of the mode just entered
    if selection.selecting((ev.match:match(":(.)") or "")) then
      if restore then
        return
      end

      local win = vim.api.nvim_get_current_win()
      local held = vim.wo[win].winhighlight

      restore = { win = win, winhighlight = held }
      vim.wo[win].winhighlight = held ~= "" and (held .. ",Visual:MivnSelect") or "Visual:MivnSelect"
      caret.override("select", CURSOR)

      return
    end

    if not restore then
      return
    end

    if vim.api.nvim_win_is_valid(restore.win) then
      vim.wo[restore.win].winhighlight = restore.winhighlight
    end

    caret.drop("select")
    restore = nil
  end,
})

return {}
