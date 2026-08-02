# TODO

<!--toc:start-->
- [TODO](#todo)
  - [Plugins](#plugins)
  - [UI](#ui)
  - [Languages](#languages)
  - [Dashboard](#dashboard)
  - [Later](#later)
  - [Watching](#watching)
<!--toc:end-->

Ordered roughly by what blocks daily use. Done items are deleted, not
checked off; git remembers them.

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

## UI

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

- [ ] `rust-analyzer` is enabled and **not actually installed**. What is on
      PATH is rustup's shim, and the component behind it is missing, so
      running it recurses until rustup gives up with "infinite recursion
      detected". `rustup component add rust-analyzer` is the fix.
      The reason this went unnoticed is worth more than the fix: the check in
      `lsp.lua` is `vim.fn.executable()`, and a rustup shim is an executable
      whatever is behind it. So the server was enabled, failed to start, and
      `:MivnServers` reported it `on`. Every rustup tool can do this. Decide
      whether the check should run the binary rather than just find it, at the
      cost of a subprocess per server at startup.
- [ ] The servers still missing are the npm ones: `bashls`, `jsonls`, `cssls`,
      `html`, `ts_ls`, `dockerls`. Node is on asdf here with 24.16.0 installed
      but **no global version set**, so `npm i -g` has nowhere to go. Decide
      whether to `asdf set -u nodejs 24.16.0` or leave those languages to
      tree-sitter. JSON is the only one that stings, and `jq` already formats
      it; what is lost is schema validation from SchemaStore.
- [ ] `lemminx` (XML) and `jsonnet-language-server` are not in Homebrew.
      `xmllint` covers XML formatting in the meantime.
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
