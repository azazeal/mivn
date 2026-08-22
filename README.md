# mivn

My Neovim configuration: a few pinned plugins, one leader namespace, and a
written account of what it changes over a stock `nvim` configuration.

It runs wherever Neovim runs and does not care where that is. The config
works in the terminal, it works in GUIs like Neovide, and it stays out of
my way, unless I'm about to do something smart, like `:restart` in a
Neovide instance that happens to be wrapping a Neovim session on another
host.

![The mivn dashboard: the block logo and its key hints, with the file tree open beside it and the status line reading NORMAL on branch main](assets/screenshot.png)

## Installing

This is a plain Neovim configuration: clone it where Neovim looks and run
`nvim`.

```
git clone https://github.com/azazeal/mivn.git ~/.config/nvim
```

The first start clones the plugins at their pinned revisions, which takes a
few seconds; then run `:MivnInstallGrammars` once for the grammars. There is
nothing else to fill in: this config has no personal-settings file, because
it _is_ the settings.

To try it without touching an existing configuration, clone it anywhere and
run it isolated under a different name:

```
git clone https://github.com/azazeal/mivn.git ~/.config/mivn
NVIM_APPNAME=mivn nvim
```

The configuration should work with any Neovim from v0.12 onwards. Other than
that, it relies on the following (the first three on `PATH`):

1. `git`, which `vim.pack` uses to fetch the pinned plugins on first start.
2. A C _compiler_ like `cc`, `gcc`, or `clang`, which
   [`:MivnInstallGrammars`](#commands) needs to compile the tree-sitter
   grammars stock Neovim does not come with. Skipping it breaks nothing:
   until that command runs, the grammars Neovim already ships with keep
   highlighting and every other language falls back to classic syntax
   highlighting.
3. `ripgrep` (or `fd`), optionally: `<Space>f` and `<Space>/` use whichever
   is installed, and fall back to slower built-ins otherwise.
4. A _Nerd Font_, for the icons in the tree, the tab bar, and the pickers.
   See [Fonts](#fonts) for where the font is actually chosen.

## Commands

Everything `mivn` adds is under one prefix, so `:Mivn` and `<Tab>` is the whole
list from inside the editor.

| Command | What it does |
|---|---|
| `:checkhealth mivn` | Runs every configured server and formatter once and reports which ones actually answer |
| `:MivnTrust [action] [dir]` | Decides whether this workspace may have code run for it. See [Trust](#trust) |
| `:MivnInstallGrammars` | Compiles the tree-sitter grammars mivn knows about. Run once after cloning |
| `:MivnUpdateGrammars` | Updates every installed grammar |
| `:MivnUpdate` | Pulls the newest mivn, if this checkout has no changes of its own |
| `:MivnDashboard` | Opens the landing buffer again |
| `:MivnBdAll` | Closes every file buffer and leaves the panels standing |
| `:MivnBdOthers` | Closes every file buffer except this one |
| `:MivnRestartRemote` | What `:restart` becomes when the window is on another machine |
| `:MivnTreeBd` | What `:bd` typed inside the tree becomes. It closes nothing and says how to leave the tree instead |

Three of those are reached by their short spellings instead, because that is
what the fingers already type: `:bda` is `:MivnBdAll`, `:bdo` is
`:MivnBdOthers`, and a bare `:%bd` is rewritten to `:MivnBdAll` so the tree
and the terminal survive it. Stock `:bd` is untouched.

`:MivnUpdate` implements the manual half of a check that runs on its own: once a
day, at most, mivn asks the remote whether there is a release tag it does not
have, using one `git ls-remote` that fetches nothing and writes nothing into the
repository. It only considers releases and not commits.

## Language servers and tools

Every language server comes from `PATH`, and this config installs none of
them: a server that is not on it is a language with tree-sitter colors and
nothing else, said once in `:checkhealth mivn`. Which toolchain a session
gets is the launcher's business, not this config's.

The set in use is Go (`gopls`, `golangci-lint-langserver`), Python (`ty`,
`ruff`), TypeScript (`tsgo`), Rust, Lua, Elixir, Gleam, Shell, Markdown,
TOML, YAML (`yaml-language-server`, `actions-languageserver`, `zizmor`), JSON,
HTML, Terraform, Protocol Buffers, templ and the Docker files. The external
formatters (`stylua`, `shfmt`, `jq`, `taplo`, `yamlfmt`, `dockerfmt`,
`xmllint`) and `gci` for Go imports are looked up the same way.

What this config owns is everything around that: what each server is told
once it starts, what runs after it (`gci` re-groups Go imports after the
language server has formatted), and which JSON Schema a file gets. One file
per language under `lua/mivn/languages/` holds all of it for that language.
`:checkhealth mivn` reports the lot.

### Trust

Servers run with the permissions you do, and several of them run the
repository's own code to answer questions about it: `rust-analyzer` builds
`build.rs` and expands proc macros, `expert` compiles `mix.exs`, `gopls` shells
out to the toolchain. So opening a repository is running it, and the workspace
has to be trusted before any of that starts. Until it is, no server starts and
nothing formats on save; files open, tree-sitter colors them, and the editor
is an editor.

The workspace is the directory the editor is working in, not the root each
server picks for itself, so one answer covers everything under it, including
a dependency's source or the standard library reached from inside it.

| `:MivnTrust ...` | What it does |
|---|---|
| `allow`, or no argument at all | Trusts this workspace and starts its servers there and then |
| `deny` | Records that it must not run, which covers everything under it |
| `forget` | Drops the decision, so the question is open again |
| `status` | Says where this directory stands, and which directory decided it |

A directory can be named as a second argument; without one the command means
the workspace. Decisions live in Neovim's own trust list, the file `:trust`
writes, so `:trust` still reads them. `:checkhealth mivn` lists every
directory decided about, either way.

It is a gate and not a sandbox: a server that does start runs as you.

## Leader maze

Every key mivn takes is in one file, `lua/mivn/keymaps.lua`, and `<Space>?`
lists them from inside a running editor along with everything Vim and the
plugins bind. Holding a prefix for a moment shows what can follow it, so the
tables below are the same list the editor will show you.

Six keys sit directly on the leader and the rest are grouped, so what you
remember is three words rather than two dozen keys: code, goto, toggle.

### Find

All six open the same floating window, so its own keys are learned once.

| Key | Opens |
|---|---|
| `<Space>f` | Find file |
| `<Space>/` | Search the project |
| `<Space>b` | Open buffers |
| `<Space>:` | Command palette |
| `<Space>h` | Help |
| `<Space>?` | Every key, searchable |

### Code, the `<Space>a` chain

| Key | What it does |
|---|---|
| `<Space>aa` | Code action |
| `<Space>ar` | Rename symbol |
| `<Space>af` | Format this buffer |
| `<Space>aF` | Organize imports |
| `<Space>ai` | Hover documentation |
| `<Space>ax` | Run the code lens on this line |
| `<Space>ad` | Diagnostics in this buffer |
| `<Space>aD` | Diagnostics in the workspace |

### Goto, the `<Space>g` chain

| Key | Where |
|---|---|
| `<Space>gd` | Definition |
| `<Space>gD` | Declaration |
| `<Space>gi` | Implementation |
| `<Space>gt` | Type definition |
| `<Space>gr` | References |
| `<Space>gs` | Symbols in this document |
| `<Space>gS` | Symbols in the workspace |

One answer jumps straight there. Several open in the same floating window as
the finders above, rather than in a quickfix split that rearranges the layout.

Neovim's own LSP keys are taken off, `grn`, `gra`, `grr`, `gri`, `grt`, `grx`,
`gO` and `K` included. Two keys for one request is two things to keep in step,
and these chains are the ones with a panel behind them.

### Toggle, the `<Space>t` chain

| Key | What it flips |
|---|---|
| `<Space>tt` | The file tree |
| `` <Space>t` `` | The terminal |
| `<Space>tw` | Wrapping long lines, in this window |
| `<Space>th` | Dotfiles, in the tree and the finders at once |
| `<Space>ti` | Files the SCM ignores, in the tree and the finders at once |
| `<Space>tr` | The old text, inline, for every line I have changed |

The last two answer for both views of a directory, so a file drawn in one and
missing from the other cannot happen.

## Changed keys

Keys that already meant something in stock Vim and mean something else here:

| Key | What it does here |
|---|---|
| Shift and an arrow | Selects, by a character or a line |
| Ctrl+`→` / Ctrl+`←` | Past the end of the word / the start of the previous one, never the WORD |
| Alt+`→` / Alt+`←` | The same, by subword |
| Ctrl or Alt and Shift | The same two distances, selecting |
| `Home` | Alternates between the indent and column zero |
| `End` | Past the end of the line, the boundary after the last character |
| `Insert` | Whichever of Insert and Normal you are not in |
| Shift+PageUp / PageDown | Select a page, stopping at the first and last line |
| `Ctrl+Tab` / `Ctrl+Shift+Tab` | Along the tab bar of buffers |
| `Ctrl+↑` / `Ctrl+↓` | Move the line, or the selected lines |
| `Ctrl+Del` | Delete the word ahead |
| `Alt+D` / `Alt+C` | Delete or change onto the clipboard |
| `{count}` and `\|` | That column, counted in characters rather than screen cells |
| `Esc` in Normal mode | Also clears leftover search highlighting |
| `ZR` | `:restart`, unless the window is on another machine |

`y` and `p` are the system clipboard; `d` and `c` are not. A selection opened
while typing lands in Select mode, where what you type next replaces it; one
opened from Normal mode lands in Visual, where the whole grammar applies and a
stray letter is a command.

Everything else is stock Vim, or a stock option doing its documented job.
[DEFAULTS.md](DEFAULTS.md) is the full account, marks every deviation, and
says what each one costs.

## Fonts

Nothing here sets a font, on purpose. In the terminal the font is the
terminal's. In Neovide it comes from Neovide's own
`~/.config/neovide/config.toml`. A font and its size are a per-machine,
per-screen choice, and an editor config has no way to make that choice well;
Neovim cannot even ask the compositor for the monitor's physical size.

Under Neovide, `Ctrl+=`, `Ctrl+-` and `Ctrl+0` zoom in, out and back to 100%;
the numpad's `+`, `-` and `0` do the same. They scale what that file asked
for rather than writing a size anywhere, so 100% keeps meaning whatever the
file says. The step is foot's, near enough, and it stops at half and at
triple. In a terminal the keys are not mivn's to take: foot has them and
resizes its own font.

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
| `lua/mivn/languages/` | One file per language: its servers, settings and formatting |
| `colors/`     | The basalt theme                                          |
| `queries/`    | Tree-sitter extras: SQL in Go strings, gotmpl files       |
| `DEFAULTS.md` | The tour of stock Vim, and what mivn changes, marked so   |
| `TODO.md`     | State and queue; friction lands here first                |
