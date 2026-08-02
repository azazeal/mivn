-- Personal settings the config reads when they exist, kept out of version
-- control. To use: copy this file to local.lua in the same directory
-- (local.lua is gitignored) and fill in what you want. Every key is optional,
-- and the config works the same with no file at all.
--
-- These are the personal, machine-side knobs. A project that wants to carry
-- its own editor config does it the standard way instead: 'exrc' is on, so a
-- trusted .nvim.lua in the project (or any directory above it) runs after
-- this config and can tweak Neovim directly; vim.lsp.config() calls there
-- merge over the defaults lua/mivn/lsp.lua ships.
return {
  -- Import prefixes that count as "ours" when formatting Go, keyed by the
  -- directory they apply under (longest match wins; "~" works). Each prefix
  -- earns a gci block of its own, in list order, plus gopls' `local`
  -- treatment. An empty table (or no key at all) means no extra blocks
  -- anywhere. For example:
  --
  --   go_import_prefixes = {
  --     ["~/projects/my-org"] = { "github.com/my-org/" },
  --     ["~/work"] = { "github.com/employer/", "go.employer.dev/" },
  --   },
  go_import_prefixes = {},

  -- Changes to the language-server table in lua/mivn/lsp.lua, nvim-lspconfig
  -- name to the binary that proves it is installed. A new pair adds a server,
  -- a different binary re-points one, and `false` drops one entirely.
  -- :MivnServers shows the merged result. For example:
  --
  --   lsp_servers = {
  --     basedpyright = "basedpyright",
  --     sqls = false,
  --   },
  lsp_servers = {},

  -- Per-server settings, deep-merged over the defaults lua/mivn/lsp.lua
  -- ships, so a key here wins and everything else keeps its default. The
  -- nesting mirrors the server's own settings sections. Most useful inside
  -- `projects` below, where one client's checkouts can want different
  -- settings. For example:
  --
  --   lsp_settings = {
  --     gopls = { gopls = { buildFlags = { "-tags=integration" } } },
  --   },
  lsp_settings = {},

  -- How :checkhealth mivn asks a server binary for its version, keyed by
  -- binary name (not server name): the extra arguments as a list, or false
  -- for a binary with no harmless one-shot flag, which is then only looked
  -- up and never run. Merges over the built-in table, which already covers
  -- the servers the config ships; this mostly matters for servers added
  -- through `lsp_servers` above. For example:
  --
  --   lsp_probes = {
  --     ["my-language-server"] = { "-v" },
  --     ["starts-serving-when-run"] = false,
  --   },
  lsp_probes = {},

  -- Changes to the tree-sitter grammar list in lua/mivn/treesitter.lua:
  -- grammar name to true (add) or false (drop). Takes effect on the next
  -- :MivnInstallGrammars run. For example:
  --
  --   treesitter_grammars = {
  --     ocaml = true,
  --     zig = false,
  --   },
  treesitter_grammars = {},

  -- Everything above is global. `projects` scopes any of the same keys to a
  -- directory: when Neovim starts inside one, that directory's values merge
  -- over the globals, and the longest matching directory wins. One client's
  -- checkouts can run a different Elixir server, for example:
  --
  --   projects = {
  --     ["~/work/client-a"] = {
  --       lsp_servers = { expert = false, elixirls = "elixir-ls" },
  --     },
  --   },
  projects = {},
}
