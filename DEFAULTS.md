# Neovim defaults

Vim's grammar as it ships, with nothing remapped. This is the surface to judge
before deciding what a config should add.

Two things to know before reading:

- This is curated, not complete. `:h index` is the complete list and is not
  useful to read. `:h default-mappings` covers what Neovim adds on top of Vim.
- Neovim changed a few Vim defaults. Those are marked _(nvim)_.

A few keys in here are this configuration's own rather than Vim's, marked
_(mivn)_ where they appear, and they are the whole list. `Ctrl+Tab` and
`Ctrl+Shift+Tab` step along the tab bar, which Vim leaves unbound;
[Buffers](#buffers) has the one way they can fail to arrive. `Up` and `Down`
move through the command line's completion menu while it is open, and
[The command line](#the-command-line) has what that costs and how to get it
back. `Enter`, `Tab` and `Ctrl+Space` take and open the Insert-mode completion
menu, which [Completion](#completion) covers. `PageUp` and `PageDown` reach the
first and last line when there is no screenful left to scroll, which
[Motions](#motions) covers.

Nearly everything here works in a bare `nvim -u NONE`. The three sections that
need this config say so where they start: the file tree, the picker, and
shift-selection.

## The one rule

Most of Normal mode is one pattern:

```
operator + target
```

`d` (delete) + `iw` (inner word) = `diw`. Learn three operators and a handful of
targets and you get their product, not their sum. That product is the reason
people stay.

Two shorthands on top of the rule:

- Doubling an operator applies it to the line: `dd`, `yy`, `cc`, `>>`.
- A count multiplies: `3dd` deletes three lines, `d2w` deletes two words.

## When you are lost

This comes second because it is the thing that actually stops people, ahead of
any part of the grammar: the suspicion that a key just put the editor in a state
you cannot name and cannot leave. The whole way out is short enough to fit here.

| Key | Gets you |
|---|---|
| `Esc` | Back to Normal mode, and a "Press ENTER" prompt dismissed unrun |
| `Ctrl+\` `Ctrl+N` | The same, from anywhere at all |
| `u` | The last change to the text undone |
| `Ctrl+O` | Back to where you were before the last jump |
| `:q` | The window you did not mean to open, closed |
| `Ctrl+W =` | The windows evened up after one got squashed |
| `gt` / `:tabclose` | Out of the second tab you are probably in |
| `:MivnDashboard` / `:NvimTreeOpen` | The banner and the tree back |

`Ctrl+\` `Ctrl+N` is the one to memorize even though `Esc` is easier, because it
is the one with no exceptions: it works from Terminal mode, where `Esc` belongs
to the shell, and from the middle of a half-typed operator. `Esc` covers the
other ninety percent, including the hit-enter prompt, which is worth knowing
precisely: it dismisses the message and runs nothing.

`gt` is in that list because a changed screen is more often a second tab than a
broken editor. A Vim tab is a whole layout of windows, so landing in one
replaces everything you were looking at at once, which reads as damage and is
not.

`u` steps back by *change*, not by keystroke, so it is coarser than it looks and
that is in your favour: a whole `ciw` and the word you typed into it come back
together. Insert mode's `Ctrl+W` and `Ctrl+U` are the exception worth expecting,
because Neovim breaks the undo block before each of them, so a word or a line
deleted mid-insert comes back on one `u` of its own instead of taking everything
you typed with it.

One key looks like it belongs in that table and makes things worse. `Ctrl+W o`
means "close every window except this one", so pressed from a window you did not
mean to be in, it closes the tree and the banner and leaves you with a single
blank buffer. It is a tidying key, not a rescue.

And the part that should be said plainly rather than implied: nothing you press
can lose work. Nothing reaches the disk until `:w`. `u` walks back every change
the file has seen while it was open, and `'undofile'` means it keeps walking
back through the changes from before you last closed it. The worst outcome of a
keyboard being sat on is a layout to put back.

The screen mivn opens on is an ordinary buffer, which is why the motions work on
it: `j`, `w` and `G` move a cursor over the banner that is deliberately not
drawn, and where it lands makes no difference to anything. There is nothing
there to edit, so the keys that would try (`i`, `a`, `x`, `dd` and the rest) say
so on the status line instead of failing.

### Chords your hands already have

Every one of these is a key some other editor taught you to press without
thinking. None of them is remapped here, so this is what they do instead, and
most of them are discovered by pressing one by accident.

| Chord | Here |
|---|---|
| `Ctrl+W` / `Ctrl+Shift+W` | The window-command prefix |
| `Ctrl+A` / `Ctrl+X` | Increment / decrement the number under the cursor |
| `Ctrl+Tab` / `Ctrl+Shift+Tab` | Next / previous buffer _(mivn)_ |
| `Ctrl+V` / `Ctrl+Q` | Visual block |
| `Ctrl+F` `Ctrl+B` `Ctrl+D` `Ctrl+U` | Scrolling, by a screen and by half one |
| `Ctrl+E` / `Ctrl+Y` | Scrolling, by one line |
| `Ctrl+P` / `Ctrl+N` | A line up / down; completion in Insert mode |
| `Ctrl+S` | Nothing in Normal mode; signature help in Insert and Select |
| `Ctrl+Z` | Suspend |
| `q` | Starts recording a macro into the next key you press |
| `Ctrl+W` / `Ctrl+U` in Insert | Delete the word / the line before the cursor |

Five of those earn a sentence more.

`Ctrl+W` is where a window you did not ask for comes from, and `Ctrl+Shift+W`
reaches it too, because the shift is simply discarded. `Ctrl+W n` opens an empty
split, `Ctrl+W _` and `Ctrl+W |` squash every other window to nothing, and
`Ctrl+W T` moves this window off into a new tab, which is the one that looks
worst. `:q` closes the extra window and `Ctrl+W =` fixes the sizes.

`Ctrl+Tab` is the one of these that means here roughly what it means everywhere
else, with the difference that the strip it steps along holds buffers rather
than Vim tabs. Plain `Tab` is a different key entirely and keeps Vim's meaning;
see [Buffers](#buffers) for why that distinction is load-bearing.

`Ctrl+A` and `Ctrl+X` are select-all and cut everywhere else and are an edit to
the file here, with nothing on screen announcing it. If a number changed under
you, that was this, and `u` puts it back.

`Ctrl+S` is a save everywhere else and does nothing at all here in Normal mode.
In Insert and Select it is signature help, which makes it the answer to "what is
this float that appeared while I was typing". Writing the file is `:w`.

`q` is the sharpest of them, because it is a letter rather than a chord and it
says nothing. It starts recording a macro into the register named by whatever
key you press next, and from then on every keystroke is kept until a second `q`
stops it. The status line shows `rec @x` while one is running, and that is the
only sign there is.

### How to answer this yourself

The point of this document is to stop being needed, and four things make it
unnecessary.

Hold any key you have started for about a quarter of a second and the editor
lists what can follow it. `Ctrl+W` brings up the window commands, `d` brings up
every motion and text object it accepts, and both lists are longer than the
panel, so `Ctrl+D` scrolls them. This is the one to reach for first, because it
needs no vocabulary at all.

`:verbose map <key>` says whether a key is mapped, to what, and by which file,
which is the only way to tell Vim's own grammar from something a plugin took.

`:h CTRL-W`, `:h i_CTRL-W`, `:h ctrl-a`: the manual is indexed by key, with the
mode as a prefix, so a key you do not recognize can be looked up as itself.

And `:lua =vim.fn.keytrans(vim.fn.getcharstr())`, then press a chord, prints
exactly what Neovim received. That is the tool for "does foot pass this
through", "does Neovide see it the same way" and "what does this key send on a
Greek layout", which are otherwise guesswork.

## Modes

| Key | Mode | Notes |
|---|---|---|
| `Esc` | Normal | Where you always return to |
| `i` / `a` | Insert | Before / after the cursor |
| `I` / `A` | Insert | First non-blank / end of line |
| `o` / `O` | Insert | Open a line below / above |
| `v` | Visual | Character-wise selection |
| `V` | Visual line | Whole lines |
| `Ctrl+V` | Visual block | Columns / rectangles |
| `gh` / `gH` | Select | Like Visual, but typing replaces the selection |
| `R` | Replace | Overwrites as you type |
| `:` | Command-line | Ex commands |
| `/` `?` | Command-line | Search forward / backward |

`gv` reselects whatever you had selected last. Select mode is the one to know
about here, because this config also puts it under Shift and the arrows: see
[Selecting with Shift](#selecting-with-shift).

## Arrows

Arrow keys are not a compromise here. They are bound by default, they are `h j
k l` in Normal mode, they work as operator targets (`d↓` deletes two lines, same
as `dj`), and they work in Insert mode. Nothing needs remapping to use them.

In Visual and Select mode there is one difference, and it comes from this config
rather than from Vim: an unshifted arrow **ends** the selection instead of
extending it, while `hjkl` still extends. That is the price of shift-selection
below, and it is the only place in this document where an arrow and its letter
part company.

`hjkl` exists so the hand never leaves the home row, which matters less than it
is made out to. Single-character movement is the least Vim-like way to get
around whatever key drives it. The habit worth building is reaching for `w`,
`f{char}`, `}`, `%` and text objects instead of holding a key down, and that is
the same habit either way.

One genuine catch, in Insert mode only: moving the cursor with an arrow closes
the current undo block. That means `u` will only undo back to the arrow press,
and `.` will only repeat the text typed after it. Press `Esc`, move, then `i`
again rather than arrowing around mid-insert. This applies to `hjkl` users too,
they just have no way to move in Insert mode without leaving it first.

### Selecting with Shift

Shift and an arrow selects, the way it does in every other editor. No mapping is
involved: `init.lua` sets `'keymodel'`, `'selectmode'` and `'selection'`, three
options Vim ships for exactly this, and the keys were bound already.
Shift+`←`/`→` extends by a character, Shift+`↑`/`↓` by a line,
Ctrl+Shift+`←`/`→` by a word, Shift+Home/End to either end of the line. Typing
replaces what is selected. A mouse drag selects the same way. `Esc` drops the
selection and leaves you in the mode it started from, Insert or Normal.

What you land in is **Select mode**, which is Vim's own (`:h select-mode`) and
not Visual. The two look identical and differ in exactly one thing: in Visual
mode the letters you type are commands, in Select mode they replace the
selection. The status line gives Select its own color so the two are never
confused, and `Ctrl+G` switches between them when the selection is the one you
wanted but the mode is not.

Copying a selection needs that switch, because `y` in Select mode replaces the
selection with the letter y. `Ctrl+O` borrows Visual mode for a single command,
so `Ctrl+O y` copies the selection and drops it; with the clipboard setting in
`init.lua` that copy is on the system clipboard. `Ctrl+G` is the same idea when
there is more than one command to run on it.

This is a bridge for the edit you make once, and the grammar is still the better
tool for the edit you are about to make five more times. Renaming a word by
Ctrl+Shift+`→` and typing `NEW` costs two undos, because the delete and the
typing are separate changes, and `.` cannot repeat it: it replays the typing
without the delete, so the next word comes out `NEWdelta` instead of replaced.
`ciw` then `NEW` is one undo and repeats properly, so `w.` handles the next
occurrence and the one after that.

The other cost is `'selection'`, which is `exclusive` here so that three presses
of Shift+`→` select three characters and not four. What that costs elsewhere is
one character off a character-wise Visual yank: on `amm`, `vlly` yanks `am`,
where Vim's default would give `amm`. Text objects, `ve`, `v$`, `V` and every
operator are unaffected, which is nearly everything a yank is built from in
practice.

## Motions

These are targets. Alone they move the cursor; after an operator they define
what it acts on.

### Within a line

| Key | Moves to |
|---|---|
| `h` `l` or `←` `→` | Left / right |
| `w` / `W` | Start of next word / WORD |
| `b` / `B` | Start of previous word / WORD |
| `e` / `E` | End of word / WORD |
| `0` | Column zero |
| `^` | First non-blank character |
| `$` | End of line |
| `f{char}` | Forward onto the next `{char}` |
| `F{char}` | Backward onto the previous `{char}` |
| `t{char}` | Forward to just before `{char}` |
| `T{char}` | Backward to just after `{char}` |
| `;` / `,` | Repeat the last `f`/`t` forward / backward |
| `%` | The matching bracket |

A *word* stops at punctuation; a *WORD* is whitespace-delimited. In
`foo.bar_baz`, `w` moves to `.` and `W` skips the whole thing.

One deviation to know before the table: long lines do not wrap here _(mivn)_.
Vim wraps by default; with the width markers saying when a line is too long,
a line is one screen row and runs off the right edge instead. `Space w` turns
wrapping back on for the window you are in, per window, so prose can wrap
beside code that does not; while it is on, lines break between words
(`'linebreak'`), and `gj` / `gk` walk the screen lines.

### Across the file

| Key | Moves to |
|---|---|
| `j` `k` or `↓` `↑` | Down / up |
| `gj` `gk` | Down / up by screen line, when text is wrapped |
| `Space w` | Wrap long lines in this window, off by default _(mivn)_ |
| `{` / `}` | Previous / next blank line (paragraph) |
| `(` / `)` | Previous / next sentence |
| `gg` / `G` | First / last line |
| `Ctrl+Home` / `Ctrl+End` | The same two, in the spelling every other editor uses |
| `{n}G` or `:{n}` | Line `{n}` |
| `H` `M` `L` | Top / middle / bottom of the visible screen |
| `Ctrl+D` / `Ctrl+U` | Half a screen down / up |
| `PageDown` / `PageUp` | A full screen down / up, or the last / first line _(mivn)_ |
| `Ctrl+F` / `Ctrl+B` | The same, in Vim's own spelling, without the last part |
| `zz` `zt` `zb` | Scroll so the cursor line is centered / top / bottom |

Where two spellings exist, they are genuinely equal and neither is more correct,
with the one exception noted just below. Use `PageUp`/`PageDown` if that is
where your hand goes. It matters here for one practical reason too: foot binds
`Ctrl+B` to its own link launcher, so that spelling never reaches Neovim in a
terminal, while the page keys always do.

`PageUp` and `PageDown` **scroll a screenful, and go to the first or last line
when there is no screenful left** _(mivn)_. The second half is this
configuration's, and it is the one place the page keys and `Ctrl+B` / `Ctrl+F`
part company. Vim's own pair only scrolls, so on a file that already fits on
screen `Ctrl+B` moves nothing at all, and `Ctrl+F` reaches the last line but
drags the view along with it until that line is alone at the top. Neither is
wrong as scrolling; both are useless as a way to reach the ends, which is what
the key means once the file is short. `Ctrl+Home` / `Ctrl+End` and `gg` / `G`
are still the direct way there, and unlike the page keys they always are.

### Reading the gutter

The line numbers are hybrid: the line you are on shows its real number, and
every other line shows how far it is from you.

```
  38 func run(ctx context.Context) error {
   3     cfg, err := load()
   2     if err != nil {
   1         return err
41         }
   1
   2     return serve(ctx, cfg)
   3 }
```

That number *is* the count to give a motion. The `return err` line reads `1`, so
`1k` goes there, and `d1k` deletes up to it. Seven lines down reads `7`, so `7j`
and `d7j`. You never count rows by eye; the gutter has already done it.

The absolute number is still there on the current line, which is what you need
when a compiler or a review comment names a line: read it, then `{n}G` to any
other.

## Operators

| Key | Does |
|---|---|
| `d` | Delete (into a register, so it is also cut) |
| `c` | Change: delete, then enter Insert |
| `y` | Yank (copy) |
| `>` / `<` | Indent / dedent |
| `=` | Re-indent |
| `gu` / `gU` | Lowercase / uppercase |
| `g~` | Toggle case |
| `gq` | Reflow to the text width |
| `!` | Filter through an external command |

Capital shortcuts for "to end of line": `D` = `d$`, `C` = `c$`, `Y` = `y$`
_(nvim; in Vim `Y` meant `yy`)_.

## Text objects

Only valid after an operator or inside Visual mode. `i` means *inner*
(contents); `a` means *around* (contents plus the delimiters, and for words the
trailing space).

| Object | Is |
|---|---|
| `iw` / `aw` | Word |
| `iW` / `aW` | WORD |
| `is` / `as` | Sentence |
| `ip` / `ap` | Paragraph |
| `i"` `i'` `` i` `` | Inside quotes |
| `i(` `i)` `ib` | Inside parentheses |
| `i{` `i}` `iB` | Inside braces |
| `i[` `i]` | Inside brackets |
| `i<` `i>` | Inside angle brackets |
| `it` / `at` | Inside / around an HTML or XML tag |

The cursor only has to be *somewhere inside* the object, not at its start. This
is most of the daily payoff:

| Type | To |
|---|---|
| `ciw` | Rename the word you are sitting on |
| `ci"` | Replace a string's contents, quotes kept |
| `di(` | Empty an argument list |
| `ya{` | Copy a whole block including its braces |
| `>ap` | Indent this paragraph |
| `=i{` | Re-indent this block |

## Single-key edits

| Key | Does |
|---|---|
| `x` / `X` | Delete the character under / before the cursor |
| `r{char}` | Replace one character, stay in Normal |
| `s` / `S` | Substitute a character / a whole line, then Insert |
| `~` | Toggle the case of one character |
| `J` / `gJ` | Join with the next line, with / without a space |
| `p` / `P` | Paste after / before the cursor |
| `u` / `Ctrl+R` | Undo / redo |
| `.` | Repeat the last change |
| `Ctrl+A` / `Ctrl+X` | Increment / decrement the number under the cursor |

`.` is the one to actually internalize. `ciw` a name, `Esc`, then `n.` `n.`
`n.` through every other occurrence. Almost every editing habit in Vim is built
on making the next `.` do the right thing.

## Search

| Key | Does |
|---|---|
| `/text` | Search forward |
| `?text` | Search backward |
| `n` / `N` | Next / previous match |
| `*` / `#` | Search for the word under the cursor, forward / backward |
| `:noh` | Clear the highlighting until the next search |
| `Ctrl+L` | The same, on a key, plus a redraw _(nvim)_ |
| `Esc` | The same, on the key the hand already presses _(mivn)_ |

`Ctrl+L` is still worth knowing even with `Esc` covering the everyday case: it
is `:noh`, a diff refresh and a screen redraw in one press, which also makes
it the answer to a screen some background program has scribbled on.

Replace is an Ex command with a range:

```vim
:s/old/new/         " first match on this line
:s/old/new/g        " every match on this line
:%s/old/new/g       " every match in the file
:%s/old/new/gc      " ...confirming each one
:'<,'>s/old/new/g   " ...in the visual selection ('<,'> is filled in for you)
```

## Insert mode

Insert mode is nearly unbound, which is why CUA keys fit here without a fight.
What is taken:

| Key | Does |
|---|---|
| `Ctrl+W` | Delete the word before the cursor |
| `Ctrl+U` | Delete to the start of the line |
| `Ctrl+R {reg}` | Insert a register's contents |
| `Ctrl+O` | Run one Normal-mode command, then come back |
| `Ctrl+N` / `Ctrl+P` | Complete from words in open buffers |
| `Ctrl+X Ctrl+F` | Complete a filename |
| `Ctrl+X Ctrl+O` | Omni-completion (the language server) |

One addition _(mivn)_: `Ctrl+Del` deletes the word after the cursor, the CUA
twin of the `Ctrl+W` in the table above.

One divergence _(mivn)_: brackets and quotes close themselves. `(` inserts
`()` with the cursor between them, typing the closing character walks over the
one already there, and Backspace inside an empty pair deletes both. That is
mini.pairs with its defaults, and `lua/mivn/pairs.lua` is the whole of it.

## Completion

The menu opens by itself as you type _(mivn)_, from Vim's own `'autocomplete'`
rather than a plugin. It merges what the language server knows with the words
already written in the open buffers, and the server's answers come first.

| Key | Does |
|---|---|
| `Down` / `Up` | Next / previous match, without writing it into the line |
| `Ctrl+N` / `Ctrl+P` | The same two, and Vim's own spelling of them |
| `Enter` | Take the highlighted match _(mivn)_ |
| `Tab` | Take the highlighted match, or the top one if none is _(mivn)_ |
| `Ctrl+Y` | Take it, and Vim's own spelling of that |
| `Ctrl+Space` | Open the menu here _(mivn)_ |
| `PageUp` / `PageDown` | A screenful of the menu once you are in it, else of the file _(mivn)_ |
| `Ctrl+E` | Close the menu and put back what you typed |
| `Esc` | Close the menu and leave Insert mode |

Nothing is highlighted until you press an arrow, and that is what keeps `Enter`
honest: while the menu is merely open it still breaks the line, which is what
you meant by it. Only once you have said which match you want does `Enter` take
one. `Tab` is the short way past that, since it takes the top match with no
arrow first, and the literal tab it costs is only ever lost mid-word, where a
tab was not what you wanted.

`PageUp` and `PageDown` follow the same rule as `Enter`, and for the same
reason. Vim hands them to the menu whenever the menu is open, which was fair
when the menu only appeared on request; now that it comes on its own, that would
mean the page keys stop moving through the file for as long as you are in Insert
mode, which is most of the time. So they move through the file until you have
stepped into the menu with an arrow, and through the menu after that. Pressing
one before you have stepped in also closes the menu, rather than leaving it
hanging over a view that has scrolled out from under it. [Motions](#motions) has
what they do to the file, which is not quite what Vim does either.

Inside the menu they stop rather than wrap. Vim's menu is a ring with "what you
typed" as one more entry on it, so a page past the end lands on nothing selected
instead of on the last match, and on a list shorter than a page that happens on
the second press. Arriving at nothing selected means the next `Enter` breaks the
line, which is not what a key for crossing a long list should leave you holding.

`Ctrl+Space` is mostly unnecessary, since the menu comes on its own. Where it
earns its place is the spot the automatic trigger has nothing to go on: a fresh
line, or just after a space, with no partial word yet. That is also the spot
where "what can go here" is the actual question.

## Registers

A register is a named clipboard. Prefix any yank, delete, or paste with
`"{name}`.

| Register | Holds |
|---|---|
| `""` | The last delete or yank (the default) |
| `"0` | The last yank only, never a delete |
| `"+` | The system clipboard |
| `"*` | The X/Wayland primary selection |
| `"a`-`"z` | Yours to use |
| `"_` | The black hole: delete without touching any register |

`"+yy` copies a line to the system clipboard. `"_dd` deletes a line without
clobbering what you just yanked. `:reg` lists them all.

The trap worth knowing: a plain `dd` overwrites `""`, so pasting after a delete
gives you the deleted text, not the thing you yanked earlier. `"0p` pastes the
last *yank* and sidesteps it.

This config changes which register the unprefixed keys use _(mivn)_. Stock Vim
gives them `""` and leaves the system clipboard to `"+`, so a copy meant for
another window has to be typed as `"+y`. Here 'clipboard' is `unnamedplus`,
which makes `""` and `"+` the same register: `y` copies out of the editor and
`p` pastes whatever any other window last copied, with no prefix either way.

That is worth having and it sharpens the trap above rather than removing it,
because `d`, `c` and `x` write to a register too. Each of them now replaces the
system clipboard, so a delete can throw away something you copied an hour ago
and in another application. The two registers just above are the whole answer:
`"_d` for a delete you do not want kept, `"0p` to paste the last yank past any
delete since.

## Marks and jumps

| Key | Does |
|---|---|
| `m{a-z}` | Set a mark here |
| `` `{a-z} `` | Jump to that mark |
| `` `` `` | Jump back to where you were before the last jump |
| `` `. `` | Jump to the last change |
| `Ctrl+O` / `Ctrl+I` | Go back / forward through the jump list |

`Ctrl+O` is the "back" button after a go-to-definition. `Ctrl+I` is forward, and
it is worth knowing that `Tab` is the same key: that is why nothing here maps
`Tab`, and why the tab bar's chords are `Ctrl+Tab` and not it.

## Windows, buffers, tabs

Three separate concepts, and Vim's names do not match a visual IDE's:

- A **buffer** is an open file. They live in one flat global list.
- A **window** is a viewport onto a buffer. This is a split pane.
- A **tab** is a *layout of windows*, not a file. A tab bar showing open files
  is a plugin idea, not a Vim one.

### Windows (`Ctrl+W` prefix)

| Key | Does |
|---|---|
| `Ctrl+W s` / `Ctrl+W v` | Split horizontally / vertically |
| `Ctrl+W h j k l` | Move focus left / down / up / right |
| `Ctrl+W w` | Cycle to the next window |
| `Ctrl+W q` | Close this window |
| `Ctrl+W o` | Close every other window |
| `Ctrl+W =` | Equalize sizes |
| `Ctrl+W H J K L` | Move this window to that edge |

If windows keep appearing that you did not ask for, this prefix is the reason,
and `Ctrl+Shift+W` reaches it as well: the shift is discarded on the way in.
`:q` closes the extra window and `Ctrl+W =` puts the sizes back. See
[When you are lost](#when-you-are-lost) for the rest of that family.

### Buffers

| Key | Does |
|---|---|
| `]b` / `[b` | Next / previous buffer _(nvim)_ |
| `]B` / `[B` | Last / first buffer _(nvim)_ |
| `Ctrl+Tab` | Next buffer, cycling at the end _(mivn)_ |
| `Ctrl+Shift+Tab` | Previous buffer, cycling at the start _(mivn)_ |
| `Ctrl+^` | Toggle between the last two buffers |
| `:e {file}` | Open a file |
| `:ls` | List buffers |
| `:b {name}` | Switch by name; partial matches work |
| `:bd` | Close a buffer |

`Ctrl+Tab` and `Ctrl+Shift+Tab` are the one pair of chords the tab bar adds, and
they are the meaning every other editor gives them. Nothing is displaced: Vim
leaves both unbound. Both wrap, so past the last buffer you land on the first,
which comes free from `:bnext` and `:bprevious` being all they are.

They need a surface that speaks the extended keyboard protocol, and that is
worth knowing rather than discovering. In the older encoding a terminal has no
way to say Ctrl and Tab together, so it sends a plain Tab, and Normal-mode Tab
is `Ctrl+I`, forward through the jumplist. That half of `Ctrl+O` is worth more
than a convenience key, so nothing here is mapped to Tab: only `<C-Tab>` and
`<C-S-Tab>` are, and on a surface that cannot send them the two chords do
nothing at all while Tab keeps its own job. Neovide and a kitty-protocol
terminal like foot send them and both directions work; measured, by feeding the
encodings in and watching which way the buffers moved. `]b` and `[b` are there
on every surface and do the same thing, which is the answer if you are somewhere
the chords do not arrive.

Nothing about them changes on a Greek layout. `'langmap'` translates letters,
and Tab is not one; the physical key sends Tab under every layout.

Note the two axes, which visual editors merge into one. `Ctrl+W h/j/k/l` moves
between **windows** (the panes on screen, including the file tree). `]b` / `[b`
moves between **buffers** (the open files, whichever pane you are in). The tab
bar along the top lists buffers, not windows.

### Tabs

| Key | Does |
|---|---|
| `:tabnew` | New tab |
| `gt` / `gT` | Next / previous tab |
| `{n}gt` | Tab `{n}` |

## The file tree

Not Neovim's: these come from nvim-tree, and like the picker's below they work
**only while the cursor is inside the tree window**. Outside
it every one of them means what the rest of this document says it means, so `H`
is still "top of the screen" in a file. `Ctrl+W h` and `Ctrl+W l` are how you
get in and out. `<leader>t` _(mivn)_ shows or hides the tree itself, without
moving focus.

The highlighted row is the selection, and no cursor is drawn in the tree on
purpose: a column position means nothing in a list of names, so `j` and `k` and
the arrows move the highlight and nothing else.

| Key | Does |
|---|---|
| `Enter` / `o` | Open the file, or expand the directory |
| `Tab` | Preview the file without leaving the tree |
| `Backspace` | Collapse the directory you are in |
| `P` | Jump to the parent directory |
| `E` / `W` | Expand / collapse everything |
| `=` / `→` | Expand the directory under the cursor _(mivn)_ |
| `-` / `←` | Collapse it; elsewhere, the one you are in _(mivn)_ |
| `J` / `K` | Last / first sibling |
| `R` | Refresh |
| `a` `d` `r` `x` `c` `p` | Create, delete, rename, cut, copy, paste |
| `q` | Close the tree |
| `g?` | The full list, in a window over the tree |

A right click on a row _(mivn)_ opens a menu with the file actions: new,
rename, delete, cut, copy, paste. The same actions the keys above cover, for
the hand already on the mouse.

The questions these actions ask (a name, a yes/no before a delete) open in a
one-line float _(mivn)_ instead of on the bottom bar. Enter answers, `Esc` or
`Ctrl+C` cancels unrun, and `Tab` completes a path where one is being typed.
Rename floats at the cursor with the stem preselected: typing replaces it,
an arrow drops the selection to edit the extension too.

Two of its defaults are removed _(mivn)_: `-` and `Ctrl+]` used to **re-root
the tree**, one to the parent directory and one to the directory under the
cursor. The tree is rooted at the project and stays there, so the two keys
that could walk it out are simply gone.

`:bd` typed inside the tree is caught _(mivn)_: the tree is a panel, not a
file, so instead of deleting the tree's buffer and collapsing the split, the
command answers with where to go instead. Every spelling of bdelete typed
alone is guarded, bang included; a count like `:2bd` names a real buffer and
runs normally.

### Showing and hiding

Three filters, each on its own key:

| Key | Toggles |
|---|---|
| `H` | Dotfiles |
| `I` | Files git ignores |
| `U` | `.git/` |

The starting state is **dotfiles shown, ignored files hidden**, which is what
you want almost always: a dotfile is usually project configuration worth seeing,
while an ignored directory is build output that is never worth scrolling past.
The two are separate on purpose, because `.envrc` and `node_modules/` are not
the same kind of hidden.

`.git/` is the one both rules miss. It is a dotfile, so showing dotfiles shows
it, and git does not ignore its own directory, so hiding ignored files does not
hide it either. It is named on its own and hidden, because it is machinery
rather than part of the project. `<leader>f` leaves it out for the same reason.

Both are view state, not settings. They last as long as the session and reset
on the next start, so flipping one to go and look at something cannot leave the
tree in a state you later have to explain to yourself.

## The picker

The other set of keys here that are not Neovim's. `<leader>f` (files),
`<leader>/` (search the project), `<leader>b` (buffers), `<leader>h` (help),
`<leader>d` (diagnostics) and `<leader>:` (commands) all open the same floating
window, from mini.pick, so this list is learned once and covers all six. You
type to narrow the list; these keys act on it.

Neovim's own "choose one of these" prompts come through the same window too,
sized to fit their list _(mivn)_: `gra` code actions are the one you will
meet first. `Esc` backs out of those without choosing, like any picker.

| Key | Does |
|---|---|
| `↑` / `↓` | Move up / down the list |
| `←` / `→` | The same two: every arrow walks the list _(mivn)_ |
| `Ctrl+P` / `Ctrl+N` | Up / down without leaving the home row |
| `PageUp` / `PageDown` | A page up / down the list _(mivn)_ |
| `Shift+←` / `Shift+→` | Move the caret inside what you have typed _(mivn)_ |
| `Enter` | Open the match |
| `Ctrl+S` / `Ctrl+V` / `Ctrl+T` | Open it in a split / vertical split / tab |
| `Tab` | Toggle the preview |
| `Shift+Tab` | Toggle the info view: the counts, and this list of keys |
| `Ctrl+X` | Mark the match |
| `Alt+Enter` | Send everything marked to the quickfix list and open it |
| `Ctrl+Space` | Refine: search again within the current matches |
| `Ctrl+U` | Delete from the caret back to the start of the query |
| `Esc` | Close |

One of those is the reason to read this rather than guess: marking with
`Ctrl+X` ends in a quickfix list, which is a real Vim structure rather than a
picker feature. `]q` and `[q` walk it afterwards, and it survives closing the
window.

## The terminal

`` <leader>` `` _(mivn)_ shows and hides a terminal panel along the bottom;
the shell survives hiding. What it opens is the built-in terminal, so
everything below applies to it.

`:terminal` opens a shell in a buffer, in the window you are in. It starts in
Terminal mode, where nearly every key goes to the shell instead of to Neovim,
which is what makes it a usable shell and also what makes the way out worth
writing down, because nothing on screen says it:

| Key | Does |
|---|---|
| `Ctrl+\` `Ctrl+N` | Back to Normal mode, shell still running |
| `i` / `a` | Back to typing at the shell |

Once you are in Normal mode the scrollback is an ordinary buffer, so `/`, `y`,
the motions and the marks all work on it. There is no second way out: `Esc`
belongs to the shell and to the programs running in it, which is why it cannot
be the one.

## The bracket family

Neovim binds `[` and `]` as "previous" and "next" over whatever the letter
names. Worth learning as one shape rather than six bindings.

| Key | Steps through |
|---|---|
| `]b` / `[b` | Buffers |
| `]B` / `[B` | Last / first buffer |
| `]d` / `[d` | Diagnostics in this file |
| `]q` / `[q` | The quickfix list |
| `]l` / `[l` | The location list |
| `]t` / `[t` | The tag stack |
| `]a` / `[a` | The argument list |
| `]<Space>` / `[<Space>` | Add a blank line below / above the cursor |
| `]h` / `[h` | Git hunks _(mivn: mini.diff's pair, same shape)_ |

## The command line

`:` opens it, and the menu of matches now opens with it: it appears as you type
and follows every keystroke _(mivn)_, from Vim's own `wildtrigger()` rather than
a plugin. Nothing is selected and nothing is inserted, so what is on the line
stays what you typed.

The keys, and the two of them that are this configuration's:

| Key | Does |
|---|---|
| `Tab` | Fill in as much as is unambiguous, then cycle the matches |
| `Shift+Tab` | Cycle the matches the other way |
| `Down` / `Up` | Next / previous match while the menu is open _(mivn)_ |
| `Ctrl+N` / `Ctrl+P` | The same two, and Vim's own spelling of them |
| `Left` / `Right` | Also previous / next match, once the menu is up |
| `PageUp` / `PageDown` | Page through a long menu |
| `Shift+Up` / `Shift+Down` | Older / newer command in the history, always |
| `Ctrl+E` | Close the menu and put back what you typed |
| `Enter` | Run it |
| `Esc` | Leave, in one press, menu or no menu |

`Enter` runs the selected match if you moved onto one, and what you typed if you
did not. That is the whole point of the menu opening with nothing selected: a
command you typed in full is never quietly replaced by whatever the completion
thought you meant, and the moment you press `Down` you have said which one you
want.

`Up` and `Down` are the trade, and it is worth knowing which half you gave up.
With no menu open they are still Vim's history keys, and they still recall only
the commands that start with what is already on the line. With the menu open,
the prefix search is what they cost. `Shift+Up` and `Shift+Down` are the way
back to the history from either state, and the difference to expect is that they
walk all of it rather than the entries matching your prefix, which is Vim's own
split between the two pairs and not something this configuration did. `Ctrl+E`
closes the menu, and after it `Up` is prefix search again.

Search (`/` and `?`) is deliberately not part of this: the same function covers
it, but a popup of words over the match `'incsearch'` is already showing you is
in the way rather than in help.

## Files and quitting

| Command | Does |
|---|---|
| `:w` | Write |
| `:q` | Quit this window |
| `:wq` or `:x` | Write and quit |
| `:q!` | Quit, discarding changes |
| `:wa` / `:qa` | Write all / quit all |
| `:qa!` | Quit everything, discarding everything |
| `:cq` | Quit with an error code, so the tool that launched the editor cancels |

`:cq` is the one to remember when something else is waiting on the editor: in a
`git commit` or `git rebase -i`, it is the difference between "run this" and
"abort", and it works the same on every machine.

`:restart` (and `ZR`, its Normal-mode spelling) restarts the editor in
place. One exception _(mivn)_: when the window runs on another machine (see
the README on remote windows), both refuse with an explanation instead,
because the restarted editor would come up on the wrong machine, the window
would die, and a headless editor would be left behind.

Two deviations _(mivn)_, one rule: `:bd` closes a buffer, the `:q` family
closes the session. Closing the last file with `:bd` normally leaves a blank
buffer behind; in a session started with no file arguments the dashboard shows
instead, and in a session started on a file the editor quits, the way Zed and
VS Code end their `--wait` when the last tab closes, so `git commit` finishes
on `:bd`. And `:q` or `:x` on the last file window quits even while the tree
is open, instead of Vim's answer of leaving you in the one window that cannot
show a file. Unsaved changes still block every one of these paths.

One key is not on that list and looks like it belongs there: `Ctrl+Z`, which is
`:suspend`. It stops Neovim and hands you back the shell that started it, a real
Unix feature rather than a mistake, but it only means something when there is a
shell to come back to. Neither way of starting the editor here leaves one.
Neovide reads a suspend as "minimize this window", so the editor disappears from
the screen and comes back off the taskbar: startling, nothing lost. The foot
fallback is the worse case, because `mivn` runs Neovim as foot's own command
with no shell around it, so a suspend there leaves the process stopped with
nothing to type `fg` into. Nothing is mapped away over this, since the key
belongs to the terminal and not to Neovim. It is written down so it is
recognizable if it happens.

## Language server

Neovim 0.11 binds these when a server attaches. No plugin involved.

| Key | Does |
|---|---|
| `K` | Hover documentation |
| `grn` | Rename symbol |
| `gra` | Code action |
| `grr` | Find references |
| `gri` | Go to implementation |
| `grt` | Go to type definition |
| `gO` | Document symbols |
| `Ctrl+S` (Insert) | Signature help |
| `]d` / `[d` | Next / previous diagnostic |
| `gd` | Go to definition _(mivn)_ |

Go-to-definition has no default binding, the one obvious gap in the stock
list, so mivn binds `gd` over the stock file-local declaration search when a
server attaches. `:h lsp-defaults` is the authority on the rest for your
exact version.

`grn` asks for the new name in a one-line float at the symbol _(mivn)_ rather
than on the bottom bar, prefilled and preselected: typing replaces the old
name, Enter applies the rename, `Esc` backs out with nothing changed.

`K` and the other floats Neovim opens are framed _(mivn)_, stock draws them
with no border and their text sits straight on top of the buffer. The picker
and the rename prompt always looked this way; this is the rest of them
matching.


Most servers install themselves _(mivn)_: for the languages the store covers
(Python, Rust, Lua, TypeScript, Markdown, TOML, HTML, Elixir and more; Go and
Ruby still pend their runtime passes), opening a file with no server
installed asks once, Yes / No / Ask me later, then downloads the pinned
binary and attaches it to the file that asked. The answer is remembered per
machine. `:MivnLsp` reviews and reverses all of it, and lists the few
servers still expected on `PATH` beside the managed ones.

## Folding

| Key | Does |
|---|---|
| `za` | Toggle this fold |
| `zo` / `zc` | Open / close this fold |
| `zR` / `zM` | Open / close every fold |

## Macros

| Key | Does |
|---|---|
| `q{a-z}` | Start recording into a register |
| `q` | Stop recording |
| `@{a-z}` | Play it back |
| `@@` | Play the last one again |
| `{n}@{a-z}` | Play it back `n` times |

A macro is a register holding keystrokes, which is why `"ap` pastes a recorded
macro as text and you can edit it by hand.

## What to ignore for now

Real, in the manual, and safe to skip:

- Ex ranges and `:g/pattern/command`. Powerful, rarely reached for early.
- Most registers. `"+` and `"0` cover almost everything.
- `:h` options, all several hundred of them.
- Command-line window (`q:`), `Ctrl+A` in Insert, digraphs, `'`-vs-backtick
  mark distinctions, `gi`, `zf`.

## The subset that matters first

If you only keep one section, keep this one. Roughly a week of use.

```
Modes      i a o  v V  Esc  :
Move       w b e  0 ^ $  gg G  { }  f{char}  %
Operators  d c y  >  (double for the line: dd cc yy >>)
Objects    iw  i"  i(  i{  ip     (and the "a" variants)
Edit       x  p P  u  Ctrl+R  .
Search     /  n N  *  :%s/old/new/g
Windows    Ctrl+W v   Ctrl+W h j k l
```

That is about twenty keys. Everything else in this document is reachable from
`:h` once these are automatic, and nothing here is a leader-key convention
someone else invented.

## On a Greek layout

Letters are handled. `init.lua` sets `'langmap'`, which translates each
Greek letter to the Latin one on its physical key, in Normal, Visual, Select
and Operator-pending mode only. Insert mode is untouched, so Greek prose still
types as Greek. `δ` is `d`, `ψις` is `ciw`.

One gap in the letters: `ς` and `σ` both uppercase to `Σ`, so `Σ` is given to
`S`, and Shift+W has no Greek twin.

Punctuation is deliberately not translated, because `xkb_layout gr` leaves most
of it exactly where US has it. `/` `?` `'` `"` `.` `,` `<` `>` `@` and the whole
number row are identical, so searching, marks and macro playback are unaffected.

Two keys do move, and one of them is a trap.

| Physical key | Greek sends | Which in Normal mode is |
|---|---|---|
| `q` | `;` | Repeat the last `f`/`t` |
| `Shift+Q` | `:` | The command line |
| `;` | `´` (dead key) | Nothing, and worse. See below |
| `Shift+;` | `¨` (dead key) | Nothing |

So `;` and `:` both still work. They have moved onto the `q` key. What is
actually lost is `q` and `Q` themselves, which means **macros cannot be recorded
on a Greek layout**. Replaying one still works, since `@` has not moved. Switch
to US to record.

The trap is the physical `;` key. In Greek it is `dead_acute`, which is how
`ά έ ή ί ό ύ ώ` are typed, so it cannot be given up without breaking Greek. A
dead key emits nothing by itself and instead holds onto the next keystroke to
compose with it. In Normal mode that means pressing it does not merely do
nothing, it eats the command you type next.

### Why the obvious fix does not work

Swapping these in `'langmap'` looks like the answer and is not. `'langmap'` is a
global character table with no idea which layout is currently active. It is safe
for letters only because Greek and Latin letters are disjoint sets: a US
keyboard never sends `ς`, so that entry can never fire at the wrong moment.
Punctuation is not disjoint. Both layouts send `;` and `:`, so mapping `;` to
`q` would rebind `;` on the US layout too. Vim's own Greek example at
`:h langmap` stops at letters for this exact reason, and parks `qq`, `QQ` and
`WW` there as no-ops.

That leaves the layout itself as the only lever, and a variant does exist.
`gr(nodeadkeys)` changes exactly one key: physical `;` becomes a real `;` and
`:`, matching US. It is the precise fix for reaching the command line where the
hand expects it.

The price is in its name. No dead keys means no `ά έ ή ί ό ύ ώ`, so Greek prose
stops working. For an everyday layout that is too expensive, and carrying it as
a third group (`xkb_layout us,gr,gr` with `xkb_variant ,,nodeadkeys`) buys
little, since that group still cannot produce `q`.

`q` and `Q` are unreachable under every Greek variant, not only this one. `q` is
not a Greek character, and its key is genuinely the Greek question mark. No
layout hands it back, and `'langmap'` cannot either.

So: Greek is the layout for prose, prose is Insert mode, and Insert mode is
untouched. Switch to US to edit. The `'langmap'` above is a safety net for when
you forget mid-flow, not a substitute for switching.

## Learning it

`:Tutor` is the place to start and it is already installed. Thirty minutes,
interactive, inside the editor, and it teaches exactly the subset above in the
order it is useful. It is slow-paced by design and can be left and resumed.

After that, the one worth paying for is _Practical Vim_ (Drew Neil). It is
organized as ~120 short tips rather than a course, so it reads in any order and
suits picking up one habit a week. It is the standard recommendation for
getting past "I can use it" to "it is faster than what I had".

Free alternatives if a browser suits better: [openvim](https://openvim.com) is
interactive and gentle, and
[Learn Vim](https://github.com/iggredible/Learn-Vim) is a well-organized free
book covering roughly the same ground as _Practical Vim_.

For drills once the basics are in, `vim-be-good` is a plugin that generates
exercises. Skip VimGolf: it optimizes for shortest keystrokes, which is a
different game from editing well.
