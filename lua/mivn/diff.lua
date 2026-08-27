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

local M = {}

--- Whether the overlay is on for this buffer, for the summary <leader>t?
--- prints. A buffer mini.diff never attached to counts as off, since there is
--- nothing there to turn on.
function M.reviewing()
  local data = diff.get_buf_data(0)

  return data ~= nil and data.overlay
end

--- Show the old text inline for every changed line, or stop; <leader>tr in
--- lua/mivn/keymaps.lua.
---
--- Guarded, because mini.diff only attaches to a buffer that has a file behind
--- it. On the banner, the tree or the terminal it raised "Buffer N is not
--- enabled" from inside the plugin, which is a stack trace for a key that
--- simply has nothing to do there.
---
--- It says which way it went, and the state is read back rather than assumed:
--- the overlay is per buffer, and on a file I have not changed there is
--- nothing on screen either way, so turning it on looks exactly like leaving
--- it off.
function M.toggle_review()
  if not diff.get_buf_data(0) then
    vim.notify("Nothing to compare here: this buffer has no file behind it.", vim.log.levels.WARN)
    return
  end

  diff.toggle_overlay()

  vim.notify(("Review: %s"):format(diff.get_buf_data(0).overlay and "on" or "off"))
end

return M
