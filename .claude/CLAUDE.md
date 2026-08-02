# mivn

<!--toc:start-->
- [mivn](#mivn)
  - [Philosophy](#philosophy)
  - [Conventions](#conventions)
  - [Verify before calling anything done](#verify-before-calling-anything-done)
  - [Agents](#agents)
<!--toc:end-->

A personal Neovim config. The repo root is the config directory, cloned to
`~/.config/nvim` (or run isolated: symlink the repo to `~/.config/mivn` and
set `NVIM_APPNAME=mivn`, which is how this working copy is tested without
touching the real config). Launching, the Neovide-vs-terminal choice, and
direnv are up to the executing environment and not this repo.

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
- Comments are first person ("as I type"), plain common English, hard-wrapped
  at 80 columns, no em dashes. User-visible strings (`desc = ...`,
  `vim.notify`) address the user instead.
- Every highlight group lives in `colors/basalt.lua`, the plugins' and
  mivn's own included, written through that file's palette names (`c.blue`,
  never a hex). Modules under `lua/mivn/` define none, name no color, and carry
  no `ColorScheme` autocmd.
- Lua is formatted by stylua, two-space indent.

## Verify before calling anything done

- `stylua --check init.lua lua/mivn/*.lua colors/*.lua`
- `timeout 60 env NVIM_APPNAME=mivn nvim --headless "+lua io.write('ok\n')" +qa`
  must print `ok` with no errors (needs the `~/.config/mivn` symlink above).
  Headless boot does not exercise UI paths; drive them with `:normal` or
  feedkeys when a change touches one.

## Agents

- `ux-advisor`: consult for interaction and ergonomics decisions.
- `ui-advisor`: consult before visual, layout, or color decisions.
- `implementer`: writes Lua/bash to spec.
