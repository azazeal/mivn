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
- [ ] Decide whether to offer editor-managed language servers, for people who
    would rather not install each binary by hand. The candidate design is a
    `local.lua` flag, off by default, that turns on mason.nvim plus
    mason-lspconfig and lets them install whatever server is missing. The
    default stays what it is: the binary has to be on `PATH`, which is what
    per-project toolchains through direnv already feed. Deciding this and
    wiring it is a monthly-batch item.

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
