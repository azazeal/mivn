# mivn

My Neovim configuration, written from scratch on Neovim 0.12, for Neovide on
the desktop and the terminal everywhere else.

![The dashboard, with the file tree beside it](assets/screenshot.png)

## What I want from it

- **Defaults first.** Vim's grammar as it ships is the product. The custom
  surface is a handful of leader keys and a few bridges, and it is meant to
  stay that small: anything rare goes through the command palette instead of
  earning a key.
- **My hands keep working.** I come from CUA editors (VS Code, Zed). Shift and
  an arrow selects, typing replaces the selection, `y` and `p` are the system
  clipboard while a delete is not, PageUp/PageDown always go somewhere. Most
  of it rides options Vim ships for exactly that purpose, so the grammar
  underneath stays intact while I learn it.
- **Looks matter.** The basalt theme, shared with my other tools; one
  status line, a tab bar of buffers, git in the gutter and in the tree.
- **A tool, not a project.** Few plugins, all pinned. New friction becomes a
  line in TODO.md and gets fixed in batches, not the same day.

## Installing

What has to be on the system:

- **Neovim's latest stable release** (0.12 or newer). The config leans on
  0.12 features: `vim.pack` for plugins, `'autocomplete'` for completion.
- **git**, which `vim.pack` uses to fetch the pinned plugins on first start.
- **A C compiler** (`cc`, `gcc`, or `clang` on `PATH`), which
  `:MivnInstallGrammars` needs: tree-sitter grammars compile from source.
  Without one, and until that command runs, the grammars Neovim ships with
  still highlight and everything else falls back to classic syntax
  highlighting; nothing breaks.
- **A Nerd Font**, for the icons in the tree, the tab bar, and the pickers.
  See [Fonts](#fonts) for where the font is actually chosen.
- **ripgrep** (or **fd**), optionally: `<Space>f` and `<Space>/` use whichever
  is installed, and fall back to slower built-ins otherwise.

Every language server comes from `PATH`, and this config installs none of
them: a server that is not on it is a language with tree-sitter colors and
nothing else, said once in `:checkhealth mivn`. Which toolchain a session
gets is the launcher's business, not this config's. The set in use is Go
(`gopls`, `golangci-lint-langserver`), Python (`ty`, `ruff`), TypeScript
(`tsgo`), Rust, Ruby, Lua, Elixir, Gleam, Shell, Markdown, TOML, YAML
(`yaml-language-server`, `actions-languageserver`, `zizmor`), JSON, HTML,
Terraform, Protocol Buffers, templ and the Docker files. The external
formatters (`stylua`, `shfmt`, `jq`, `taplo`, `yamlfmt`, `dockerfmt`,
`xmllint`) and `gci` for Go imports are looked up the same way.

What this config owns is everything around that: what each server is told
once it starts, what runs after it (`gci` re-groups Go imports after the
language server has formatted), and which JSON Schema a file gets. One file
per language under `lua/mivn/languages/` holds all of it for that language.
`:checkhealth mivn` reports the lot.

Servers run with the permissions you do, which is worth knowing before you
open someone else's repository: several of them run that repository's code
to answer questions about it. rust-analyzer builds `build.rs` and expands
proc macros, expert compiles `mix.exs`, gopls shells out to the toolchain.
Neovim has no workspace-trust prompt, and this config adds none.

This is a plain Neovim configuration: clone it where Neovim looks and run
`nvim`.

```
git clone https://github.com/azazeal/mivn.git ~/.config/nvim
```

The first start clones the plugins at their pinned revisions, which takes a
few seconds; then run `:MivnInstallGrammars` once for the grammars. There is
nothing else to fill in: this config has no personal-settings file, because
it is itself the settings.

To try it without touching an existing configuration, clone it anywhere and
run it isolated under a different name:

```
git clone https://github.com/azazeal/mivn.git ~/.config/mivn
NVIM_APPNAME=mivn nvim
```

## Fonts

Nothing here sets a font, on purpose. In the terminal the font is the
terminal's. In Neovide it comes from Neovide's own
`~/.config/neovide/config.toml`. A font and its size are a per-machine,
per-screen choice, and an editor config has no way to make that choice well;
Neovim cannot even ask the compositor for the monitor's physical size.

Under Neovide, `Ctrl+=`, `Ctrl+-` and `Ctrl+0` zoom in, out and back to 100%;
the numpad's `+`, `-` and `0` do the same. They scale what that file asked for rather than writing a size anywhere, so
100% keeps meaning whatever the file says. The step is foot's, near enough,
and it stops at half and at triple. In a terminal the keys are not mivn's to
take: foot has them and resizes its own font.

## A remote window

Neovim can run on one machine with its window on another: Neovide attaching
over ssh, with `--neovim-bin` pointing at a wrapper that runs the editor on
the far host. One command must not work there. `:restart` starts the new
editor on the machine the old one ran on and hands the window an address on
that machine's filesystem, so the window dies trying to connect and a
headless editor is left running behind it; Neovim's own docs call out the
same-system limit. mivn refuses `:restart` and `ZR` in that setup and says
why.

Export `MIVN_REMOTE_UI=1` in whatever launches the remote session to declare
it. Without the variable, a remote Neovide is still recognized by the
clipboard bridge it registers, but the variable is the supported switch: it
survives Neovide configuration changes and covers UIs this config has never
heard of.

## Layout

| Path          | What it holds                                             |
|---------------|-----------------------------------------------------------|
| `init.lua`    | Options and the command-line setup                        |
| `lua/mivn/`   | One module per concern; trade-offs live in each header    |
| `lua/mivn/keymaps.lua` | Every key that is on for the whole session       |
| `colors/`     | The basalt theme                                          |
| `queries/`    | Tree-sitter extras: SQL in Go strings, gotmpl files       |
| `DEFAULTS.md` | The tour of stock Vim, and what mivn changes, marked so   |
| `TODO.md`     | State and queue; friction lands here first                |

## The additions

Every key mivn takes is in one file, `lua/mivn/keymaps.lua`, and `<Space>?`
lists them from inside a running editor along with everything Vim and the
plugins bind.

The whole custom key list: `<Space>f` find file, `<Space>/` search the
project, `<Space>b` buffers, `<Space>:` command palette, `<Space>h` help,
`<Space>d` diagnostics, `<Space>?` every key there is, `<Space>t` show or hide
the file tree, `` <Space>` `` show or hide the terminal, `<Space>w` wrap long
lines in this window, `gd` go to definition, `Ctrl+Del` delete the word ahead,
`Ctrl+↑` / `Ctrl+↓` move the line or the selected lines, `Alt+D` / `Alt+C`
delete or change onto the clipboard, and `Ctrl+Tab` / `Ctrl+Shift+Tab` along
the tab bar. `y` and `p` are the system clipboard, `d` and `c` are not. `Esc`
in Normal mode also clears leftover search highlighting. Everything else is
stock Vim, or a stock option doing its documented job.
[DEFAULTS.md](DEFAULTS.md) is the full account, including what each bridge
costs.
