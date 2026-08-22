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
    -- Two cells, the pad first: the sign field now sits immediately right of
    -- the last digit ('statuscolumn' in init.lua), so a bare glyph would be
    -- flush against the number instead of the border, which is the same
    -- complaint one column over. With the pad the ink lands just before the
    -- code, a rail on it.
    signs = { add = " ▎", change = " ▎", delete = " ▁" },
  },
})
