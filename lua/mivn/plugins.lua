-- My plugins, managed by vim.pack. Each is pinned to a commit right here, with
-- the nearest release tag and the commit date in its comment, so this file says
-- what should be installed and nvim-pack-lock.json is a cache of it.
-- .github/scripts/repin moves the pins. What is on disk can lag behind them,
-- which `:checkhealth mivn` reports.
vim.pack.add({
  -- The basics: syntax, language servers, the file tree.

  -- grammars (v0.9.3+854, 2026-09-07)
  { src = "https://github.com/nvim-treesitter/nvim-treesitter", version = "32dbd2e8fd6079ae4d69e7ed621320369b75b563" },
  -- per-server configs, not a client (v2.11.0, 2026-07-21)
  { src = "https://github.com/neovim/nvim-lspconfig", version = "b89138d9af0a96e6048e202a15765fc6b6416bd4" },
  -- the file tree (v1.18.0, 2026-07-01)
  { src = "https://github.com/nvim-tree/nvim-tree.lua", version = "531b807b8f0d6f75016a0ee1e0cd5ce2086e9d95" },
  -- what can follow the key I just pressed (v3.17.0, 2025-02-22)
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
  -- auto-closing pairs, and the table the wrapping keys read (v0.18.0, 2026-06-19)
  { src = "https://github.com/echasnovski/mini.pairs", version = "4a014143fcb4e9df26198ccb3ecff3b9e77a048c" },
})

-- vim.pack.update with GIT_CONFIG_GLOBAL=/dev/null, which keeps git off ssh;
-- git() in lua/mivn/update.lua says why.
--
-- NOTE: when the call opens a review, the variable goes back only once the
-- review goes: these are blobless clones, so the checkout its :write starts
-- still fetches. Until then it is the whole editor's, a :terminal included.
local pack_update = vim.pack.update

--- The review buffers vim.pack.update has open, as a set.
local function reviews()
  local found = {}

  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_get_name(buf):find("nvim-pack://confirm", 1, true) then
      found[buf] = true
    end
  end

  return found
end

---@diagnostic disable-next-line: duplicate-set-field it is the point
vim.pack.update = function(...)
  local saved = vim.env.GIT_CONFIG_GLOBAL
  vim.env.GIT_CONFIG_GLOBAL = "/dev/null"

  local function restore()
    vim.env.GIT_CONFIG_GLOBAL = saved
  end

  local before = reviews()
  local ok, err = pcall(pack_update, ...)

  -- this call's own review, not one an earlier update left open
  local review
  for buf in pairs(reviews()) do
    if not before[buf] then
      review = buf
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
