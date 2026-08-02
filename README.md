# mivn

<!--toc:start-->
- [mivn](#mivn)
  - [What I want from it](#what-i-want-from-it)
  - [Running it](#running-it)
  - [Fonts](#fonts)
  - [Local overrides](#local-overrides)
  - [Layout](#layout)
  - [The additions](#the-additions)
<!--toc:end-->

My Neovim configuration, written from scratch on Neovim 0.12, for Neovide on
the desktop and the terminal everywhere else.

## What I want from it

- **Defaults first.** Vim's grammar as it ships is the product. The custom
  surface is a handful of leader keys and a few bridges, and it is meant to
  stay that small: anything rare goes through the command palette instead of
  earning a key.
- **My hands keep working.** I come from CUA editors (VS Code, Zed). Shift and
  an arrow selects, typing replaces the selection, the clipboard is the
  system one, PageUp/PageDown always go somewhere. All of it rides options
  Vim ships for exactly that purpose, so the grammar underneath stays intact
  while I learn it.
- **Looks matter.** The basalt theme, shared with my other tools; one
  status line, a tab bar of buffers, git in the gutter and in the tree.
- **A tool, not a project.** Few plugins, all pinned. New friction becomes a
  line in TODO.md and gets fixed in batches, not the same day.

## Running it

This is a plain Neovim configuration: clone it where Neovim looks and run
`nvim`.

```
git clone https://github.com/azazeal/mivn.git ~/.config/nvim
```

To try it without touching an existing configuration, clone it anywhere and
run it isolated under a different name:

```
git clone https://github.com/azazeal/mivn.git ~/.config/mivn
NVIM_APPNAME=mivn nvim
```

It needs Neovim's latest release. First run: `:MivnInstallGrammars` compiles
the tree-sitter grammars; it needs a C compiler.

## Fonts

Nothing here sets a font, on purpose. In the terminal the font is the
terminal's. In Neovide it comes from Neovide's own
`~/.config/neovide/config.toml`. A font and its size are a per-machine,
per-screen choice, and an editor config has no way to make that choice well;
Neovim cannot even ask the compositor for the monitor's physical size.

## Local overrides

`lua/mivn/local.lua` is optional, gitignored, and returns a table of personal
settings the config reads when the file exists;
`lua/mivn/local.example.lua` is the committed template to copy from. Two keys
today: `go_import_prefixes`, the import prefixes that count as yours when
grouping Go imports, keyed by the directory they apply under (so different
clients can group differently), and `lsp_servers`, edits to the
language-server table (add a server, re-point a binary, or drop one with
`false`). Without the file, Go imports group as standard library / everything
else / the current module, and the server table ships as
`lua/mivn/lsp.lua` writes it.

## Layout

| Path          | What it holds                                             |
|---------------|-----------------------------------------------------------|
| `init.lua`    | Options and the command-line setup                        |
| `lua/mivn/`   | One module per concern; trade-offs live in each header    |
| `colors/`     | The basalt theme                                     |
| `queries/`    | Tree-sitter extras: SQL in Go strings, gotmpl files       |
| `DEFAULTS.md` | The tour of stock Vim, and what mivn changes, marked so   |
| `TODO.md`     | State and queue; friction lands here first                |

## The additions

The whole custom key list: `<Space>f` find file, `<Space>/` search the
project, `<Space>b` buffers, `<Space>:` command palette, `<Space>h` help,
`<Space>d` diagnostics, `<Space>t` show or hide the file tree, `` <Space>` ``
show or hide the terminal, `gd` go to definition, `Ctrl+Del` delete the word
ahead, and `Ctrl+Tab` / `Ctrl+Shift+Tab` along the tab bar. `Esc` in Normal
mode also clears leftover search highlighting. Everything else is stock Vim, or a stock
option doing its documented job. [DEFAULTS.md](DEFAULTS.md) is the full
account, including what each bridge costs.
