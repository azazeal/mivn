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
-- says. So the option itself is swapped for as long as Select lasts, the way
-- lua/mivn/panel.lua does it to hide the cursor: an appended `a:` names a
-- highlight group for every mode without touching a single shape, and the
-- saved value goes back on the way out.

local group = vim.api.nvim_create_augroup("mivn.select", { clear = true })

--- The window whose 'winhighlight' was swapped, what it held before, and the
--- 'guicursor' that was in force. Nil whenever Select is not the mode.
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

      restore = { win = win, winhighlight = held, guicursor = vim.o.guicursor }
      vim.wo[win].winhighlight = held ~= "" and (held .. ",Visual:MivnSelect") or "Visual:MivnSelect"
      vim.o.guicursor = restore.guicursor .. ",a:" .. CURSOR .. "/" .. CURSOR

      return
    end

    if not restore then
      return
    end

    if vim.api.nvim_win_is_valid(restore.win) then
      vim.wo[restore.win].winhighlight = restore.winhighlight
    end

    vim.o.guicursor = restore.guicursor
    restore = nil
  end,
})

return {}
