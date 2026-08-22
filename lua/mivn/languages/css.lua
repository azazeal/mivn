-- CSS: the VS Code server, which is the one Zed and VS Code itself run.
--
-- It covers .css, .scss and .less, all three from the one binary, and it
-- arrives with the html and json servers in the same npm package that
-- lua/mivn/languages/html.lua and json.lua already draw from.
--
-- The plain command, for the reason json.lua gives: nvim-lspconfig ships a
-- `cmd` function that prefers the project's own node_modules. No probe, for
-- the reason it gives too.
--
-- .sass, the indented syntax, is not covered and cannot be here: this server
-- does not speak it, and tree-sitter has no grammar for it either, so those
-- files get regex highlighting and nothing more.

return {
  servers = {
    cssls = {
      cmd = { "vscode-css-language-server", "--stdio" },
      probe = false,
    },
  },
}
