-- Git changes in the gutter: a bar beside added and changed lines, a low
-- underscore where lines were deleted. The comparison is against git's index,
-- so the gutter empties as hunks are staged.
--
-- The plugin's own keys are kept: `]h` and `[h` jump between hunks, `gh` is an
-- operator that stages what it covers (`ghgh` for the hunk under the cursor),
-- `gH` the same for resetting, and `:lua MiniDiff.toggle_overlay()` shows the
-- old text inline.

local diff = require("mini.diff")

diff.setup({
  view = {
    -- Spelled out because the default with 'number' on is to color the line
    -- numbers instead of drawing signs, which reads as the gutter being
    -- broken. The sign column is always reserved, so the bars cost no width.
    style = "sign",
    signs = { add = "▎", change = "▎", delete = "▁" },
  },
})
