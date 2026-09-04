-- YAML, and the workflow files that are YAML with a schema over them.
--
-- yaml-language-server formats through prettier, and prettier drops the blank
-- line that sits under a key, above its first entry. So formatting is taken
-- off it and yamlfmt does the job instead; a missing yamlfmt then shows as a
-- file that does not change, which is what it should look like, rather than
-- as a whole file quietly reflowed behind yamlfmt's back.
--
-- The `yaml.format.enable` setting does not do this: in VS Code the extension
-- around the server acts on it, and the bare server keeps on formatting.

return {
  servers = {
    yamlls = {
      -- The plain command, for the reason lua/mivn/languages/json.lua gives:
      -- nvim-lspconfig would otherwise reach into the project's
      -- node_modules.
      cmd = { "yaml-language-server", "--stdio" },

      -- The header says why.
      format = false,
    },

    -- GitHub's own server for workflow files, which nvim-lspconfig roots at a
    -- `.github/workflows` directory and attaches nowhere else. It knows the
    -- inputs of the actions a workflow uses, which is the half a schema
    -- cannot cover.
    gh_actions_ls = {
      -- nvim-lspconfig expects lttb's wrapper; this is GitHub's own package,
      -- which the release carries under a name of its own.
      cmd = { "actions-languageserver", "--stdio" },

      -- Looking an action's inputs up is an API call, and no token is
      -- handed over, so it runs rate limited rather than authenticated.
      probe = false,
    },

    -- The workflow linter, in its language-server mode. It reads and says
    -- what it found; nothing it reports needs the network, and its online
    -- audits are off unless a token is handed over.
    zizmor = { binary = "zizmor" },
  },

  formatters = {
    yaml = {
      "yamlfmt",
      "-formatter",
      -- retain_line_breaks_single keeps a single blank line, which is what
      -- prettier does; the default strips them all. yamlfmt keeps one by
      -- writing a `#magic___^_^___line` comment in its place and taking that
      -- line out again at the end, and a blank line under a folded (`>`)
      -- block gets folded into the block, so the marker ends up inside the
      -- value and nothing takes it out again. scan_folded_as_literal stops
      -- the folding, so the marker stays a line of its own; it also leaves a
      -- `>` block with the line breaks I wrote it with, instead of joining
      -- them into one line. google/yamlfmt#86 is the open bug. The one case
      -- it does not save is a block scalar with a trailing space on a line,
      -- which comes back as a quoted string with the marker inside it.
      "retain_line_breaks_single=true,scan_folded_as_literal=true",
      "-in",
    },
  },
}
