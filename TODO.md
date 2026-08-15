# TODO

Ordered roughly by what blocks daily use. Done items are deleted, not
checked off; git remembers them.

## UI

- [ ] Test coverage in the gutter, the way Zed shows it for Go. Nothing live
    exists here: coverage comes from a `go test -coverprofile=...` run, and
    neither the language server nor mini.diff reads the profile. Two routes:
    nvim-coverage, which signs the lines but pulls in plenary.nvim, or an
    in-house parser, since the coverprofile format is one line per range
    (`file.go:12.2,15.9 3 1`) and extmarks do the rest. Decide in a monthly
    batch, not now.

- [ ] Guard ui2's pager window against opening files into it. Measured on
    2026-08-04: with focus in the pager, `:view /etc/hosts` opens the file
    inside the float, and ui2 later swaps its own buffer back in, leaving
    the file loaded but shown nowhere. 'winfixbuf' on the pager window is
    the obvious guard, but ui2 itself puts buffers into that window when it
    rebuilds one, and a fixed buffer turns that into an error, so the clean
    version of this fix is upstream's to make. File it there, or carry a
    careful local one.

- [ ] Ctrl+Shift and an arrow over-reaches in one sequence. Measured on
    2026-08-04: one Shift+Right, then Ctrl+Shift+Right, selects two words
    rather than one. With "startsel" in 'keymodel' and the selection still
    one character wide (the cursor sitting on its own anchor), Vim runs the
    key's built-in `W` first and the mapping in lua/mivn/cua.lua then adds
    its `w` on top; an `<Nop>` in place of the mapping still moves, so the
    built-in is not mine to stop. Every other order is right, including two
    Shift+Rights and then Ctrl+Shift+Right. Taking shift-selection off
    'keymodel' and mapping all eight keys by hand would fix it and costs
    more than the bug does. The same one-character-wide state also costs
    Shift+PageDown one extra line (measured: 90 -> 112 where a 21-line
    window says 111), a milder case of the same thing.

## Languages

- [ ] Check whether treesitter indentation beats the built-in ftplugins for
    any of these. It is off right now on the assumption it does not.
- [ ] `:MivnInstallGrammars` cannot repair a half-installed grammar. It skips
    a language whose parser is already there, so a broken query link is
    invisible: the parser loads, highlighting turns on, and every capture
    comes back empty, which reads as "the colorscheme forgot this language".
    That is what the move off lazy.nvim left behind in `~/.config/nvim`: 30
    languages whose `queries/<lang>` still pointed into the old `lazy/`
    directory, relinked by hand on 2026-08-03. Either check the links on
    install or say it in `:checkhealth mivn`.
- [ ] Markdown: decide the writing set. Three things are missing today.
    Formatting: marksman does not format, and the formatter table has no
    markdown entry, so tables stay as typed and nothing runs on save.
    `mdformat` (Python, and mise already provisions it) is the candidate now
    that deno is gone; `deno fmt` would bring a runtime back for one file
    type, and `prettier` would drag node in. Preview and mermaid: nothing
    renders inside the terminal or Neovide; peek.nvim (deno) and
    markdown-preview.nvim (node) both preview in the browser with mermaid
    support, and both cost a runtime. In-buffer polish:
    render-markdown.nvim prettifies headings and tables in place but renders
    no diagrams. A monthly-batch decision, not a today one.
- [ ] Sandbox the installs too, which is the last of the store's guarantees
    with no replacement. The store promised one manifest in git, an exact
    version and a sha256 per platform verified before anything ran, and no
    install without a prompt. Two of the three replacements are decided, on
    2026-08-15:

      release age    `minimum_release_age = "14d"` globally, with `"0"` on
                     go and rust, which are trusted further. That is the
                     worm case covered: a package compromised on Monday is
                     never installed unless nobody notices for two weeks.
      lockfile       **no**, deliberately. It would buy the same versions on
                     both machines and a record of which bytes ran, and it
                     would cost the thing the mise config is written for:
                     nothing is pinned to a patch so a security release
                     arrives on its own. Eventual consistency between the
                     laptop and the macbook is fine. Do not revisit without
                     a reason that is not tidiness.
      servers        confined, see lua/mivn/sandbox.lua.

    What is left is the installs. mise has a sandbox of its own in
    `src/sandbox/`, Landlock plus seccomp on Linux and the macOS sandbox,
    with deny_read, deny_write, deny_net, deny_env and allow lists, and
    lua/mivn/sandbox.lua already puts every server behind it.

    **It does not cover installs.** `with_sandbox` is called from
    `cli/run.rs`, `cli/exec.rs` and `task/task_executor.rs` and from nowhere
    in the install path, so the one moment foreign code actually runs, a
    `go install` building a module or an npm postinstall, is the one moment
    mise does not confine.

    The rule, decided 2026-08-15: **prefer backends that download a built
    artifact (aqua, github, http) over ones that build**. It costs nothing,
    it is checkable by reading the config, and npm installs already run with
    `--ignore-scripts`, which is where that ecosystem's worms live.

    Two standing exceptions, both because Go publishes no binaries at all:
    `go:golang.org/x/tools/gopls` and `go:github.com/daixiang0/gci`. gci's
    releases page has no assets whatsoever, so aqua's own recipe for it is a
    go_install too. Those two are what bwrap would still be for, if it is
    ever worth it.

    Note what the server sandbox does not reach either: rust-analyzer runs a
    project's build scripts and proc macros as part of its job, so those run
    confined but they do run. That was equally true under the store, behind
    a prompt that only ever gated the download.

- [ ] Facts written twice, waiting to drift; found by the 2026-08-04
    review, parked for a monthly batch. find.lua's BUILTINS table
    hand-describes 21 Ex commands, and its prose-vs-code regex hides any
    real description that mentions a call like `foldexpr()`.
    local.example.lua's long header mirrors the behavior of lsp.lua by hand.
    health.lua's PROBES table is keyed by binary name while everything
    around it is keyed by server name. Each is fine today and wrong the day
    its twin changes.

## Plugins

- [ ] `:checkhealth mivn` should list plugin clones on disk that
    plugins.lua no longer mentions. vim.pack deletes nothing on its own, so
    a dropped plugin lingers under site/pack on every other machine, and
    each boot there "repairs" the lock to account for the orphan, which
    keeps nvim-pack-lock.json forever dirty in git. Measured 2026-08-04: a
    leftover SchemaStore.nvim did exactly that on another machine, and
    `:lua vim.pack.del({ "<name>" })` was the cleanup; the check should
    name the orphans and point at it.

## Dashboard

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

    Half of that now exists. `lua/mivn/update.lua` already owns a line under
    the byline, the once-a-day cache under `stdpath("state")`, and the
    environment that keeps a background git off ssh; it asks about mivn's own
    releases. The plugin count belongs on the same line, through the same
    cache, not on a second one.

    **It must not touch an SSH key.** A global gitconfig can rewrite the
    https plugin URLs to ssh (`url.<base>.insteadOf`), and then a
    background fetch on a machine whose agent holds no key hangs on a
    passphrase prompt nothing is drawing.

    The fix is `GIT_CONFIG_GLOBAL=/dev/null` on the git subprocess, which
    drops the rewrite and fetches anonymous https. Verified, and half in
    place: plugins.lua wraps `vim.pack.update` with exactly that, so the
    background check only has to do the same. Note that you cannot instead
    *override* the rewrite with a competing rule: git picks the longest
    matching prefix and ties go to the first one seen, so an equal-length
    rule always loses. Never set the variable for the whole Neovim process,
    or `:terminal` loses the user's git config too.

- [ ] Whether the tools this workspace uses have newer releases, on the
    same line. mise answers the whole question: `mise outdated --json`
    gives `{name, requested, current, latest, source}` per tool, and the
    global config declares gopls, gci, golangci-lint and its language
    server alongside go and rust, so one call covers the servers and the
    toolchains together.

    Same shape as the mivn check beside it: one call a day, the answer in
    update.lua's cache under `stdpath("state")`, a notice and nothing more.
    No command to apply it: `mise upgrade` is the yes, and it belongs in a
    terminal where its output is visible.

    No cooldown of ours. mise has `minimum_release_age` (24h by default,
    absolute dates accepted too), so a week's wait is one line in the mise
    config and applies to every tool on the machine rather than to the four
    Neovim happens to care about.

    `current` is null for a tool that is declared and not installed, which
    reads as "nothing to upgrade" and is really "nothing is there". Say
    that case differently, or `mise install` never gets suggested.

## Watching

Seen once, not reproduced, not forgotten:

- Neovide and `:restart` under the ui2 trial: one session hung on restart with
  no dashboard and the old buffers still loaded, and after closing the buffers
  by hand the statusline and the command line were gone. Not reproduced since,
  2026-08-04: a scripted `:view` + `:restart` comes back clean in the TUI and
  in a fresh Neovide, and the server state after both is healthy, so whatever
  breaks lives in Neovide's reattach once a session has more history behind
  it. If it happens again, before recovering run `nvim --server <sock>
  --remote-expr` from outside and capture 'laststatus', 'cmdheight',
  `nvim_list_uis()` and the window list; those say which half is broken, the
  server or the window.

- After a layout collapse in the tree, `:NvimTreeOpen` left a completely blank
  full-window `NvimTree_1` buffer, drawing no listing at all. Scripted repros
  recover cleanly from every state tried, so this probably needs the layout to
  be damaged in some way a script has not reached. If it happens again, capture
  `:ls!`, `:echo winlayout()` and `:messages` before restarting; those are the
  three things that would identify it.
