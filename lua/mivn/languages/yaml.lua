-- YAML, and the workflow files that are YAML with a schema over them.
--
-- yaml-language-server formats through prettier, which drops the blank line
-- under a key, above its first entry, so yamlfmt formats instead. A missing
-- yamlfmt then shows as a file that does not change, rather than one quietly
-- reflowed by the server.

return {
  servers = {
    yamlls = {
      -- The plain command, for the reason json.lua gives.
      cmd = { "yaml-language-server", "--stdio" },

      -- NOTE: The `yaml.format.enable` setting cannot replace this. In VS Code
      -- the extension around the server acts on it, and the bare server keeps
      -- on formatting.
      format = false,
    },

    -- GitHub's own server for workflow files, which nvim-lspconfig attaches
    -- only under a `.github/workflows` directory. It knows the inputs of the
    -- actions a workflow uses, which a schema cannot cover. Looking them up
    -- is an API call, and no token is handed over, so it runs rate limited.
    gh_actions_ls = {
      -- nvim-lspconfig expects lttb's wrapper; GitHub's own package ships the
      -- server under this name.
      cmd = { "actions-languageserver", "--stdio" },

      -- No probe, for the reason json.lua gives: the same runtime is under it.
      probe = false,
    },

    -- The workflow linter, in its language-server mode. Its online audits are
    -- off unless a token is handed over, so it never reaches the network.
    zizmor = { binary = "zizmor" },
  },

  formatters = {
    yaml = {
      "yamlfmt",
      "-formatter",
      -- retain_line_breaks_single keeps one blank line where the default
      -- strips them all.
      --
      -- NOTE: It needs scan_folded_as_literal beside it. yamlfmt keeps a
      -- blank line as a `#magic___^_^___line` comment that it takes out at
      -- the end, and a blank line under a folded (`>`) block gets folded into
      -- the value, marker and all. scan_folded_as_literal stops that, and
      -- keeps a `>` block's line breaks as I wrote them. A block scalar with
      -- a trailing space on a line still comes back quoted with the marker
      -- inside (google/yamlfmt#86).
      "retain_line_breaks_single=true,scan_folded_as_literal=true",
      "-in",
    },
  },
}
