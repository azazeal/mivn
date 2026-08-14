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
- [ ] Decide what replaces the store's guarantees, before the entry below
    happens and before any release. The store promised one manifest in git,
    an exact version and a sha256 per platform verified before anything ran,
    and no install without a prompt. mise can give all of that back, and
    none of it is on here today. Measured 2026-08-15, on this machine:

      `mise settings lockfile`         not set, and no mise.lock anywhere,
                                       so nothing records which version or
                                       which bytes were installed
      `sandbox.deny_all`, `deny_net`   false
      `paranoid`                       false
      `minimum_release_age`            not set, so no release-age damping,
                                       the guard praktoras's notes already
                                       argued for

    bubblewrap may not be needed for half of it: mise has a sandbox of its
    own in `src/sandbox/`, Landlock plus seccomp on Linux and the macOS
    sandbox, with deny_read, deny_write, deny_net, deny_env and allow lists.

    **It does not cover installs.** `with_sandbox` is called from
    `cli/run.rs`, `cli/exec.rs` and `task/task_executor.rs` and from nowhere
    in the install path, so the one moment foreign code actually runs, a
    `go install` building a module, an npm postinstall, pipx, is the one
    moment mise does not confine. That is where bwrap earns its place, or
    else a rule that only download-shaped backends (aqua, github) are used
    and never ones that build.

    The other half is bigger and older: rust-analyzer runs a project's build
    scripts and proc macros, so opening a repo someone else wrote runs their
    code. That was equally true under the store; it was just behind a
    prompt. mise's exec sandbox is the lever there, since shims go through
    `Exec::run_with_toolset`.

    Order to decide in: lockfile on, `minimum_release_age` set, then whether
    the sandbox goes around installs (bwrap), around the servers (mise's
    own), or both.

- [ ] Stop installing language servers here. Decided 2026-08-14, and it
    supersedes the entry below: mise installs them and mivn finds them on
    PATH, until either praktoras is real or enough servers ship as single
    binaries that neither is needed.

    The reason is not that the store is bad. It works, and its failure
    modes were paid for in real bugs. It is that it is a package manager
    living inside an editor config, roughly 1300 lines of the 3900 here,
    and mise does the same work for the whole machine, so every editor and
    every shell gets the answer instead of this one. The coupling that
    actually matters, gopls having been built by a Go at least as new as
    the project's, is something mise gets right through GOBIN being per
    install, and the store cannot express at all: it pins one binary per
    platform and knows nothing about toolchains.

    What goes when it goes: store.lua, lsp/managed.lua, the consent file
    under stdpath("state"), the managed half of health.lua, `:MivnLsp`,
    and the README paragraph. lsp.lua's `servers` table becomes the whole
    list, and every entry in it is a PATH check.

    What has to be true first, or a half-done day is a day with no
    language servers at all: the dotfiles migration lands, every server in
    the manifest has a home in mise or in a `go install` beside it, and
    `:checkhealth mivn` finds all of them on PATH. lua/mivn/env.lua is the
    first half of that and is already here.

    Carry the knowledge out before deleting the code. The store's header
    and health.lua's PROBES table hold things no document elsewhere
    records: expert has no version flag, superhtml exits 0 on --version
    while printing nothing useful, a rustup shim is an executable that is
    not a program. praktoras wants all three.

- [ ] Managed language servers, the rest. The engine lives in
    lua/mivn/store.lua and lua/mivn/lsp/managed.lua, and every server
    that ships as a binary is managed now; the full design (manifest,
    store layout, lock, sweep, hook points) lives in those two files'
    comments and in this entry's git history. Still to do, roughly in
    order:
  - [ ] Ruby, decided 2026-08-03: build the ruby runtime after the other
      passes land. ruby-lsp (Shopify) is the server, a gem, so the store
      needs a portable ruby plus a `gem install` at install time, the way
      go will build gopls. Rails comes from the ruby-lsp-rails addon,
      which activates from the project's Gemfile on its own.
  - [ ] The node runtime as a store entry (one `bin/node`), plus the
      node-only servers bundled to a single file with esbuild by the
      weekly workflow and published as sha-pinned release assets of
      mivn: yamlls and jsonls (SchemaStore.nvim returns with them),
      cssls, bashls. npm runs only in CI; the user downloads two files.
  - [ ] Go as a build-time runtime for gopls (`go install` at install
      time, entry named `servers/gopls/v<ver>@go<ver>`), since gopls
      publishes no binaries. gci comes along in the same pass: it
      publishes no binaries either, it is the second half of the Go
      format pipeline (gopls formats, gci re-groups the imports), and
      one Go dialog should cover both. The store grows a small "tools"
      notion for it: same staging, lock and sweep, but no client wiring;
      lsp.lua's gci run resolves through the store by absolute path.
  - [ ] Grow .github/scripts/repin (or a sibling) to bump the store's
      manifest pins the way it bumps plugin pins, in the same weekly PR.
      The 2026-08-04 review sharpened this into the store's single
      highest-leverage change: move the manifest out of store.lua into a
      machine-owned JSON next to nvim-pack-lock.json, have the weekly job
      bump versions and compute every platform's sha256, and have it run
      `M.install` for each server on the runner before opening the PR, so
      a dead URL or wrong hash is caught in CI and not at first file open
      on this machine. Until then the pins rot: ruff and ty release
      near-weekly and are already behind.
  - [ ] Steal from fresh: spawn backoff for a crash-looping server, and
      a stub log so "view log" always has something to open.

- [ ] Facts written twice, waiting to drift; found by the 2026-08-04
    review, parked for a monthly batch. find.lua's BUILTINS table
    hand-describes 21 Ex commands, and its prose-vs-code regex hides any
    real description that mentions a call like `foldexpr()`.
    local.example.lua's long header mirrors the behavior of store.lua and
    lsp.lua by hand. health.lua's PROBES table repeats what the manifest's
    `smoke` fields already know, keyed by binary name instead of server
    name. Each is fine today and wrong the day its twin changes.

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
