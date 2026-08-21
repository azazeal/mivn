-- Shows what can follow a key I have started typing.
--
-- Configured for learning, not just for the leader menu. `triggers` is left on
-- its default of every prefix, so `d` lists the motions and text objects that
-- complete it, `g` the g-commands, `"` the registers. The delay is short for
-- the same reason.

local wk = require("which-key")

wk.setup({
  preset = "modern",
  delay = 250,

  -- Do not warn about keys with no description; most of what shows up here is
  -- Vim's own grammar, which has never had one.
  notify = false,

  icons = {
    mappings = true,
    -- Only the leader is spelled out: "<Space>" reads better than a glyph.
    keys = { Space = "<Space> " },
  },

  win = {
    border = "rounded",
    padding = { 1, 2 },
  },

  -- Group first, then Vim's own ordering, then alphabetical. Puts the
  -- multi-key prefixes at the top of a panel rather than scattered through it.
  sort = { "group", "local", "order", "alphanum", "mod" },

  -- The descriptions themselves live on the mappings (`desc = ...` at each
  -- vim.keymap.set site) and which-key reads them from there; an entry here
  -- exists only for what a mapping cannot carry. Icons first: which-key
  -- guesses one from keywords in the description, and these three are the
  -- ones it gets wrong. No desc on them on purpose, so the mapping's own
  -- text stays the single copy.
  spec = {
    { "<leader>:", icon = { icon = "󰘳", color = "purple" } },
    { "<leader>h", icon = { icon = "󰋖", color = "cyan" } },
    { "<leader>t", group = "toggle" },
    { "<leader>tt", icon = { icon = "󰙅", color = "blue" } },

    -- Names for the prefixes Vim ships, so the panel explains itself instead
    -- of listing bare letters.
    { "g", group = "goto / misc" },
    { "z", group = "folds, scroll, spelling" },
    { "]", group = "next ..." },
    { "[", group = "previous ..." },
    { '"', group = "registers" },
    { "'", group = "marks (line)" },
    { "`", group = "marks (exact)" },
    { "gr", group = "language server" },
  },
})
