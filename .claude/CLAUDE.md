# mivn

My personal Neovim configuration, the whole of `~/.config/nvim`. It holds my
keymaps, the few plugins I have opted into, and everything said to the
language servers and tools around them.

The tools themselves come from `$PATH` as the session was handed it, and
nothing here resolves a toolchain or asks a version manager anything. So a
server that is not on `PATH` is a language with tree-sitter colors and nothing
else, and a project's import prefixes arrive as `$GOIMPORTPREFIXES` rather
than through a config key.

To exercise this working copy without touching my real config, `~/.config/mivn`
points at this repo and `NVIM_APPNAME=mivn` runs it.

## Philosophy

- Defaults first. Vim's grammar stays as it ships, and every deviation is a
  recorded trade: DEFAULTS.md is the tour of that surface, marks deviations
  with `_(mivn)_`, and is updated whenever behavior changes.
- My hands come from CUA editors and are not changing. Where that pulls
  against Vim's grammar the tension is deliberate, so the answer is to record
  the trade rather than pick a side.
- A tool, not a project. New friction becomes a TODO.md line and is fixed in
  batches. Do not add plugins, options or mappings beyond what a task needs.
- Plugins: the mini.* family and zero-dependency ones, and only for what
  Neovim still does not bundle.

## Conventions

- One module per concern under `lua/mivn/`; the header comment carries the
  module's purpose and its trade-offs.
- `lua/mivn/languages/` is data, not concerns: one file per language, holding
  its servers, their settings, what confines them, and how it is formatted.
  Nothing else goes in there. `lua/mivn/lsp.lua` is what loads them.
- Every mapping that is on for the whole session lives in
  `lua/mivn/keymaps.lua`, whatever module owns the behavior: that module
  exports a function and this file picks the key. A mapping that exists only
  while some buffer does (made inside an autocmd, `buffer = ...`) stays with
  its module.
- Every highlight group lives in `colors/basalt.lua`, the plugins' and mivn's
  own included, written through that file's palette names. Never a hex, and
  never a highlight group or a `ColorScheme` autocmd under `lua/mivn/`.
- Comments are first person ("as I type"), plain common English, hard-wrapped
  at 80 columns, no em dashes. User-visible strings (`desc = ...`,
  `vim.notify`) address the user instead.
- Plugins are pinned to a commit in `plugins.lua` itself, with a one-line
  comment above each entry: purpose, then the pin in parentheses.
  `.github/scripts/repin` maintains the pins and `nvim-pack-lock.json`; edit
  the purpose text freely, keep the shape.
- Lua is formatted by stylua.

## Verify before calling anything done

- `stylua --check .`
- `timeout 60 env NVIM_APPNAME=mivn nvim --headless "+lua io.write('ok\n')" +qa`
  must print `ok` and nothing else.
- Headless boot does not exercise UI paths, so a clean boot is not a passing
  test for one. When a change touches a UI path, drive it with `:normal` or
  feedkeys and read back what actually happened.
- A new key, command or save-time behavior has to be tried on the buffers
  that have no file behind them, not only on a file. `.github/scripts/panels
  --key '<Space>x'`, `--cmd 'MivnThing'` or `--write` runs it against the
  banner, the tree and the terminal, with a real file as the control, and
  exits non-zero on the ones it raises in. Two keys have shipped broken on
  the banner already.
- When a bug gets through, say what would have caught it and offer to add
  that, whether or not it is about the panels. The panels script exists
  because two bugs of one shape got through; the next shape will need its
  own check, and the useful moment to notice is while the bug is fresh.

## Releasing

- Work happens on a branch and lands on `main` through a pull request; `main`
  takes no direct pushes, and I run the merge myself.
- A release is `.github/scripts/release patch|minor|major`, never the git and
  gh commands by hand: `git tag -a` writes an unsigned tag, and nothing on
  GitHub's side rejects it. Tags never move either, so a bad release is
  followed by the next patch version rather than repaired; only the notes can
  still be edited.

## Agents

- `ux-advisor`: consult for interaction and ergonomics decisions.
- `ui-advisor`: consult before visual, layout, or color decisions.
- `implementer`: writes Lua and bash to spec.
