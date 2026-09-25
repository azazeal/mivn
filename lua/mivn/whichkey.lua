-- Shows what can follow a key I have started typing, after any prefix and not
-- only the leader (`triggers` stays at its default), so `d` lists what can
-- complete it and `"` the registers.

local wk = require("which-key")

wk.setup({
  preset = "modern",
  delay = 250,

  -- Vim's own keys have no description, so a missing one is not worth a
  -- warning.
  notify = false,

  -- No panel on entering a mode, only on a prefix pressed in it. The default
  -- defers only `V` and Ctrl+V, so `v` and every shifted arrow would open a
  -- panel over the selection just made; `g` or `[` inside one still opens it.
  defer = function()
    return true
  end,

  icons = {
    mappings = true,
    -- Only the leader is spelled out: "<Space>" reads better than a glyph.
    keys = { Space = "<Space> " },
  },

  win = {
    border = "rounded",
    padding = { 1, 2 },
  },

  -- Groups first, so the prefixes with more keys behind them top the panel.
  sort = { "group", "local", "order", "alphanum", "mod" },

  -- Only what a mapping cannot carry; the descriptions stay on the mappings.
  -- The icons are the ones which-key guesses wrong from the description.
  spec = {
    { "<leader>:", icon = { icon = "󰘳", color = "purple" } },
    { "<leader>h", icon = { icon = "󰋖", color = "cyan" } },
    { "<leader>a", group = "code" },
    { "<leader>g", group = "goto" },
    { "<leader>t", group = "toggle" },
    { "<leader>tt", icon = { icon = "󰙅", color = "blue" } },

    -- Names for the prefixes Vim ships.
    { "g", group = "goto / misc" },
    { "z", group = "folds, scroll, spelling" },
    { "]", group = "next ..." },
    { "[", group = "previous ..." },
    { '"', group = "registers" },
    { "'", group = "marks (line)" },
    { "`", group = "marks (exact)" },
  },
})
