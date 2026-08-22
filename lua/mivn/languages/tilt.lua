-- Tilt: the language server that ships inside the `tilt` binary itself, so
-- there is nothing to install beside it.
--
-- A Tiltfile is Starlark, and the grammar registered for it in
-- lua/mivn/treesitter.lua is starlark's. Neovim detects the filetype on its
-- own, both for `Tiltfile` and for `*.tiltfile`; nvim-lspconfig's note about
-- adding detection by hand is older than that.

return {
  servers = {
    tilt_ls = {
      binary = "tilt",

      -- `lsp start` is the server; `version` is the one thing the binary
      -- answers and exits.
      probe = { "version" },
    },
  },
}
