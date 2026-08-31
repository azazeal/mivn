# TODO

Ordered roughly by what blocks daily use. Done items are deleted, not
checked off; git remembers them.

## UI

- [ ] A key that arrives while a shifted arrow is still running goes first.
    `arrow()` in keymaps.lua clears 'keymodel', feeds the plain key with
    nvim_feedkeys' "x" and puts the option back. "x" runs everything already
    waiting, and what it feeds joins the end of that queue rather than the
    front, so the key I typed after the arrow is the one that runs first.
    Typed `abc`, Shift+`←`, Shift+`←`, `x` arriving together leaves `abcx`
    and not `ax`: the `x` replaced a selection that had not been opened yet.
    Measured 2026-08-31 through a socket, the same input path as typing, and
    it takes keys arriving in one piece: a paste, a key held down, or a
    terminal handing over a burst. Typed apart they are correct. Wrapping in
    pairs.lua steers around the same "x" by using :normal, which is the shape
    of the fix, except that 'keymodel' has to stay cleared for exactly the
    fed keys and no others, and every arrow mapping goes through here.

- [ ] `%S` leaves a stray space to its right in the status line's right-hand
    group. mini.statusline joins a group's non-empty strings with a space and
    cannot tell that `%S` renders as nothing while no command is pending, so
    the separator is drawn for a thing that is not there. Found while the
    filetype was briefly a glyph, which made a one-character orphan obvious;
    it is there with the name too, just harder to see. The fix is either a
    group of its own for `%S` or moving the filetype out of that group, and
    both change the padding either side, so measure before picking.

    Half of that is spent already. Reordering the right-hand side on
    2026-08-23 put the filetype in a group of its own, so the second lever is
    pulled and only the first is left to try. The shape of it is already in
    the file: the panel branch gives `%S` a group to itself, a few lines above
    the file branch that still shares one with the search count. Measuring it
    again is harder than it sounds: everything after `%=` is right aligned, so
    a stray space at the left edge of a group merges into the empty middle and
    a rendered line looks the same either way. Catching it needs something
    sitting hard against that edge, which is the state the glyph put it in.

- [ ] A fact written twice, waiting to drift; found by the 2026-08-04 review,
    parked for a monthly batch. find.lua's BUILTINS table hand-describes 21 Ex
    commands, and its prose-vs-code regex hides any real description that
    mentions a call like `foldexpr()`. It is fine today and wrong the day its
    twin changes.

- [ ] Test coverage in the gutter, the way Zed shows it for Go. Nothing live
    exists here: coverage comes from a `go test -coverprofile=...` run, and
    neither the language server nor mini.diff reads the profile. Two routes:
    nvim-coverage, which signs the lines but pulls in plenary.nvim, or an
    in-house parser, since the coverprofile format is one line per range
    (`file.go:12.2,15.9 3 1`) and extmarks do the rest. Decide in a monthly
    batch, not now.

## Languages

- [ ] Check whether tree-sitter indentation beats the built-in ftplugins for
    any of the languages in treesitter.lua's list. It is off right now on the
    assumption it does not, and that assumption is written beside the setting
    rather than measured. What would settle it is a file per candidate
    language, indented both ways and compared.

- [ ] `:MivnInstallGrammars` cannot repair a half-installed grammar. It skips
    a language whose parser is already there, so a broken query link is
    invisible: the parser loads, highlighting turns on, and every capture
    comes back empty, which reads as "the colorscheme forgot this language".
    That is what the move off lazy.nvim left behind in `~/.config/nvim`: 30
    languages whose `queries/<lang>` still pointed into the old `lazy/`
    directory, relinked by hand on 2026-08-03.

    Half of this is spent. `:checkhealth mivn` now walks the installed
    grammars and says how many have their queries, so a broken link is
    findable. What is left is the repair: the install still skips a language
    whose parser is there, so the check can name the problem and nothing
    fixes it.

- [ ] Markdown: decide what is left of the writing set. Formatting is done:
    `rumdl` with MD060 alone aligns the tables and gives a file with no table
    in it back byte for byte, which is why it is a linter with one rule turned
    on rather than a formatter. `mdformat` was the standing candidate and is
    out, measured: it aligned the table and also rewrote setext headings, list
    markers, numbering, nesting, code fences and escapes.

    Still missing. Preview and mermaid: nothing renders inside the terminal or
    Neovide; peek.nvim (deno) and markdown-preview.nvim (node) both preview in
    the browser with mermaid support, and both cost a runtime. In-buffer
    polish: render-markdown.nvim prettifies headings and tables in place but
    renders no diagrams. A monthly-batch decision, not a today one.

## Health

- [ ] `:checkhealth mivn` takes about 4.7 seconds now, up from the 3.4 it was
    at last time and the 1.4 it started from. The servers with no version flag
    are started for real and given half a second to prove they did not die on
    the spot, which is what caught jsonls and cssls shipping without the code
    behind their launchers. Four healthy ones hold that half second each, one
    after another. Starting them all before waiting on any would put the time
    back. Measured 2026-08-31 with every server on PATH; a machine missing
    them pays none of it, since only a server that is there is waited on.

- [ ] `:checkhealth mivn` should list plugin clones on disk that plugins.lua
    no longer mentions. vim.pack deletes nothing on its own, so a dropped
    plugin lingers under site/pack on every other machine, and each boot there
    "repairs" the lock to account for the orphan, which keeps
    nvim-pack-lock.json forever dirty in git. Measured 2026-08-04: a leftover
    SchemaStore.nvim did exactly that on another machine, and
    `:lua vim.pack.del({ "<name>" })` was the cleanup; the check should name
    the orphans and point at it.

## Testing

- [ ] Nothing watches the word keys. `.github/scripts/panels` exists because
    two bugs of one shape reached the banner; the motions are the next shape
    and they reached me the same way. The parser read bytes, so `café` broke
    at the `é` and `abcαβγ` broke at the Greek, and the fix for that then
    swallowed a whole line of Japanese in one press because every script was
    being called one kind. Both were found by hand, twice, after shipping.

    What would have caught them is a `.github/scripts/motions` asserting
    where the caret lands for `w`, `e`, `b`, `ge` and their capitals, plus
    the arrows, over a fixture with an ASCII line, a Greek one, an accented
    one, a Japanese one and an emoji cluster. The assertions already exist as
    a throwaway: 76 of them were written while fixing this and thrown away
    afterwards, which is the part worth not repeating.

    The gap is two keys wide now. The wrapping keys of 2026-08-31 could only
    be checked by driving a real editor over a socket: headless feedkeys
    queues keys in a different order than a terminal does, so it said yes to a
    broken version and no to a working one. Twelve assertions, thrown away the
    same way. Whatever `motions` turns out to be wants room for a Select-mode
    buffer beside the caret ones, and it has to drive a real one.

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

## Watching

Seen once, not reproduced, not forgotten:

- Neovide and `:restart`, from when ui2 was still a trial: one session hung on
  restart with
  no dashboard and the old buffers still loaded, and after closing the buffers
  by hand the statusline and the command line were gone. Note that 'cmdheight'
  is 0 now, so "the command line was gone" is what a healthy session looks
  like; the status line is the half that would still say something. Not
  reproduced since 2026-08-04: a scripted `:view` + `:restart` comes back
  clean in the TUI and
  in a fresh Neovide, and the server state after both is healthy, so whatever
  breaks lives in Neovide's reattach once a session has more history behind
  it. If it happens again, before recovering run `nvim --server <sock>
  --remote-expr` from outside and capture 'laststatus', 'cmdheight',
  `nvim_list_uis()` and the window list; those say which half is broken, the
  server or the window.

- The tree grew a second way to re-root on 2026-08-23: `sync_root_with_cwd`
  moves it on DirChanged, so `:cd` now takes it along. Nothing has gone wrong
  with it, and it is only worth writing down beside the entry below, which is
  the other time the tree ended up somewhere unexpected. If that one comes
  back, this is the new code path near it.

- After a layout collapse in the tree, `:NvimTreeOpen` left a completely blank
  full-window `NvimTree_1` buffer, drawing no listing at all. Scripted repros
  recover cleanly from every state tried, so this probably needs the layout to
  be damaged in some way a script has not reached. If it happens again, capture
  `:ls!`, `:echo winlayout()` and `:messages` before restarting; those are the
  three things that would identify it.
