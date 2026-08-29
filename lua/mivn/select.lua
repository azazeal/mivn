-- Select mode's tint.
--
-- Neovim paints Visual and Select with the one `Visual` group, and the two
-- are different modes: in Visual the keys are commands, in Select the next
-- letter I type replaces what is picked out. The status line has always told
-- them apart by color, so the selection itself does too.
--
-- It is a module of its own because the group is global: pointing `Visual`
-- somewhere else would repaint every window, including the ones not in Select
-- at all. 'winhighlight' is a window option, so the window in Select is the
-- only one that changes, and it changes back on the way out. Only one window
-- can be in Select at a time, which is why one saved value is enough.
--
-- The caret is the same problem one level down. 'guicursor' has no Select
-- mode to name: the list it takes is `n v ve o i r c ci cr sm t a`, and
-- asking for `s` is E546, so Select is drawn with whatever Visual's entry
-- says. An override for as long as Select lasts is the answer, and
-- lua/mivn/caret.lua is what applies it: the option is global and two modules
-- want it, so neither of them touches it directly.

local caret = require("mivn.caret")

local group = vim.api.nvim_create_augroup("mivn.select", { clear = true })

--- The window whose 'winhighlight' was swapped and what it held before. Nil
--- whenever Select is not the mode.
local restore = nil

--- The caret while Select lasts. Named here rather than in 'guicursor',
--- which has no Select mode to hang it off; colors/basalt.lua defines it.
local CURSOR = "MivnCursorSelect"

--- Whether `mode`, the second half of a ModeChanged match, is a Select one.
--- Charwise, linewise and blockwise, the last being a raw CTRL-S byte.
local function selecting(mode)
  return mode:find("^[sS\19]") ~= nil
end

vim.api.nvim_create_autocmd("ModeChanged", {
  group = group,
  callback = function(ev)
    if selecting(ev.match:match(":(.*)$") or "") then
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
