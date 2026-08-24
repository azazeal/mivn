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

local group = vim.api.nvim_create_augroup("mivn.select", { clear = true })

--- The window whose 'winhighlight' was swapped, and what it held before.
local restore = nil

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

      return
    end

    if not restore then
      return
    end

    if vim.api.nvim_win_is_valid(restore.win) then
      vim.wo[restore.win].winhighlight = restore.winhighlight
    end

    restore = nil
  end,
})

return {}
