-- My plugins, managed by vim.pack (built into Neovim 0.12, no bootstrap
-- needed). Every plugin is pinned to a commit right here, with the nearest
-- tag and the commit date beside it, so this file says exactly what is
-- installed; nvim-pack-lock.json is a cache of the same and never disagrees.
--
-- Moving a pin forward is .github/scripts/repin's job: `repin strip`, then
-- `:lua vim.pack.update()`, then `repin write`. The weekly workflow does
-- that and opens a PR with the result. Details and trade-offs live with each
-- plugin's setup in lua/mivn/.
vim.pack.add({
  -- The basics: syntax, language servers, the file tree.

  -- grammars (v0.9.3+840, 2026-08-01)
  { src = "https://github.com/nvim-treesitter/nvim-treesitter", version = "7b6cc8949f9999c5ed91436cbe24aa5f99c42025" },
  -- per-server configs, not a client (v2.11.0+17, 2026-08-01)
  { src = "https://github.com/neovim/nvim-lspconfig", version = "1c0d8f70dbc8827263eedc3cf7021ceba0f68689" },
  -- the file tree (v1+5, 2026-07-16)
  { src = "https://github.com/nvim-tree/nvim-tree.lua", version = "4213bd6eabac38b16dd6615002b6243b23cf3bf6" },
  -- what can follow the key I just pressed (stable+8, 2025-10-28)
  { src = "https://github.com/folke/which-key.nvim", version = "3aab2147e74890957785941f0c1ad87d0a44c15a" },

  -- The mini family: single-purpose plugins with no dependencies of their own
  -- that know about each other (the tab bar, the tree and the pickers all draw
  -- mini.icons).

  -- fuzzy finding (v0.18.0+1, 2026-07-07)
  { src = "https://github.com/echasnovski/mini.pick", version = "04e73ab07222508361095bb6e27621b315e6b9f1" },
  -- more pickers: palette, diagnostics (v0.18.0+1, 2026-07-07)
  { src = "https://github.com/echasnovski/mini.extra", version = "9c6affac2b176142f48b185bd7abc5db7ec20ac8" },
  -- icons; stands in for nvim-web-devicons (v0.18.0+2, 2026-07-07)
  { src = "https://github.com/echasnovski/mini.icons", version = "98faae31e9be1cc054ae63485e58ceb185efcad0" },
  -- the buffer tab bar (v0.18.0+1, 2026-07-07)
  { src = "https://github.com/echasnovski/mini.tabline", version = "525b27e98de7cd2a6012d99f45b4fc10676e00e5" },
  -- the status line (v0.18.0+2, 2026-07-07)
  { src = "https://github.com/echasnovski/mini.statusline", version = "127997ebef7ef632161203b960c5ef9d158f4810" },
  -- git changes in the gutter (v0.18.0+4, 2026-07-30)
  { src = "https://github.com/echasnovski/mini.diff", version = "626b8a5b93874c4d05ca25aedec56cfff0b378fb" },
  -- auto-closing pairs, on trial (v0.18.0+4, 2026-07-23)
  { src = "https://github.com/echasnovski/mini.pairs", version = "b1c5a726921b7a8c9321e9a7a208aa0571de5810" },
})
