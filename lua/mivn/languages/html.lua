-- HTML: the VS Code server for the language, superhtml for the opinions.

return {
  servers = {
    html = {
      -- The plain command and no probe, for the reasons json.lua gives.
      cmd = { "vscode-html-language-server", "--stdio" },

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
