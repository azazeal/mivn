-- CSS: the VS Code server, for .css, .scss and .less. It comes in the same
-- npm package as the html and json servers.
--
-- The plain command and no probe, for the reasons json.lua gives.
--
-- .sass, the indented syntax, gets regex highlighting and nothing more:
-- neither this server nor tree-sitter has anything for it.

return {
  servers = {
    cssls = {
      cmd = { "vscode-css-language-server", "--stdio" },
      probe = false,
    },
  },
}
