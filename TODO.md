# TODO

<!--toc:start-->
- [TODO](#todo)
  - [Before first real use](#before-first-real-use)
  - [Plugins](#plugins)
  - [Known bug: `:bd` with the cursor in the tree](#known-bug-bd-with-the-cursor-in-the-tree)
  - [UI](#ui)
  - [Languages](#languages)
  - [Later](#later)
  - [Done](#done)
  - [Dashboard, remaining](#dashboard-remaining)
<!--toc:end-->

Ordered roughly by what blocks daily use.

## Before first real use

- [x] Run `:MivnInstallGrammars` once. It compiles ~50 tree-sitter grammars and
      needs a C compiler. Without it only the grammars Neovim ships with are
      highlighted; everything else falls back to classic syntax highlighting
      and nothing breaks.
- [x] Decide `clipboard=unnamedplus`. Set. `y` and `p` reach the system
      clipboard with no prefix, and the cost is that `d`/`c`/`x` overwrite it
      too; `"_d` and `"0p` are the way around that. DEFAULTS.md, under
      Registers, has the account.

## Plugins

- [ ] Freeze every plugin at an explicit commit SHA, and write the tag or
      release that SHA belongs to next to it as a comment, so the pin is
      readable. Right now `plugins.lua` names only the source (and a branch,
      for nvim-treesitter), and the actual revisions live in
      `nvim-pack-lock.json`, which is generated. That means the file a person
      reads does not say what is installed, and a fresh clone depends on the
      lock file being in step. Pinning in `plugins.lua` itself makes the source
      the source of truth and the lock file merely a cache. `vim.pack.add`
      takes `version` as a SHA, a tag, or a branch, so this is a per-entry
      change; `vim.pack.update()` is what moves a pin forward, and the tag
      comment has to be updated with it.

## Fixed: `:bd` with the cursor in the tree

Fixed with the second of the two options that were on the table: guard the
command, not the buffer. Vim has no cancellable pre-delete event, so the
deletion cannot be vetoed; instead the command line is rewritten on
`CmdlineLeavePre`, the moment before it runs: any spelling of bdelete typed
alone from the tree window (`bd` through `bdelete`, bang or not) becomes a
command that explains instead of deleting. A command-line abbreviation was
tried first and measured flaky: `:bd!` typed right after an expanded `:bd`
sailed through unexpanded. Deliberately narrow either way: a count (`:2bd`)
or a scripted delete passes through and lands on the old
annoying-but-recoverable behavior, which the layout invariant in
`lua/mivn/tree.lua` keeps survivable.

The first option (subscribe to nvim-tree's `Event.TreeClose` to record intent
and heal deletions that lack one) was rejected as more machinery and more
coupling for the spellings nobody actually types. Worth remembering why plain
healing cannot work: **`:NvimTreeClose` deletes the tree buffer too**, so "the
buffer was deleted" cannot tell an accident from a deliberate close.

A second symptom was seen once in a live session and **could not be reproduced**:
after the collapse, `:NvimTreeOpen` left a completely blank full-window
`NvimTree_1` buffer, drawing no listing at all. Scripted repros recover cleanly
from every state tried, including a fully collapsed blank one, so this probably
needs the layout to be damaged in some way a script has not reached. Worth
watching for rather than hunting: if it happens again, capture `:ls!`,
`:echo winlayout()` and `:messages` before restarting, since those are the three
things that would have identified it.

## UI

- [x] Tab bar of open buffers (mini.tabline), always visible, unsaved shown by
      colour. Vim tabs are window layouts, not files, so `:tabnew` is unrelated
      to this bar; `]b` / `[b` step through it and need no new key.
- [x] Line numbers: absolute and relative together, so the current line reads
      as its real number and every other line reads as the count that reaches
      it. `DEFAULTS.md` has the worked example.
- [x] Tree: dotfiles and SCM-ignored each on their own toggle, `H` and `I`
      inside the tree. Already nvim-tree defaults, so this was documentation
      rather than configuration; both are session view state and reset on
      restart, which is the wanted behavior.
- [x] `-` and `Ctrl+]` in the tree, the two keys that **re-root** it, are
      unbound in `on_attach`. The project is the root and stays the root;
      re-rooting is not made deliberate, it is made impossible. Nothing was
      added in their place: expand and collapse were never missing (Enter
      toggles the directory, Backspace collapses the one the cursor is in,
      `E` / `W` do everything), and a `+`/`-`/`=` scheme was designed and then
      thrown away for exactly that reason.
- [x] Statusline, on mini.statusline: mode, git branch and a dirty dot,
      project-relative file name, diagnostics, language server, filetype and
      position. One line across the editor (`laststatus=3`) rather than one per
      window, so it pairs with the tab bar instead of drawing a strip under the
      tree as well. On the banner and in the tree it shows the branch and the
      project instead of `[Scratch][-]` and a column number.
- [x] Command line: back on the default single row. `cmdheight=0` was tried,
      and the rule written for it fired in the first real session (twice: a
      refused `:restart` and a startup message both turned into modal "Press
      ENTER" screens), so the row is back. A row of chrome is cheaper than a
      modal prompt; that rule stands if 0 ever tempts again.
      What survives the experiment: the mode and the pending command live on
      the statusline (`showmode=false`, `showcmdloc=statusline`), and cmdline
      completion is the built-in `wildmenu` as a popup (`wildoptions=pum`),
      opened as I type by a `CmdlineChanged` autocmd calling `wildtrigger()`,
      with `wildmode=noselect:lastused,longest:full,full` so the menu never
      inserts or preselects anything and `Tab` still fills in the unambiguous
      part before it cycles.
      No plugin, and noice.nvim was deliberately not taken: it moves the
      cmdline but also takes over messages, search and LSP progress, and when
      it breaks it owns the surface errors would print on.
- [x] Git signs in the gutter, via mini.diff (`lua/mivn/diff.lua`): bars for
      added and changed lines, an underscore where lines were deleted, colored
      with the same three git colors the tree and tab bar use. The comparison
      is against the index, so staging empties the gutter. `]h` / `[h` move
      between hunks, `gh` / `gH` stage / reset over a motion; all plugin
      defaults.
- [ ] Decide bracket pair coloring (Zed's `colorize_brackets`). Nothing built
      in does it; rainbow-delimiters.nvim is the plugin. A looks question as
      much as a plugin question, so it waits for a monthly batch.
- [ ] Test coverage in the gutter, the way Zed shows it for Go. Nothing live
      exists here: coverage comes from a `go test -coverprofile=...` run, and
      neither the language server nor mini.diff reads the profile. Two routes:
      nvim-coverage, which signs the lines but pulls in plenary.nvim, or an
      in-house parser, since the coverprofile format is one line per range
      (`file.go:12.2,15.9 3 1`) and extmarks do the rest. Decide in a monthly
      batch, not now.
- [ ] Centered, unmissable prompts instead of the bottom bar, via
      `vim.ui.input` / `vim.ui.select` overrides. Open question: whether they
      should be dismissable with Esc. They should; a prompt you cannot escape
      traps you the first time you open one by mistyping.

## Languages

- [x] Format on save for file types with no language server, as a table of
      external formatters in `lua/mivn/lsp.lua`: `stylua` for Lua, `shfmt` for
      shell, `jq` for JSON, `taplo` for TOML, `xmllint` for XML. An entry is an
      **override**, not a fallback: it beats the server, because a server having
      a formatter does not make it the right one. `lua-language-server` will
      format Lua and `stylua` is what the Lua world uses.
      A formatter that exits non-zero leaves the buffer untouched and reports
      why, so a syntax error cannot empty the file. Verified with broken Lua.
- [x] Nine servers on: `gopls`, `rust-analyzer`, `expert`, `buf`,
      `lua-language-server`, `yaml-language-server`, `taplo`, `marksman`,
      `stylua` alongside them.
- [ ] `rust-analyzer` is counted above and is **not actually installed**. What
      is on PATH is rustup's shim, and the component behind it is missing, so
      running it recurses until rustup gives up with "infinite recursion
      detected". `rustup component add rust-analyzer` is the fix.
      The reason this went unnoticed is worth more than the fix: the check in
      `lsp.lua` is `vim.fn.executable()`, and a rustup shim is an executable
      whatever is behind it. So the server was enabled, failed to start, and
      `:MivnServers` reported it `on`. Every rustup tool can do this. Decide
      whether the check should run the binary rather than just find it, at the
      cost of a subprocess per server at startup.
- [x] `rust-analyzer` runs `clippy` rather than `cargo check` for diagnostics.
      Clippy itself is installed and real (0.1.97), unlike the above.
- [ ] The servers still missing are the npm ones: `bashls`, `jsonls`, `cssls`,
      `html`, `ts_ls`, `dockerls`. Node is on asdf here with 24.16.0 installed
      but **no global version set**, so `npm i -g` has nowhere to go. Decide
      whether to `asdf set -u nodejs 24.16.0` or leave those languages to
      tree-sitter. JSON is the only one that stings, and `jq` already formats
      it; what is lost is schema validation from SchemaStore.
- [ ] `lemminx` (XML) and `jsonnet-language-server` are not in Homebrew.
      `xmllint` covers XML formatting in the meantime.
- [ ] Decide about `yq` for YAML. Left out on purpose: `yaml-language-server`
      formats now, and yq is a query tool that happens to re-emit YAML, so it
      normalizes quoting and anchors in ways a formatter should not.
- [ ] Verify `expert` attaches on a real Elixir project. It is installed but
      has not been exercised.
- [ ] `sqls` needs a connection configured before it does anything useful.
      Worth deciding whether it earns its place at all, given the SQL that
      matters here is embedded in Go.
- [ ] Check whether treesitter indentation beats the built-in ftplugins for
      any of these. It is off right now on the assumption it does not.
- [ ] Markdown: decide the writing set. Three things are missing today.
      Formatting: marksman does not format, and the formatter table has no
      markdown entry, so tables stay as typed; `prettier` formats pipe tables
      but needs the npm decision above, `mdformat` (Python) and `deno fmt` are
      the other candidates. Preview and mermaid: nothing renders inside the
      terminal or Neovide; peek.nvim (deno) and markdown-preview.nvim (node)
      both preview in the browser with mermaid support. In-buffer polish:
      render-markdown.nvim prettifies headings and tables in place but renders
      no diagrams. A monthly-batch decision, not a today one.
- [ ] Decide whether to offer editor-managed language servers, for people who
      would rather not install each binary by hand. The candidate design is a
      `local.lua` flag, off by default, that turns on mason.nvim plus
      mason-lspconfig and lets them install whatever server is missing. The
      default stays what it is: the binary has to be on `PATH`, which is what
      per-project toolchains through direnv already feed. Deciding this and
      wiring it is a monthly-batch item.

## Later

- [ ] Install the `mivn` launcher onto `PATH`, so the scripts that start it
      stop hard-coding the repo path.
- [ ] Decide whether the config should be reachable over SSH, and how. `mivn`
      already falls back to the terminal UI on an SSH login, but the config
      itself lives in this repo on this machine.

## Done

- [x] `mivn` launcher: Neovide on a Wayland session, foot otherwise, terminal
      UI over SSH or with `-nw`. Isolated under `NVIM_APPNAME`, so a stock
      Neovim on this machine is untouched.
- [x] direnv, applied only when the `.envrc` is already allowed.
- [x] Fixed a missing comma in `plugins.lua` that made the whole `vim.pack.add`
      table a syntax error. Worth remembering for how it showed up rather than
      for the fix: headless Neovim prints the error and carries on, so every
      scripted check passed, while Neovide stopped at the hit-enter prompt
      before it ever mapped a window and sat at 100% CPU. From the outside it
      looked like the window-manager script that launches it was broken, since
      that script waits 15s for a window with the right app id and then gives
      up. A config error and a launcher error look identical from there; check
      for a live `neovide` process with no window before suspecting the script.
- [x] `basalt` theme (born `modest-dark`), ported from the same source as the themes for my
      other tools.
- [x] Greek `langmap`. See `DEFAULTS.md`; the punctuation limits are real and
      not worth fighting.
- [x] EditorConfig, with a tab width of 4 as the fallback.
- [x] Tree-sitter highlighting, folds, and SQL injection into `/* sql */`
      tagged Go strings.
- [x] `.tmpl` and `.tpl` as `gotmpl`, with the language named by the rest of
      the file name highlighted in between the actions: `foo.json.tmpl` is JSON
      and Go template at once, not one or the other. Better than a
      strip-the-suffix rule, which loses the actions. chezmoi's other rule is
      covered too: everything under a `.chezmoitemplates` directory is a
      template whatever it is called, and there the name itself, not what is
      left of it, says which language. `jsonc` maps onto the `json` parser
      while it has no grammar of its own.
- [x] Language servers, started only when the binary exists.
- [x] Go format on save: gopls organizes imports and gofmts, then gci re-splits
      the imports into their blocks.
- [x] Completion, using Neovim's built-in support rather than a plugin. The
      menu opens as you type (`'autocomplete'`, 0.12), merging the language
      server with the words in the open buffers. Arrows walk it, `Enter` and
      `Tab` take a match, `Ctrl+Space` opens it on demand. See `DEFAULTS.md`,
      under Completion, for why `Enter` still breaks the line most of the time.
- [x] Landing buffer: banner, tagline, byline, centered and re-centered on
      resize. Shows at startup with nothing to edit (including `mivn <dir>`,
      in place of a file listing) and again when the last real buffer closes.
      No recents, no projects, no lists of any kind, on purpose.
- [x] The keys Vim has no default for: `<leader>f` find file, `<leader>/`
      search the project, `<leader>b` buffers, `<leader>:` command palette,
      `<leader>h` help, `<leader>d` diagnostics, and `gd` for go-to-definition.
      Leader is Space. That is the whole list of additions.
- [x] File tree, for orientation rather than navigation: open at startup beside
      the landing buffer without taking focus, 32 columns, git colors on the
      file name, dotfiles shown and gitignored hidden. Started with no
      keybinding at all; that lost to reality, since hiding a panel to get the
      width back is a constant CUA gesture, not a couple-of-times-a-day one.
      `<leader>t` now toggles it, keeping focus where it is.
- [x] which-key, on every prefix rather than just leader, so pressing `d` or
      `g` lists what completes it while the grammar is still being learned.
- [x] Command palette showing descriptions, not bare names. 605 commands are
      only searchable if you already know what a thing is called; the 25 that
      carry a real description now show it.
- [x] No cross-session history. `shada` is off, so there is no `:oldfiles`, no
      per-file marks and no jumplist surviving a restart, and therefore nothing
      holding paths that can go stale when a directory is renamed. `undofile`
      is kept: it is per-file undo, never a place to return to.
- [x] mini.pairs, as a trial: auto-closing pairs, defaults untouched. Enter
      stays complete.lua's mapping and calls `MiniPairs.cr()` on its newline
      path, the integration the plugin's docs ask for. If it fights more than
      it helps, deleting `lua/mivn/pairs.lua` and the two lines naming it ends
      the trial; the Enter mapping survives that (pcall).
- [x] The everyday built-in commands (`:bd`, `:q`, `:vs`, ...) described by
      hand in the command palette. Built-ins carry no description Neovim
      exposes, and the command-line completion menu cannot annotate its
      candidates at all, so the palette is where "what does this do" lives.

## Dashboard, remaining

- [ ] Plugin-update notice on the dashboard. Deferred on purpose, not
      forgotten. Three things are already known about it:

      No plugin is needed to *do* the update. `vim.pack.update()` is built in
      and opens a review buffer with the changelog per plugin, `:write` to
      apply and `:quit` to discard, `]]` and `[[` to move between plugins.
      That is already better than most plugin managers' update UI.

      What is missing is only the notice, and it has to be ours, because
      `vim.pack` has no check-without-applying mode. So: a background
      `git fetch` per plugin plus `git rev-list --count HEAD..origin/<branch>`,
      counted up into one line under the byline.

      **It must not touch an SSH key, and today it would.** The global
      `~/.gitconfig` carries
      `url."ssh://git@github.com/".insteadOf = https://github.com/`, so every
      plugin here was actually cloned over SSH despite `plugins.lua` naming
      https URLs (`git -C <plugin> remote -v` shows `ssh://git@github.com/`).
      It works right now only because the key is in the agent and Neovide
      inherits `SSH_AUTH_SOCK` from the session; a background fetch without an
      agent would hang on a passphrase prompt nothing is drawing.

      The fix is `GIT_CONFIG_GLOBAL=/dev/null` on the git subprocess, which
      drops the rewrite and fetches anonymous https. Verified. Note that you
      cannot instead *override* the rewrite with a competing rule: git picks
      the longest matching prefix and ties go to the first one seen, so an
      equal-length rule always loses. Scope the variable to the two places that
      need it (the background check, and a wrapper around `vim.pack.update`),
      never to the whole Neovim process, or `:terminal` loses the user's git
      config too.
- [x] Hide the cursor while the landing buffer is focused. It was more
      machinery than it looked, and the tree wanted the same thing, so it lives
      in `lua/mivn/panel.lua`: a filetype is registered as a panel, and one
      autocmd swaps `guicursor` for a blended-out highlight group on arrival and
      puts the saved value back on the way out. Recomputed from where the cursor
      actually is rather than paired enter/leave hooks, so nothing can leave it
      hidden in a window that never asked for it.
      The limit is real and cannot be fixed here: only a GUI draws its own
      cursor, so Neovide obeys the blend and foot keeps drawing a block wherever
      the panel's highlighted row is.
- [x] The banner re-centers to its own window now, not the whole editor: the
      re-render fires on `WinNew`, `WinClosed`, `WinResized` and `VimResized`,
      scheduled so the layout has settled first. `WinNew`/`WinClosed` are the
      ones that matter for the tree and the terminal panel; `WinResized` alone
      would not have covered them, and it never fires headless, so the tests
      drive the others.
- [x] Every highlight group centralized into `colors/basalt.lua`. The
      per-module `theme()` functions and their `ColorScheme` autocmds are gone,
      and the palette names in that file are now the only color notation
      anywhere outside `colors/`. Two colors had no palette name, the fire
      gradient's middle steps, and they are declared beside the banner's
      section there.
      The ordering question this raised has a clean answer: the colorscheme
      runs before the plugins are set up, and every plugin involved (mini.*,
      nvim-tree, which-key) registers its groups as defaults (`default = true`,
      `hi def`), which never overwrite an existing definition. So the
      colorscheme wins even though it ran first, and what the per-module load
      order used to buy is no longer needed. Confirmed by dumping the resolved
      groups before and after: byte for byte the same.
      It also fixed something on the way: the banner's colors used to be set
      inside its render pass, so `:colorscheme basalt` on a running editor
      left them cleared until the next re-render. Now the one pass restores
      everything.
