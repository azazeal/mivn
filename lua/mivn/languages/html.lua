-- HTML: the VS Code server for the language, superhtml for the opinions.

return {
  servers = {
    html = {
      -- The plain command, for the reason lua/mivn/languages/json.lua gives:
      -- nvim-lspconfig would otherwise reach into the project's node_modules.
      cmd = { "vscode-html-language-server", "--stdio" },

      -- No harmless one-shot flag, for the reason json.lua gives too.
      probe = false,
    },

    superhtml = {
      binary = "superhtml",

      -- Not --version: it prints "unrecognized subcommand" for that and still
      -- exits 0, which would read as its version line.
      probe = { "version" },
    },
  },
}
