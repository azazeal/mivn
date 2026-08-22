-- TypeScript: tsgo, Microsoft's Go port of the compiler, which serves LSP
-- from the same binary as `tsc --lsp`.
--
-- Two things it needs telling, both because its defaults suit a client that
-- is not this one.
--
-- It answers diagnostics both ways at once: it advertises a diagnostic
-- provider unconditionally and pushes as well. Neovim turns pull on for any
-- server that offers it and keeps the two in namespaces of their own, so
-- every error arrived twice, once per namespace. Turning the push half off
-- leaves the pull half, which is the one Neovim asked for.
--
-- Its code lenses return nothing at all until one of them is named, so the
-- lenses this config enables for every buffer were an empty promise here.
-- References, and not the two `showOn*` switches beside it: resolving one
-- runs a find-references, and one per function is a lot of them for a number
-- I rarely read.

return {
  servers = {
    tsgo = {
      cmd = { "tsc", "--lsp", "--stdio" },

      config = {
        init_options = { disablePushDiagnostics = true },

        settings = {
          typescript = {
            referencesCodeLens = { enabled = true },
          },
        },
      },
    },
  },
}
