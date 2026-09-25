-- Tilt: the language server inside the `tilt` binary itself.
--
-- A Tiltfile is Starlark, and lua/mivn/treesitter.lua gives it starlark's
-- grammar. Neovim detects `Tiltfile` and `*.tiltfile` on its own, whatever
-- nvim-lspconfig's note about adding the filetype by hand says.

return {
  servers = {
    tilt_ls = {
      binary = "tilt",

      -- `lsp start` is the server; `version` is what answers and exits.
      probe = { "version" },
    },
  },
}
