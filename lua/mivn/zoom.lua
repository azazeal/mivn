-- Zooming Neovide in, out and back to 100%. A terminal zooms on these keys
-- itself, and only Neovide reads g:neovide_scale_factor.
--
-- Nothing here sets 'guifont': the size comes from Neovide's config.toml, and
-- a 'guifont' set here would win over that whole file without warning. So the
-- reset writes 1.0 rather than a size.

-- One press is foot's step, near enough: 0.5pt on a 12pt font, a 24th.
local STEP = 1 + 0.5 / 12

-- Under half the text is too small to read, and over triple the window holds
-- too little to be of use.
local MIN, MAX = 0.5, 3.0

local function by(step)
  return function()
    local factor = (vim.g.neovide_scale_factor or 1.0) * step

    vim.g.neovide_scale_factor = math.min(math.max(factor, MIN), MAX)
  end
end

local function reset()
  vim.g.neovide_scale_factor = 1.0
end

return {
  into = by(STEP),
  out = by(1 / STEP),
  reset = reset,
}
