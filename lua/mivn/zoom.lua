-- Ctrl with =, - or 0 zooms the window, the keys everything else on this
-- desktop zooms with. The numpad's + and - do the same, for the hand that is
-- already there.
--
-- Neovide only. In a terminal these keys never reach nvim: foot takes
-- Ctrl+= / Ctrl+- / Ctrl+0 itself and resizes its own font, which is the
-- right owner there, so there is nothing to map and nothing to fix.
--
-- The step is foot's, near enough. foot moves a 12pt font by 0.5pt a press
-- ('font-size-adjustment', its default), so one press is a 24th either way.
-- foot adds that same 0.5pt every time while this multiplies, so the two
-- drift apart the further from 100% I go, which no press in practice
-- notices.
--
-- Nothing here sets 'guifont', for family or for size. The size comes from
-- ~/.config/neovide/config.toml, rendered per host so that nvim in Neovide
-- and nvim in foot come out the same size, and a 'guifont' set on this side
-- wins over that whole file without warning. It is also why the reset writes
-- 1.0 instead of a size: 100% has to keep meaning "what that file asked
-- for".

if not vim.g.neovide then
  return
end

local STEP = 1 + 0.5 / 12

-- Under half the text stops being readable and over triple the window holds
-- nothing worth looking at, so the keys stop there rather than carry on.
local MIN, MAX = 0.5, 3.0

-- Zooming while typing, while selecting and in the terminal panel too: the
-- window is the same window in all of them.
local MODES = { "n", "i", "x", "s", "t" }

local function by(step)
  return function()
    local factor = (vim.g.neovide_scale_factor or 1.0) * step

    vim.g.neovide_scale_factor = math.min(math.max(factor, MIN), MAX)
  end
end

-- The numpad keys sit next to the ones above rather than replace them: the
-- keypad sends its own codes, so a <C-=> map never sees <C-kPlus>.
vim.keymap.set(MODES, "<C-=>", by(STEP), {
  desc = "Zoom in",
})

vim.keymap.set(MODES, "<C-kPlus>", by(STEP), {
  desc = "Zoom in",
})

vim.keymap.set(MODES, "<C-->", by(1 / STEP), {
  desc = "Zoom out",
})

vim.keymap.set(MODES, "<C-kMinus>", by(1 / STEP), {
  desc = "Zoom out",
})

vim.keymap.set(MODES, "<C-0>", function()
  vim.g.neovide_scale_factor = 1.0
end, {
  desc = "Zoom back to 100%",
})
