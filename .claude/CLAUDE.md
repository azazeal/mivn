# mivn

A personal Neovim config. The repo root is the config directory, cloned to
`~/.config/nvim` (or run isolated: symlink the repo to `~/.config/mivn` and
set `NVIM_APPNAME=mivn`, which is how this working copy is tested without
touching the real config). Launching and the Neovide-vs-terminal choice are
up to the executing environment and not this repo.

The environment is this repo's business, though, and that is a deliberate
reversal. Two launch paths matter: `nvim` in a terminal already inside the
directory, where mise's shell hook has run, and Neovide from a launcher,
where no shell ever ran. lua/mivn/env.lua asks mise directly so both come
out the same, and the terminal path pays 6ms for an answer it already had.
Tools come from mise too, all of them: nothing here installs a language
server, and a server missing from mise's config is a language with
tree-sitter colours and nothing else.

## Philosophy

- Defaults first. Vim's grammar stays as it ships; every addition or deviation
  is a recorded trade. DEFAULTS.md is the tour of that surface and marks
  deviations with `_(mivn)_`; update it whenever behavior changes.
- This is a tool, not a project. New friction becomes a TODO.md entry and is
  fixed in monthly batches; do not add plugins, options, or mappings beyond
  what a task strictly needs.
- Plugins: prefer the mini.* family and zero-dependency plugins. Every plugin
  is pinned to a commit in `plugins.lua` itself, with a one-line comment above
  each entry (purpose, then the pin in parentheses); `nvim-pack-lock.json` is
  a cache of the same pins. `.github/scripts/repin` maintains both the pins
  and the parentheses; edit the purpose text freely, keep the shape.

## Conventions

- One module per concern under `lua/mivn/`; the header comment carries the
  module's purpose and its trade-offs.
- Every mapping that is on for the whole session lives in
  `lua/mivn/keymaps.lua`, whatever module owns the behavior: that module
  exports a function and this file picks the key. A mapping that exists only
  while some buffer does (made inside an autocmd, `buffer = ...`) stays with
  the module it belongs to. New keys go in that file, not beside the code
  they call.
- Comments are first person ("as I type"), plain common English, hard-wrapped
  at 80 columns, no em dashes. User-visible strings (`desc = ...`,
  `vim.notify`) address the user instead.
- Every highlight group lives in `colors/basalt.lua`, the plugins' and
  mivn's own included, written through that file's palette names (`c.blue`,
  never a hex). Modules under `lua/mivn/` define none, name no color, and carry
  no `ColorScheme` autocmd.
- Lua is formatted by stylua, two-space indent.

## Verify before calling anything done

- `stylua --check .` (covers init.lua, lua/ recursively, and colors/)
- `timeout 60 env NVIM_APPNAME=mivn nvim --headless "+lua io.write('ok\n')" +qa`
  must print `ok` with no errors (needs the `~/.config/mivn` symlink above).
  Headless boot does not exercise UI paths; drive them with `:normal` or
  feedkeys when a change touches one.

## Releasing

- Work happens on a branch and lands on `main` through a pull request; `main`
  takes no direct pushes, and I run the merge myself.
- A release is `.github/scripts/release vX.Y.Z`, never the git and gh commands
  by hand: it is the only thing standing between a slipped `git tag -a` and an
  unsigned tag, which nothing on GitHub's side rejects. Its header comment
  says why.
- Releases are immutable and tags cannot be moved, so a bad release is
  followed by the next patch version, not repaired. Only the notes can still
  be edited.

## Agents

- `ux-advisor`: consult for interaction and ergonomics decisions.
- `ui-advisor`: consult before visual, layout, or color decisions.
- `implementer`: writes Lua/bash to spec.
