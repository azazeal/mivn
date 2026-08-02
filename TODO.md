# TODO

<!--toc:start-->
- [TODO](#todo)
  - [UI](#ui)
  - [Languages](#languages)
  - [Dashboard](#dashboard)
  - [Later](#later)
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

## Languages

- [ ] Verify `expert` attaches on a real Elixir project. It is installed but
    has not been exercised.
- [ ] Check whether treesitter indentation beats the built-in ftplugins for
    any of these. It is off right now on the assumption it does not.
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
- [ ] Managed language servers and runtimes: mivn installs the whole LSP
    stack itself, end to end, instead of expecting binaries on `PATH`.
    Opening a `.go` file with nothing installed asks once, through the
    floating `vim.ui.select` (Yes / No / Ask me later); Yes downloads gopls
    into the store and attaches. Nobody configures an LSP to get
    diagnostics. This replaces the earlier mason.nvim idea after reading
    mason's source: mason installs servers but no runtimes, resolves npm
    off the ambient `PATH`, and its servers run under `#!/usr/bin/env
    node`, i.e. whatever node the project's asdf pins, which is the exact
    problem. Homebrew only solves it by pulling whole toolchains in as
    dependencies (gopls drags go along). Design settled 2026-08-03, built
    on Zed's node_runtime (`~/projects/oss/zed`) and the gaps in mason and
    fresh (both checked out under `~/projects/oss/` too).

    **Manifest.** A pinned table in the repo, plugins.lua-style: a
    `runtimes` table (node, python, go; exact version and sha256 per
    platform) and a `servers` table (source: GitHub release asset or npm
    package; exact version; optional runtime; optional build-time
    runtime). One opinionated server per language. The weekly repin
    workflow grows a job that bumps these pins and opens the same kind of
    PR.

    **Store.** `stdpath("data")/runtimes/node@v24.11.0`;
    `servers/pylsp/v1.12.0@v3.13.7` (suffix = the runtime it was built
    against, so a runtime bump changes the resolved name and dependents
    rebuild); runtime-less binaries as `servers/rust-analyzer/v2026-07-28`;
    `servers/gopls/v0.20.0@go1.24.5`, because gopls publishes no binaries
    and the go runtime `go install`s it at install time, then never
    appears at spawn. Downloads are staged, sha256-verified, smoke-run
    with a version flag, then atomically renamed; the previous version
    survives until the new one passes.

    **Spawning.** Absolute paths only, never a shebang, never `PATH`: a
    node server runs as `<store node>/bin/node <store script> --stdio`.
    The server runs in the project and inherits the environment
    untouched, so its children (gopls shelling to `go list`) resolve
    against whatever asdf, mise or direnv say there, or nothing. mivn
    owns where the binary comes from; the project owns what it sees. npm
    installs go through the managed node with a private cache and blank
    npmrc files (Zed's flags), so no user npm config leaks in.

    **Overrides.** `lsp_servers` in local.lua stays the single knob, now
    tri-state: `false` is off, `true` is managed with consent pre-given
    (no dialog, and it overrules an old No), a string is the escape
    hatch, resolved in the user's own environment, runtime and all
    (`expert = false, elixirls = "elixir-ls"` swaps servers). Absent
    means managed plus the dialog; answers persist per machine in
    `stdpath("state")`. Precedence: local.lua, then dialog state, then
    manifest. Settings stay orthogonal and keep the current pipeline:
    shipped `vim.lsp.config` defaults, `lsp_settings` deep-merged over
    them (same later-wins-per-key semantics as `vim.lsp.config` itself,
    so every layer behaves alike; `vim.NIL` deletes a defaulted key;
    list values replace whole), then the project's trusted `.nvim.lua`.

    **Hooking in.** All of it rides the stock client; nothing is forked.
    Two verified hook points carry the whole design: repeated
    `vim.lsp.config(name, ...)` calls merge with lists replaced whole,
    so mivn swaps nvim-lspconfig's `PATH`-relative `cmd` for the store's
    absolute argv while keeping the filetypes, root markers and settings;
    and `vim.lsp.enable(name)` fires its FileType hook for already-open
    buffers too (`doautoall` in lsp.enable), so after a Yes the buffer
    that raised the dialog attaches without being reopened. The dialog
    itself is mivn's own FileType autocmd for covered-but-uninstalled
    servers; enable is only ever called with resolvable ones.

    **`:MivnLsp`** absorbs `:MivnServers`: every server with its state
    (managed at version / overridden / off / declined) and the actions to
    install, remove, reclaim, and reverse a No.

    **Concurrency.** Install, update and sweep passes take one coarse
    lock over the store: a lockfile created with `uv.fs_open(..., "wx")`
    (`O_CREAT|O_EXCL`, so acquisition is atomic), the owner's PID inside,
    and stale takeover when `uv.kill(pid, 0)` says the owner is gone.
    Mason's per-package lockfile is the cautionary version: it checks
    then writes (two processes can both pass the check) and a crashed
    install wedges the package until a manual `--force`. Under the lock
    sits a lock-free net anyway: entries are immutable versioned dirs
    built in unique staging dirs and renamed into place, so the worst
    concurrent outcome is finding the destination already present and
    calling it success. An instance that wants a server mid-install by
    another instance says so and waits its turn.

    **GC.** Stateless mark and sweep. The root set is what the manifest
    resolves, minus overrides and declines, plus every runtime something
    still references; nothing else needs receipts. Enablement is
    instant, reclamation is lazy: flipping `ts_ls` off stops it now and
    deletes nothing. A sweep runs after each successful install or
    update pass; garbage is first condemned (a marker file in the entry)
    and only deleted when a pass at least a week later finds it still
    condemned. The grace window makes on/off flip-flops free, lets a
    version bump age out instead of yanking, and keeps an instance still
    running yesterday's server in another terminal from having its
    binary swept mid-session.

    **Not plugins, but a seam.** Considered and settled: servers could
    ship as vim.pack plugins (a `mivn.ts_ls.nvim` carrying driver code
    and pins, with a `PackChanged` install/update hook building the
    artifact into its own dir, and delete cleaning it for free; the
    events exist and are documented for exactly this). Rejected as the
    architecture because vim.pack has no dependency graph, so the shared
    node runtime either gets duplicated per plugin or needs hand-ordered
    plugin dependencies with nothing tracking when the runtime falls out
    of use, and the store invariants (staging, checksums, lock, sweep)
    would drift across N repos the way Zed's adapters drifted. Kept from
    the idea: the engine exposes `register(spec)`, so a plugin can
    contribute server specs before enable; a spec plugin is ten lines
    and its artifacts still go through the one engine. Same split mason
    reached from the other side: one engine, specs as data.

    **Quality picks the server; shape only prices it.** The server for a
    language is chosen on quality alone, because some have no credible
    replacement (yamlls; the vscode json and css servers' completions).
    Only then does distribution shape matter, cheapest faithful form
    first. Best case, the best server is already one static binary:
    TypeScript 7 is tsgo, the compiler rewritten in Go with the LSP
    inside one binary (releases on microsoft/typescript-go;
    nvim-lspconfig already carries tsgo.lua), and superhtml covers HTML.
    Next, the node-only servers: npm never reaches the user. The weekly
    workflow bundles each with esbuild into a single server.js,
    smoke-tests it in the same job (bundlers choke on dynamic requires
    and plugin loading, so every bundle proves itself before shipping),
    and publishes it as a sha-pinned release asset of mivn. Spawning
    needs only `bin/node`, one file, so installing yamlls downloads two
    files: the shared node binary, once, and the bundle; the 120 MB,
    two-thousand-file node dist (npm, headers) exists only in CI. Last,
    the runtime tree, for servers that need the real thing: python has
    no production single-file build (the cosmopolitan APE pythons are
    experiments, PyOxidizer is abandoned, and a PyInstaller onefile
    self-extracts to temp and trips antivirus), so python is ty (astral,
    native) if its quality gets there, python-build-standalone with a
    venv per server if not. Runtime sharing stays free throughout: the
    sweep's root set keeps a runtime while anything references it.

    **Phases.** 1: the node runtime (the single `bin/node`) plus the
    bundled node servers, and SchemaStore.nvim returns with jsonls and
    yamlls. 2: go as a build-time runtime for gopls, plus the binary
    servers, tsgo among them, at which point the README's Homebrew
    requirement becomes the override path. 3: python, by whichever form
    wins above. Worth stealing from fresh along the way: spawn backoff
    for crash-looping servers, a stub log so "view log" always has
    something to open, and probing for a binary through the same
    resolution the spawn will use.

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

## Later

- [ ] Decide whether the config should be reachable over SSH, and how. The
    terminal UI already works over an SSH login; the config itself lives in
    this repo on this machine.

## Watching

Seen once, not reproduced, not forgotten:

- After a layout collapse in the tree, `:NvimTreeOpen` left a completely blank
  full-window `NvimTree_1` buffer, drawing no listing at all. Scripted repros
  recover cleanly from every state tried, so this probably needs the layout to
  be damaged in some way a script has not reached. If it happens again, capture
  `:ls!`, `:echo winlayout()` and `:messages` before restarting; those are the
  three things that would identify it.
