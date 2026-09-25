-- Git changes in the gutter, against git's index, so the gutter empties as
-- hunks are staged. mini.diff's own keys are kept: `]h`, `[h`, `gh`, `gH`.

local diff = require("mini.diff")

diff.setup({
  view = {
    -- Spelled out: with 'number' on, the default colors the line numbers
    -- instead of drawing signs.
    style = "sign",
    -- Two cells, the pad first: 'statuscolumn' puts the sign right after the
    -- line number, and the pad moves the bar over against the code.
    signs = { add = " ▎", change = " ▎", delete = " ▁" },
  },
})

local M = {}

--- Whether the overlay is on for this buffer; off where mini.diff never
--- attached.
function M.reviewing()
  local data = diff.get_buf_data(0)

  return data ~= nil and data.overlay
end

--- Show the old text inline for every changed line, or stop, and say which:
--- on a file I have not changed the two look the same. A buffer with no file
--- behind it gets a warning, since mini.diff never attached and would raise.
function M.toggle_review()
  if not diff.get_buf_data(0) then
    vim.notify("Nothing to compare here: this buffer has no file behind it.", vim.log.levels.WARN)
    return
  end

  diff.toggle_overlay()

  vim.notify(("Review: %s"):format(diff.get_buf_data(0).overlay and "on" or "off"))
end

return M
