-- TypeScript and JavaScript: the TypeScript 7 compiler, whose language server
-- is a flag on the compiler itself.

return {
  servers = {
    tsgo = {
      -- The release carries the binary under the compiler's own name, `tsc`,
      -- while nvim-lspconfig looks for `tsgo`.
      --
      -- Spelled out here for a second reason: nvim-lspconfig ships a `cmd`
      -- **function** that prefers `<root>/node_modules/.bin/<server>`
      -- whenever the project has one, so opening a repository would run the
      -- language server that repository shipped.
      cmd = { "tsc", "--lsp", "--stdio" },
    },
  },
}
