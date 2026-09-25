-- TypeScript: tsgo, Microsoft's Go port of the compiler, which serves LSP
-- from the same binary as `tsc --lsp`.

return {
  servers = {
    tsgo = {
      cmd = { "tsc", "--lsp", "--stdio" },

      config = {
        -- tsgo both pushes diagnostics and offers them on pull. Neovim pulls
        -- from any server that offers it and keeps the two in namespaces of
        -- their own, so every error would show twice.
        init_options = { disablePushDiagnostics = true },

        -- Its code lenses return nothing until one is named. References, and
        -- not the two `showOn*` switches beside it: resolving one runs a
        -- find-references, and one per function is a lot of them for a
        -- number I rarely read.
        settings = {
          typescript = {
            referencesCodeLens = { enabled = true },
          },
        },
      },
    },
  },
}
