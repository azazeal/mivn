# TODO

<!--toc:start-->
- [TODO](#todo)
  - [UI](#ui)
  - [Languages](#languages)
  - [Dashboard](#dashboard)
  - [Watching](#watching)
<!--toc:end-->

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
    markdown entry, so tables stay as typed; `deno fmt` (deno is already
    here as the TypeScript server) and `mdformat` (Python) are the
    candidates, `prettier` would drag node in. Preview and mermaid: nothing
    renders inside the
    terminal or Neovide; peek.nvim (deno) and markdown-preview.nvim (node)
    both preview in the browser with mermaid support. In-buffer polish:
    render-markdown.nvim prettifies headings and tables in place but renders
    no diagrams. A monthly-batch decision, not a today one.
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
