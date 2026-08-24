-- My plugins, managed by vim.pack (built into Neovim 0.12, no bootstrap
-- needed). Every plugin is pinned to a commit right here, with the nearest
-- tag and the commit date beside it, so this file says exactly what is
-- installed; nvim-pack-lock.json is a cache of the same and never disagrees.
--
-- Moving a pin forward is .github/scripts/repin's job. The weekly workflow
-- runs `repin pick 14`, which takes every plugin to the newest release that
-- has been out for two weeks, and opens a PR with the result. By hand it is
-- `repin strip`, then `:lua vim.pack.update()`, then `repin write`, which
-- shows me the changelogs and waits for nothing. Details and trade-offs live
-- with each plugin's setup in lua/mivn/.
vim.pack.add({
  -- The basics: syntax, language servers, the file tree.

  -- grammars (v0.9.3+843, 2026-08-08)
  { src = "https://github.com/nvim-treesitter/nvim-treesitter", version = "c9f9ed6c1892f629ea399f4ee7905f2686fa13f2" },
  -- per-server configs, not a client (v2.11.0, 2026-07-21)
  { src = "https://github.com/neovim/nvim-lspconfig", version = "b89138d9af0a96e6048e202a15765fc6b6416bd4" },
  -- the file tree (v1, 2026-07-01)
  { src = "https://github.com/nvim-tree/nvim-tree.lua", version = "531b807b8f0d6f75016a0ee1e0cd5ce2086e9d95" },
  -- what can follow the key I just pressed (stable, 2025-02-22)
  { src = "https://github.com/folke/which-key.nvim", version = "fcbf4eea17cb299c02557d576f0d568878e354a4" },

  -- The mini family: single-purpose plugins with no dependencies of their own
  -- that know about each other (the tab bar, the tree and the pickers all draw
  -- mini.icons).

  -- fuzzy finding (v0.18.0, 2026-06-19)
  { src = "https://github.com/echasnovski/mini.pick", version = "8c1f75f8ddd8c9f75d07ed2ab5718d2c3cb65a66" },
  -- more pickers: palette, diagnostics (v0.18.0, 2026-06-19)
  { src = "https://github.com/echasnovski/mini.extra", version = "e5ecf197f8954d002cb9e85b3715851e2c8d3cd5" },
  -- icons; stands in for nvim-web-devicons (v0.18.0, 2026-06-19)
  { src = "https://github.com/echasnovski/mini.icons", version = "e56797f90192d81f1fda02e662fc3e8e3d775027" },
  -- the buffer tab bar (v0.18.0, 2026-06-19)
  { src = "https://github.com/echasnovski/mini.tabline", version = "7e8584a06b86902c64227e4abd0c39ae74061101" },
  -- the status line (v0.18.0, 2026-06-19)
  { src = "https://github.com/echasnovski/mini.statusline", version = "b5547f44560dae3ccd81f914256fa6f705837022" },
  -- git changes in the gutter (v0.18.0, 2026-06-19)
  { src = "https://github.com/echasnovski/mini.diff", version = "0743d26bd858ebe32efcf5c86a91a422a000f273" },
  -- auto-closing pairs, on trial (v0.18.0, 2026-06-19)
  { src = "https://github.com/echasnovski/mini.pairs", version = "4a014143fcb4e9df26198ccb3ecff3b9e77a048c" },
})

-- vim.pack.update, with SSH kept out of it. A global gitconfig can rewrite
-- https URLs to ssh (url.<base>.insteadOf), and then the plugins above,
-- https as their URLs read, fetch over SSH, and on a machine whose agent
-- holds no key the update hangs on a passphrase prompt nothing draws.
-- GIT_CONFIG_GLOBAL=/dev/null drops the rewrite for the update's git
-- subprocesses alone: set before the call, restored once the work is done.
-- "Done" is after the call for a forced update, but at the review buffer's
-- deletion otherwise: these are blobless clones, so the checkout that the
-- buffer's :write starts still fetches blobs, and quitting the buffer is
-- the cancel. Not process-wide, ever: :terminal must keep the user's real
-- git config. TODO.md's dashboard entry records the fuller story.
local pack_update = vim.pack.update

---@diagnostic disable-next-line: duplicate-set-field it is the point
vim.pack.update = function(...)
  local saved = vim.env.GIT_CONFIG_GLOBAL
  vim.env.GIT_CONFIG_GLOBAL = "/dev/null"

  local function restore()
    vim.env.GIT_CONFIG_GLOBAL = saved
  end

  local ok, err = pcall(pack_update, ...)

  local review
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_get_name(buf):find("nvim-pack://confirm", 1, true) then
      review = buf
      break
    end
  end

  if review then
    vim.api.nvim_create_autocmd("BufWipeout", {
      buffer = review,
      once = true,
      desc = "Put the git config back after the plugin update settles",
      callback = restore,
    })
  else
    restore()
  end

  if not ok then
    error(err, 0)
  end
end
