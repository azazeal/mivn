-- My plugins, managed by vim.pack (built into Neovim 0.12, no bootstrap
-- needed). Versions are pinned in nvim-pack-lock.json, which is committed, so
-- a fresh clone installs exactly these revisions; `:lua vim.pack.update()`
-- moves them forward and rewrites the lock. Details and trade-offs live with
-- each plugin's setup in lua/mivn/.
vim.pack.add({
  -- The basics: syntax, language servers, the file tree.
  { src = "https://github.com/nvim-treesitter/nvim-treesitter", version = "main" }, -- grammars
  { src = "https://github.com/neovim/nvim-lspconfig" }, -- per-server configs, not a client
  { src = "https://github.com/b0o/SchemaStore.nvim" }, -- schemas for JSON and YAML validation
  { src = "https://github.com/nvim-tree/nvim-tree.lua" }, -- the file tree
  { src = "https://github.com/folke/which-key.nvim" }, -- what can follow the key I just pressed

  -- The mini family: single-purpose plugins with no dependencies of their own
  -- that know about each other (the tab bar, the tree and the pickers all draw
  -- mini.icons).
  { src = "https://github.com/echasnovski/mini.pick" }, -- fuzzy finding
  { src = "https://github.com/echasnovski/mini.extra" }, -- more pickers: palette, diagnostics
  { src = "https://github.com/echasnovski/mini.icons" }, -- icons; stands in for nvim-web-devicons
  { src = "https://github.com/echasnovski/mini.tabline" }, -- the buffer tab bar
  { src = "https://github.com/echasnovski/mini.statusline" }, -- the status line
  { src = "https://github.com/echasnovski/mini.diff" }, -- git changes in the gutter
  { src = "https://github.com/echasnovski/mini.pairs" }, -- auto-closing pairs, on trial
})
