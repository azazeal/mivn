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
precisely: it dismisses the message and runs nothing. _(mivn)_ runs ui2, so
that prompt should barely appear: a long message is cut short behind a `[+x]`
marker instead, and `g<` shows the whole thing; `q` or Esc closes that view.

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

Swap files, the other half of that, are kept as Vim ships them: one beside
every open file, holding what a crash would otherwise take. What is not kept
is the prompt about a swap file nothing is using any more _(mivn)_. An editor
that was killed rather than closed leaves one behind, and the next time you
open that file Vim stops to ask what to do about it, when the answer is
always "it held nothing, drop it". Those are cleared at startup, and only
those: a swap file with unsaved work in it, or one an editor is still using,
is left alone and still asks.

The screen mivn opens on is an ordinary buffer, which is why the motions work on
it: `j`, `w` and `G` move a cursor over the banner that is deliberately not
drawn, and where it lands makes no difference to anything. There is nothing
there to edit, so the keys that would try (`i`, `a`, `x`, `dd` and the rest) say
so on the status line instead of failing.

The byline under it says which release you are running _(mivn)_: `v0.2.1 by
@azazeal`, or `v0.2.1+7` when the checkout sits that many commits past the
release, which is the same way `plugins.lua` writes its pins. A checkout with
no release to name drops it and the byline reads as it always did.

One line can appear under that banner _(mivn)_, and only one: a newer mivn
release is out. The config directory is a git clone, so mivn asks GitHub once a
day whether a release tag exists that this checkout does not have, and says
nothing at all the rest of the time. `:MivnUpdate` takes it, moving onto that
release and not onto whatever the branch carries today: a fast-forward when the
checkout is on a branch, and a checkout of the tag when it is detached, which is
where a clone of a release sits. Either way it is refused outright if the
checkout has changes or commits of its own; `:restart` is what actually loads
the new files. `:checkhealth mivn` says the same thing when the banner is not on
screen.

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
| `Ctrl+=` / `Ctrl+-` / `Ctrl+0` | Zoom in / out / back to 100%, Neovide only _(mivn)_ |
| `Ctrl+numpad +` / `Ctrl+numpad -` / `Ctrl+numpad 0` | Zoom in / out / back to 100%, Neovide only _(mivn)_ |
| `Ctrl+↑` / `Ctrl+↓` | Move the line, or the selected lines _(mivn)_ |
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
| `Ctrl+G` in Visual | Select | Like Visual, but typing replaces the selection |
| `R` | Replace | Overwrites as you type |
| `Insert` | Insert / Normal | Whichever of the two you are not in _(mivn)_ |
| `:` | Command-line | Ex commands |
| `/` `?` | Command-line | Search forward / backward |

`gv` reselects whatever you had selected last. Select mode is the one to know
about here, because the floating prompt and the tree's `e` rename come up in
it, with the name preselected so typing replaces it, and because that is where
a shifted key pressed while typing lands: see
[Selecting with Shift](#selecting-with-shift).

`Insert` is Vim's own way into Insert mode from Normal, and here it is the way
back out too, so the one key covers both directions _(mivn)_. With something
selected, Visual or Select, it drops the selection and leaves you typing where
the caret is _(mivn)_, which is the end you were moving until `o` puts it on
the other one. Stock Vim spends it in Insert mode on toggling Replace, which
`R` reaches anyway.

## Arrows

Arrow keys are not a compromise here. They are bound by default, they are `h j
k l` in Normal mode, they work as operator targets (`d↓` deletes two lines, same
as `dj`), and they work in Insert mode. Nothing needs remapping to use them.

In Visual and Select mode there is one difference, and it comes from this config
rather than from Vim: an unshifted arrow **ends** the selection instead of
extending it, while `hjkl` still extends. That is the price of shift-selection
below, and it is the only place in this document where an arrow and its letter
part company.

A second difference, also this config's: an arrow crosses the line boundary
_(mivn)_. At the end of a line `→` carries on to the start of the next, and at
column zero `←` goes back to the end of the one above, in Normal, Visual and
Insert alike. Vim stops at the boundary instead, and says which keys may cross
in `'whichwrap'`. `h` and `l` are not among the ones let through here, so they
still stop where Vim stops them.

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

Shift and an arrow selects, the way it does in every other editor. Every one of
those keys is mapped by hand _(mivn)_, which is not where this started: Vim
ships `'keymodel'` with a "startsel" flag that opens a selection when a shifted
special key arrives, and that is what this used to lean on. It had to go. On
that path the selection began and the screen did not repaint until the next key
arrived, so the mode block still read `N`, nothing was highlighted, and the
cursor sat where it had been; the state was real, and a `d` right after would
delete the selection you could not see. `'keymodel'` keeps "stopsel" alone, so
an unshifted key still ends a selection. Shift+`←`/`→` extends by a
character, Shift+`↑`/`↓` by a line, Ctrl+Shift+`←`/`→` by a word and
Alt+Shift+`←`/`→` by a subword _(mivn)_,
Shift+Home/End to either end of the line, Ctrl+Shift+Home/End to either end of
the file _(mivn)_, Shift+PageUp/PageDown by a page, stopping at the first and
last line _(mivn)_. A mouse drag selects the same way. `Esc` drops the
selection, and `Insert` drops it and leaves you typing where the caret is
_(mivn)_.

What you land in is **Visual mode**, Vim's own, so a selection is only a
selection and the whole grammar applies to it: `y` copies, `d` and `x` cut, `c`
replaces, `>` indents, `o` puts the caret on the other end of it, and a motion
adjusts which text is picked out. That `y` reaches the system clipboard
_(mivn)_, so Ctrl+V in the browser gets what you just took; that `d`
deliberately does not, and `Alt+D` is the one that cuts to the clipboard.
[Registers](#registers) is the whole account.

`Tab` and `Shift+Tab` indent and dedent every line the selection touches, and
leave it picked out afterwards so the key can be held _(mivn)_. That is Zed's
pair, and it is the whole reason they are bound: `>` and `<` are untouched and
still Vim's operators, so they still indent once and end the selection the way
every operator does. Two things fall out of Vim rather than being added here: a
selection ending at the very start of a line leaves that line alone, which is
'selection' being exclusive, and the shift is a flat 'shiftwidth' rather than a
step to the next multiple of it, since 'shiftround' is off and an indent that
does not sit on the grid is usually deliberate alignment.

While a selection is up, every other copy of it in the window gets a quiet tint
_(mivn)_, the way Zed marks them. What counts as a copy is the selected
characters exactly, case and all, and word boundaries are ignored, so picking
out `for` also marks the middle of `before`. That is on purpose: half a word is
usually what you select when you want to see where else it is. One line at a
time, though, so a selection running over several lines marks nothing, and
neither does one made of spaces. Select mode counts the same as Visual, since
a shifted key pressed while you are typing lands there rather than in Visual,
and that is where most selections start. The tint is its own color, cyan, so
the copies never read as a second selection.

The cost is that a stray letter is a command and not text. `X` deletes the whole
line, `p` pastes over the selection, `u` lowercases it. Each of those is one `u`
away from being undone, and none of them is quiet enough to miss.

Pressed **while typing**, the same keys open **Select** instead _(mivn)_. You
are in the middle of a word, and what you do next to something picked out there
is type over it, which is the one thing Select is for: a letter replaces the
selection and you carry on typing, and `Del` or `Backspace` deletes it and
leaves you typing as well. So Ctrl+Shift+`→`, `Del`, and the replacement is one
run without a mode in the way. `Esc` drops the selection and leaves you typing
too, and `Insert` does the same while putting the cursor at the end you were
moving. Every shifted key reaches Insert: the arrows, `Home`, `End`, the Ctrl
and Alt word pairs, and the pages. Keys pressed from Normal are untouched and
still open Visual.

Six characters are not letters there _(mivn)_. `(`, `[`, `{`, `"`, `'` and a
backtick wrap the selection instead of replacing it, and what they wrapped
stays picked out, so `"` and then `(` over `word` gives `"(word)"`. That is
Zed's `use_auto_surround`, and Zed's rule about which characters it is: the
closing halves are not in it, so `)` over a selection still replaces. A wrap
comes off on its own `u` and the typing around it stays, except that dropping
the selection with `Esc` first spends one `u` on nothing. In Visual the same
keys keep Vim's meaning, where `"` names a register and `'` and a backtick are
mark motions.

Vim's other selection mode, **Select** (`:h select-mode`), is the one where
typing replaces the selection. `'selectmode'` would put the shifted keys and the
mouse there and is deliberately unset: the one habit it bought cost `y` and `d`,
which replaced the selection with a letter, and copying became `Ctrl+O y`. You
still meet Select mode where it does earn its keep, which is the paragraph
above, the floating prompt and the tree's `e` rename, the last two coming up
with the name preselected so typing replaces it. `Ctrl+G` switches between the
two, and the status line and the selection both give Select its own color so
they are never confused. That switch is also how you reach the keys Select
spends on text: `o` swaps the ends in Visual, and typed in Select it is a letter
that replaces the selection, so the way to the other end is `Ctrl+G`, `o`,
`Ctrl+G`. Vim's own `gh` and `gH` do not start it here: those are mini.diff's,
staging and resetting the hunk an operator covers.

This is still a bridge for the edit you make once. Replacing a word with
Ctrl+Shift+`→`, `c` and `NEW` is one change and one undo, but `.` repeats it
over the same *number of characters* rather than over the next word, so it goes
wrong as soon as the next word is a different length. `ciw` then `NEW` repeats
properly, and `w.` handles the occurrence after that.

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
| Ctrl+`→` / Ctrl+`←` | Past the end of the word / start of the previous one _(mivn)_ |
| Alt+`→` / Alt+`←` | The same, by subword _(mivn)_ |
| `e` / `E` | Past the end of the word / WORD _(mivn)_ |
| `ge` / `gE` | Past the end of the previous word / WORD _(mivn)_ |
| `0` | Column zero |
| `^` | First non-blank character |
| `$` | End of line |
| `{count}\|` | Column `{count}`, counted in characters _(mivn)_ |
| `f{char}` | Forward onto the next `{char}` |
| `F{char}` | Backward onto the previous `{char}` |
| `t{char}` | Forward to just before `{char}` |
| `T{char}` | Backward to just after `{char}` |
| `;` / `,` | Repeat the last `f`/`t` forward / backward |
| `%` | The matching bracket |

A *word* stops at punctuation; a *WORD* is whitespace-delimited. In
`foo.bar_baz`, `w` moves to `.` and `W` skips the whole thing.

Ctrl and an arrow is the word here, never the WORD _(mivn)_. Vim gives the
arrows both sizes, `w` on Shift and `W` on Ctrl, but Shift selects here
instead, and the WORD alone crosses a whole `foo::bar(baz(r, g, b))` in one
press, which is never the distance meant. `W`, `B` and `gE` are untouched and
still Vim's; nothing here is bound to them.

The two directions are deliberately not mirror images. Ctrl+`→` lands *past
the end* of the word and Ctrl+`←` on the *start* of the previous one, which is
Zed's shape and the one that makes travel stop at the far side of whatever it
crossed. Landing past the end rather than on the last letter is what makes a
selection work out: `'selection'` is exclusive, so the cursor marks a boundary
between characters rather than a character, and Ctrl+`→` followed by
Ctrl+Shift+`←` selects the word exactly. Measured on `foo bar`: stopping on
the `o` and selecting back gives `fo`, stopping past it gives `foo`.
`'virtualedit'` is `onemore` for the same reason, so the boundary after the
last word of a line exists at all.

It works after an operator too, where Vim's own inclusive `e` covers the same
text: `d`+Ctrl+`→` deletes the word and no more. An operator still reaches
that `e`, which is why the key is worth keeping in mind even though pressing
it alone now does something else.

Both pairs work **while typing** as well _(mivn)_, and they had to be bound
there rather than left alone: Vim's own Ctrl+`→` in Insert is the start of the
next word, so the key measured one distance in Normal mode and another one
letter later in Insert, and the Alt pair meant nothing there at all. In Visual
and Select they stay unbound, where an unshifted special key ends the selection
instead.

The cursor is a bar rather than a block _(mivn)_, and that is the same
decision seen from the other end. Neovim's cursor is a buffer position either
way and the shape changes nothing: every key that acts on "the character under
the cursor" acts on the one to the right of the bar. `x` deletes it, `i` opens
before it, an operator runs forward from it, a selection stops at it. Neovim
already draws Visual-with-exclusive-selection as a bar in its stock value, for
this reason; this is that reasoning carried into Normal mode. What it costs is
`r` and `~`, which act on the character to the right of the bar without
showing which one that is.

Leaving Insert leaves the caret where it was _(mivn)_. Vim steps it one place
left on the way out, since a block cursor has to sit on a character and there
is none past the last one; a bar sits between two, so the place you were
typing at and the place it stands after are one place. `Esc`, `Insert` and
anything else that ends an insert all land on the boundary you stopped
typing at.

The cursor also carries the mode's color _(mivn)_, the same hue the status
line's mode block shows: blue in Normal, green in Insert, magenta in Visual,
red in Replace, yellow on the command line, cyan for the rest. The mode block
is in the corner and the cursor is where you are already looking. The
selection is magenta for the same reason, so picking text out lights the
cursor, the selection and the mode block in one color. Select is orange the
same way, cursor and selection both, which is where a rename prompt's
preselection starts and where `Ctrl+G` from Visual lands. A terminal has to
support `OSC 12` for the cursor half; foot and kitty do.

`End` moves past the end of the line for the same reason _(mivn)_, in Normal
mode only; `$` is Vim's and stops on the last character. `Ctrl+End` follows it
to the end of the file _(mivn)_, where Vim's own stops on the last character
too. Neither can take a line break with it: the boundary after the last
character is still on that line, before the newline, so `v$`, Shift+End and the
rest yank the line's text and it takes one more press to cross.

`Home` alternates between the indent and column zero _(mivn)_, which is Zed's
`stop_at_indent` rule taken from its movement code rather than guessed, and
Shift+Home selects to wherever it would have gone. It is the same rule while
typing, where Vim's own Home is column zero and nothing else. Where you start
decides which comes first, and the third case is the one worth knowing:

| Cursor | `Home` | then |
|---|---|---|
| In the text | The indent | Column zero |
| On the indent | Column zero | The indent |
| Inside the indentation | Column zero | The indent |
| At column zero | The indent | Column zero |

So from the text it takes two presses to reach the real start of the line, and
from inside the indentation only one. Vim has the two halves as `^` and `0`
and no key that alternates between them.

`e`, `E`, `ge` and `gE` land past the last character too _(mivn)_, in Normal
and Visual. The end of a piece of text is one place here, and it is the
boundary after its last character, never the character itself. The reason is
the bar cursor: it is drawn at the left edge of the character it sits on, so
stopping *on* the last letter of a word draws the caret one place short of
where the word ends. Every other end-of-something key here is already a
boundary, and a macro recorded on a key that is not means something other than
what was pressed. A paste leaves the caret on that same boundary _(mivn)_, so
`p` ends where the pasted text ends rather than on its last character. `$` is
the one that stays Vim's, because it is an operator target before it is a
motion: `d$` and `y$` mean "including the last character", and that meaning is
the useful one.

`w`, `b` and their capitals are untouched, because they already stop at the
first character of a piece, which is the boundary a piece starts at. So the
grid Vim's four keys make, a direction and a side, is intact; only the side
that had the off-by-one moved.

What it costs is `ea`, which used to append at the end of a word and now
appends one character further on; plain `i` does that job instead. After an
operator nothing changed, so `de`, `ce`, `ye`, `dge` and the rest are still
Vim's inclusive motions and still cover the piece and no more.

Visual is bound for the same reason Normal is, even though `ve` and `vE` look
right without it. With exclusive selection Vim moves an inclusive motion one
further in Visual so the selection holds its last character, but only when the
caret is past the anchor; extend a selection leftwards and the compensation is
gone. One rule in both modes is the point.

Alt and an arrow does the same by **subword**, the piece of an identifier a
camel hump or an underscore marks off _(mivn)_. `parseHTTPUrl` is `parse`,
`HTTP` and `Url`; `foo_bar` is two; `::` is a piece of its own.

All three sizes are parsed in `lua/mivn/words.lua` rather than borrowed from
Vim's keys, because borrowing leaves a hole: `e` moves to the end of the
*next* word when the cursor already sits at the end of one, which in this
model is every time a word ends against the next. Measured on `foo (bar) baz`,
the borrowed version crossed `)` and `baz` in a single press, and `ge` skipped
the same way going back. The parsed one stops after every word, punctuation
included: `parseHTTPUrl`, `(`, `foo_bar`, `,`, `baz2Qux`, `)`.

The WORD is in that file for `E` and `gE` and reaches no arrow. Borrowing was
tried there too and `gE` plus a column right turned out to be a fixed point,
landing back where it started every time.

What all of them count is graphemes, not bytes _(mivn)_, and the kind of each
one is Vim's own answer rather than a guess. So `καλημέρα` is one word with
`«` as punctuation beside it, `naïve` does not break at the `ï`, `ΚαλήΜέρα`
humps under Alt and an arrow the way `FooBar` does, and `👩‍💻` is a single
thing the caret cannot land inside, whether it stands alone or sits in the
middle of `foo👩‍💻bar`.

Outside the cased letters the piece is one script, which is what makes these
keys work on a language written without spaces. `私は日本語を勉強しています`
is six stops, at every change between kanji and hiragana, and
`変数nameを設定する` is five. That is where Vim puts a boundary too, and
without a dictionary there is no better answer.

Neither is an operator-pending motion. After an operator the Ctrl pair falls
back to Vim's own `e` and `b`, which cover the same text, and the Alt pair has
no operator form at all: select with Alt+Shift and operate on that.

`{count}|` counts its column in characters of text _(mivn)_, not Vim's screen
cells: a tab is one character and an LSP inlay hint is nothing, so the column
a compiler prints in file:line:col is the column `40|` reaches, and the same
count the status line shows. `g|` keeps the screen-cell meaning.

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
| `Space t w` | Wrap long lines in this window, off by default _(mivn)_ |
| `{` / `}` | Previous / next blank line (paragraph) |
| `(` / `)` | Previous / next sentence |
| `gg` / `G` | First / last line |
| `Ctrl+Home` / `Ctrl+End` | The start of the file / past its last character _(mivn)_ |
| `{n}G` or `:{n}` | Line `{n}` |
| `H` `M` `L` | Top / middle / bottom of the visible screen |
| `Ctrl+D` / `Ctrl+U` | Half a screen down / up |
| `PageDown` / `PageUp` | A full screen down / up, or the last / first line _(mivn)_ |
| `Ctrl+F` / `Ctrl+B` | The same, in Vim's own spelling, without the last part |
| `zz` `zt` `zb` | Scroll so the cursor line is centered / top / bottom |

`Ctrl+Home` and `Ctrl+End` go to the file's own two ends, and they are not
`gg` and `G` in another spelling _(mivn)_. Vim's pair misses both ends by a
little: `Ctrl+End` stops on the last character rather than past it, and
`Ctrl+Home` is `gg`, which keeps the column you were in, since
`'startofline'` is off by default in Neovim. Neither shows itself on a file
you have only just opened. So these two go where their names say instead, to
column one of the first line and past the last character of the last one,
which is the rule `Home` and `End` already follow on a line. `gg` and `G` keep
Vim's meaning, the first non-blank or the column you were in, and Shift with
either of the Ctrl pair selects to that end.

Where two spellings exist, they are genuinely equal and neither is more
correct, apart from the two pairs called out here: `Ctrl+Home`/`Ctrl+End` just
above, and the page keys just below. Use `PageUp`/`PageDown` if that is where
your hand goes. It matters here for one practical reason too: foot binds
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

Signs sit to the *right* of the numbers, between them and the code _(mivn)_.
Stock Neovim puts them leftmost, where a git change bar is a thin vertical
line at the very edge of the window, parallel to whatever border the window
manager draws and a few pixels from it; two parallel lines read as one piece
of chrome. Beside the code the bar points at what it is about. Diagnostic
letters share the same column, so they move with it.

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

`gq` needs a width to reflow to, and stock Vim leaves `'textwidth'` at 0, where
it falls back to however wide the window happens to be. Markdown sets it to 80
here _(mivn)_, the first of the three width markers, so
`gqip` lays a paragraph out the way this repository's own prose is written.
Nothing wraps while you type: that is `'formatoptions'` `t`, deliberately
removed, since it breaks the line under the cursor and leaves the rest of the
paragraph ragged.

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
| `p` / `P` | Paste after / before the cursor: the system clipboard, with the caret left after the pasted text _(mivn)_ |
| `Alt+D` / `Alt+C` | Delete / change, and put it on the clipboard _(mivn)_ |
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

The same characters wrap a selection rather than replacing it _(mivn)_, which
is the Selecting with Shift section above. mini.pairs has no notion of that
half, so `lua/mivn/pairs.lua` carries it and takes the characters out of the
plugin's own table, which is why the two lists are the same list.

## Completion

The menu opens by itself as you type _(mivn)_, from Vim's own `'autocomplete'`
rather than a plugin. In a buffer with a language server the matches are the
server's alone; everywhere else they are the words already written in the open
buffers, so completion still works where no server runs. That split is Zed's
rule, adopted because Vim would otherwise list the same identifier twice, once
with the server's signature and once as a bare word scraped from a call site.

One filetype is short a source _(mivn)_. Vim's own sql completion answers by
asking a live database, through the `dbext` plugin, and without that plugin
every call prints an error and then sleeps two seconds, mid-keystroke. It is
dropped, so `Ctrl+X Ctrl+O` finds nothing in a sql buffer and the words in the
open buffers are what the menu offers. The thirteen `Ctrl+C` mappings the sql
filetype adds to Insert mode go with it, since each of them was a way into
that completion; `Ctrl+C` there leaves Insert, as it does everywhere else.

| Key | Does |
|---|---|
| `Down` / `Up` | Next / previous match, without writing it into the line |
| `Ctrl+N` / `Ctrl+P` | The same two, and Vim's own spelling of them |
| `Enter` | Take the highlighted match _(mivn)_ |
| `Tab` | Take the highlighted match, or the top one if none is _(mivn)_ |
| `Ctrl+Y` | Take it, and Vim's own spelling of that |
| `Ctrl+Space` | Open the menu here, top match highlighted _(mivn)_ |
| `PageUp` / `PageDown` | A screenful of the menu once you are in it, else of the file _(mivn)_ |
| `Ctrl+E` | Close the menu and put back what you typed |
| `Esc` | Close the menu and keep typing; again to leave Insert _(mivn)_ |

Nothing is highlighted until you press an arrow (or ask, with `Ctrl+Space`,
below), and that is what keeps `Enter` honest: while the menu is merely open it
still breaks the line, which is what you meant by it. Only once you have said
which match you want does `Enter` take one. `Tab` is the short way past that,
since it takes the top match with no arrow first, and the literal tab it costs
is only ever lost mid-word, where a tab was not what you wanted.

A match from a language server can arrive as a snippet, with its arguments left
as placeholders to fill in. `Tab` steps forward through them and `Shift+Tab`
back, which is Neovim's own pair on the same two keys the menu uses, so the
order matters: the menu answers first, then the placeholders, then the key does
what it does with neither in the way. Zed reads the same way round. With no
placeholder to go back to, `Shift+Tab` while typing takes one step of indent off
the line _(mivn)_, which is Vim's own `Ctrl+D` and the other half of Zed's pair.

`PageUp` and `PageDown` follow the same rule as `Enter`, and for the same
reason. Vim hands them to the menu whenever the menu is open, which was fair
when the menu only appeared on request; now that it comes on its own, that would
mean the page keys stop moving through the file for as long as you are in Insert
mode, which is most of the time. So they move through the file until you have
stepped into the menu, with an arrow or `Ctrl+Space`, and through it after
that. Pressing one before you have stepped in also closes the menu, rather than
leaving it hanging over a view that has scrolled out from under it.
[Motions](#motions) has what they do to the file, which is not quite what Vim
does either.

Inside the menu they stop rather than wrap. Vim's menu is a ring with "what you
typed" as one more entry on it, so a page past the end lands on nothing selected
instead of on the last match, and on a list shorter than a page that happens on
the second press. Arriving at nothing selected means the next `Enter` breaks the
line, which is not what a key for crossing a long list should leave you holding.

`Ctrl+Space` is mostly unnecessary, since the menu comes on its own. Where it
earns its place is the spot the automatic trigger has nothing to go on: a fresh
line, or just after a space, with no partial word yet. That is also the spot
where "what can go here" is the actual question.

A menu you asked for arrives stepped in, the way it does in VS Code and Zed:
the top match is highlighted, so `Enter` takes it, the arrows move from it,
and the page keys page the list. Asking is what says a match is wanted, and it
is the signal the automatic menu never has. Pressing `Ctrl+Space` while an
automatic menu is open steps into that one instead of opening anything, and
typing on does not undo the step: the highlight follows its match while the
list refilters, as it does after an arrow. A source that answers late (the
language server, usually) redraws the list under any highlight, an arrow's as
much as this key's; the highlight stays through that too, back on its match
wherever it moved, or on the top one when the match is gone.

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

The trap worth knowing in stock Vim: a plain `dd` overwrites `""`, so pasting
after a delete gives you the deleted text, not the thing you yanked earlier.
That one does not bite here, for the reason below.

This config changes which register the unprefixed **copy and paste** keys use,
and only those _(mivn)_. Stock Vim gives them `""` and leaves the system
clipboard to `"+`, so a copy meant for another window has to be typed as
`"+y`. Here `y`, `Y`, `p` and `P` name `"+` themselves: `y` copies out of the
editor and `p` pastes whatever any other window last copied, with no prefix
either way.

`d`, `c` and `x` are left alone, which is the point of doing it this way.
Vim's `'clipboard'` option can only make `""` *be* the clipboard, and then
every delete lands on it too, so a `d` throws away something copied an hour ago
in another application. Here a delete fills `""` and the numbered registers as
it always did, and the clipboard survives it.

| Key | Does _(mivn)_ |
|---|---|
| `Alt+D` | Delete **and** put it on the clipboard: the deliberate cut |
| `Alt+C` | The same for a change |
| `"1p` | Paste the last line-wise delete; `"2p` the one before it |
| `"-p` | Paste the last small delete (less than a line) |

Two edges worth knowing. A register you name always wins, `"ay` and `"1p`
included, because these are `<expr>` mappings that step aside the moment
`v:register` is set; the single exception is a literal `""p`, which cannot be
told apart from a bare `p` and so pastes the clipboard. And `"0` stays empty
here, since Vim only fills it for a yank that names no register: `p` is the
last yank now, so nothing was lost with it.

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
`Tab` in Normal mode, and why the tab bar's chords are `Ctrl+Tab` and not it.
Where the jumplist has no claim on the key, while typing and over a selection,
`Tab` does have jobs _(mivn)_.

## Windows, buffers, tabs

Three separate concepts, and Vim's names do not match a visual IDE's:

- A **buffer** is an open file. They live in one flat global list.
- A **window** is a viewport onto a buffer. This is a split pane.
- A **tab** is a *layout of windows*, not a file. A tab bar showing open files
  is a plugin idea, not a Vim one.

The window your desktop knows about is a fourth thing, and Vim mostly ignores
it. Its title here _(mivn)_ is `cli.rs · mivn`: the file, then the project
directory, with `[+]` after the name while there are unsaved changes. A buffer
with no file behind it, the banner or the tree, leaves the project on its own.
Stock Neovim writes no title at all, and Neovide, left to itself, writes the
file's full path, whose useful end is the end a taskbar cuts off. In a terminal
the same line names the tab.

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
| `:bdo` | Close every other buffer _(mivn)_ |
| `:bda` | Close them all _(mivn)_ |

`:bdo` and `:bda` are the two helix has and Vim does not, under names Vim
leaves free: its own shortest spellings are `bd` for bdelete and `bufd` for
bufdo, so neither of these completes to anything of Vim's. `:%bd` is the same
command as `:bda`. All three close the **files** and leave the panels standing,
which plain `:%bd` would not: its range walks every buffer number, so it used
to take the file tree down with them.

A buffer with unsaved changes is kept rather than closed, counted, and named in
the message; the bang takes those too. `:bdo` keeps the file you are looking
at, or the one you looked at last if you run it from the tree, since the tree
itself is not a file to keep.

`Ctrl+Tab` and `Ctrl+Shift+Tab` are the one pair of chords the tab bar adds, and
they are the meaning every other editor gives them. Nothing is displaced: Vim
leaves both unbound. Both wrap, so past the last buffer you land on the first,
which comes free from `:bnext` and `:bprevious` being all they are.

They work while typing and while something is selected, too, because the tab
bar belongs to the window rather than to the mode. The terminal panel is the
one place they do not reach: nearly every key in there belongs to the shell,
and stepping the tab bar would put a file in the panel's own split. `Ctrl+\`
`Ctrl+N` first, and then they work as everywhere else.

They need a surface that speaks the extended keyboard protocol, and that is
worth knowing rather than discovering. In the older encoding a terminal has no
way to say Ctrl and Tab together, so it sends a plain Tab, and Normal-mode Tab
is `Ctrl+I`, forward through the jumplist. That half of `Ctrl+O` is worth more
than a convenience key, so nothing here is mapped to Tab in Normal: only
`<C-Tab>` and `<C-S-Tab>` are, and on a surface that cannot send them the two
chords do nothing at all while Tab keeps its own job. Neovide and a
kitty-protocol terminal like foot send them and both directions work; measured,
by feeding the encodings in and watching which way the buffers moved. `]b` and
`[b` are there on every surface and do the same thing, which is the answer if
you are somewhere the chords do not arrive.

Shift+Tab is not in that boat. It is `\E[Z`, terminfo's `kcbt`, an old enough
sequence that every terminal sends it, which is why the selection keys and the
placeholder keys can be had where `Ctrl+Tab` cannot.

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
get in and out. `<leader>tt` _(mivn)_ shows or hides the tree itself, without
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
cursor. The tree is rooted at the working directory, so the two keys that
could walk it out from under you are simply gone.

`:cd` is the one thing that moves it _(mivn)_. The tree follows the working
directory, so telling the editor you are working somewhere else moves the tree
there too, and `:pwd`, the status line and the tree all agree afterwards.
Nothing else re-roots it: jumping to a definition that lands in the module
cache or the standard library opens the file and leaves the tree where it was,
because that is you following code rather than saying where you are working.

`:bd` typed inside the tree is caught _(mivn)_: the tree is a panel, not a
file, so instead of deleting the tree's buffer and collapsing the split, the
command answers with where to go instead. Every spelling of bdelete typed
alone is guarded, bang included; a count like `:2bd` names a real buffer and
runs normally.

### Showing and hiding

Three filters. The first two have a key inside the tree and a key outside it,
and both spellings do the same thing:

| Inside the tree | Anywhere | Toggles |
|---|---|---|
| `H` | `<leader>th` _(mivn)_ | Dotfiles |
| `I` | `<leader>ti` _(mivn)_ | Files the SCM ignores |
| `U` | | `.git/` |

The first two reach the finders as well _(mivn)_, not only the tree: `<leader>f`
and `<leader>/` list what the tree draws, because they are two views of one
directory and a file present in one and missing from the other is a worse lie
than either rule on its own. `U` is the tree's alone.

The starting state is **dotfiles shown, ignored files hidden**, which is what
you want almost always: a dotfile is usually project configuration worth seeing,
while an ignored directory is build output that is never worth scrolling past.
The two are separate on purpose, because `.envrc` and `node_modules/` are not
the same kind of hidden.

`.git/` is the one both rules miss. It is a dotfile, so showing dotfiles shows
it, and git does not ignore its own directory, so hiding ignored files does not
hide it either. It is named on its own and hidden, because it is machinery
rather than part of the project. The finders leave it out for the same reason,
whatever the other two are set to.

A directory whose contents are all filtered out would read as empty, so the
tree writes what it left out under it, counted by reason _(mivn)_: `(3
ignored)`, `(4 dotfiles)`, or both at once. Stock says `(7 hidden)` and leaves
you to guess which key brings them back. `.git/` is counted as `filtered`,
since it is the one thing hidden by neither rule.

All of it is view state, not settings. A flip lasts as long as the session and
belongs to that session alone, so a second window keeps the starting state and
the next start begins there again. Going to look at something cannot leave a
state you later have to explain to yourself.

## The picker

The other set of keys here that are not Neovim's. `<leader>f` (files),
`<leader>/` (search the project), `<leader>b` (buffers), `<leader>h` (help),
`<leader>:` (commands), `<leader>?` (every key there is, searchable) and the
two diagnostic lists on `<leader>ad` and `<leader>aD` all open the same
floating window, from mini.pick, so this list is learned once and covers all
of them. You type to narrow the list; these keys act on it.

`<leader>?` is the one to remember while learning: it lists every mapping this
editor has, Vim's own grammar and the plugins' included, each with its
description, and picking one runs it. `lua/mivn/keymaps.lua` is the same list
as a file, for the keys mivn itself takes.

Neovim's own "choose one of these" prompts come through the same window too,
sized to fit their list _(mivn)_: `<Space>aa` code actions are the one you will
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

`` <leader>t` `` _(mivn)_ shows and hides a terminal panel along the bottom;
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
| `Space t r` | The old text, inline, for every changed line _(mivn)_ |
| `Space t b` | Who wrote the line you are on, or stop showing it _(mivn)_ |

Who wrote the line under the cursor is **on from the start** _(mivn)_, and
`<leader>tb` is there to turn it off for the times it needs to be quiet. It is
a session state rather than a buffer one, so the key takes it off everywhere
at once. What it says is `panos · 3 months ago`, in the **status line**, on the
right-hand side just left of the row and column.

The cursor's line and no other, which is the shape Zed's `inline_blame` has
and the reason to prefer it. Annotating every line was tried here first and
reads badly: the same name comes back every few lines, a blank line belongs to
whichever commit added the section above it so its name lands out at column
zero beside nothing, and a file with unsaved work in it starts a fresh run
after every line you have touched. Zed keeps the whole-file view as a separate
thing in the gutter, with avatars and short hashes, rather than the same text
repeated down the right-hand side.

The status line rather than the end of the code line, which is Zed's other
location for the same text. It never sits on top of anything, never depends on
how long a line is, and is always in the same place, so the eye learns where
to look once. What it gives up is nearness to the line it describes, and that
is worth giving up when the line in question is the one the cursor is on.

The right-hand side is laid out by one rule, which is worth knowing because it
decides the order of everything there. It is built right to left, so when a
piece grows, whatever is to its *left* slides over and whatever is to its
right stays put. So the pieces that come and go as you type go first, where
there is empty middle to grow into and nothing to disturb, and the pieces you
read at a glance go last:

| | |
|---|---|
| `%S`, the command in progress | Appears and vanishes while you type |
| `F: 2/5`, the search count | There only while a search is live |
| `panos · 3 months ago` | Changes with the cursor |
| The filetype glyph | Steady |
| `28:1`, row and column | Steady |

Which renders as `2d  F: 2/5  panos · 3 months ago  󰢱 lua  28:1` with a count
half typed. Put the blame first instead and a half-typed command shoves it
sideways, which is what the order above exists to prevent.

The name is the part of the author's address before the `@`, not the full
name. git has no username of its own and this is the nearest thing it knows,
as well as much the shorter half of what it does know.

Lines with nothing committed behind them say nothing, and neither do blank
ones. The gutter already marks what you changed and `<leader>tr` already shows
what it was, so a line you are in the middle of writing simply goes quiet.
What gets blamed is the buffer and not the file on disk, so an unsaved change
is part of the question rather than something the answer disagrees with, and
typing asks git again once the text sits still.

Making room for it, the status line stopped repeating the file name _(mivn)_.
The tab bar carries the name of every open buffer already, so saying it twice
says nothing. What the bar cannot always carry is which of two files of the
same name this is: mini.tabline drops the bare name and starts prefixing
directories the moment two open buffers share one, adding only as much path as
it takes to tell them apart. So the full path appears in the status line then,
and only then. The modified and readonly flags stay either way, since the tab
bar shows neither.

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

`:restart` (and `ZR`, its Normal-mode spelling) restarts the editor in place
and brings the session with it: the windows, the open files, the folds and the
cursor all come back where they were. `:restart!` is the same restart without
any of that, and so is `:restart` with a `[command]` of its own, since there is
only one slot for one and mivn is already using it.

One deviation _(mivn)_: the tree and the terminal are closed before the session
is written and opened again after, rather than being saved in it. A session
names a window's buffer by file name and a panel has no file, so a saved tree
comes back as an ordinary empty buffer that can be typed in and written to
disk. The terminal is a fresh shell either way, since a shell does not outlive
the editor running it.

One exception _(mivn)_: when the window runs on another machine (see the README
on remote windows), every spelling refuses with an explanation instead, because
the restarted editor would come up on the wrong machine, the window would die,
and a headless editor would be left behind.

Two deviations _(mivn)_, one rule: `:bd` closes a buffer, the `:q` family
closes the session. Closing the last file with `:bd` normally leaves a blank
buffer behind; in a session started with no file arguments the dashboard shows
instead, and in a session started on a file the editor quits, the way Zed and
VS Code end their `--wait` when the last tab closes, so `git commit` finishes
on `:bd`. And `:q` or `:x` on the last file window quits even while the tree
is open, instead of Vim's answer of leaving you in the one window that cannot
show a file. Unsaved changes still block every one of these paths.

One more deviation _(mivn)_: opening a file Neovim cannot display, a PDF, an
image, audio, video, a font, first asks whether to hand it to the system's
own app for that format (what `gx` on a path does by hand). Yes opens it
there and no buffer is loaded; No reads it in raw, which is the stock
behavior for every file; Cancel, which is also what Escape answers, does
neither and leaves you on the file you were already looking at. Yes and Cancel
both leave nothing new to edit, so either one on a file opened as the only
argument ends the session, the same as closing that file would. Office files
(`.docx`, `.xlsx`, `.pptx`) are asked about too; `.epub` and the rest of the
zip family keep the built-in zip browsing instead.

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

Neovim binds `grn` `gra` `grr` `gri` `grt` `grx` `gO` and `K` when a server
attaches. mivn takes all eight off _(mivn)_ and puts the same requests on two
leader chains instead: `<Space>a` is what to ask the server to do to this
code, `<Space>g` is where to ask it to take you. One key per request, and a
prefix panel that lists what a language server can do rather than five letters
scattered through the g-commands.

| Key | Does |
|---|---|
| `<Space>aa` | Code action |
| `<Space>ar` | Rename symbol |
| `<Space>af` | Format this buffer |
| `<Space>aF` | Organize imports |
| `<Space>ai` | Hover documentation |
| `<Space>ax` | Run the code lens on this line |
| `<Space>ad` / `<Space>aD` | Diagnostics, this buffer / the workspace |
| `<Space>gd` / `<Space>gD` | Go to definition / declaration |
| `<Space>gi` | Go to implementation |
| `<Space>gt` | Go to type definition |
| `<Space>gr` | Find references |
| `<Space>gs` / `<Space>gS` | Symbols, this document / the workspace |
| `Ctrl+S` (Insert) | Signature help |
| `]d` / `[d` | Next / previous diagnostic |

The two Neovim keeps are the two with no twin. `:h lsp-defaults` is the
authority on what it would have bound for your exact version.

Dropping the stock eight hands two keys back to Vim: `gO` is the outline of a
help page or a man page again, `gd` its local declaration search, and `K` is
'keywordprg', which means `:help` in Vim files and `man` elsewhere.

`<Space>af` is the formatting half of a write, and the same code: the
language's own formatter where its file names one, and the single server
chosen to do it otherwise. `<Space>aF` is the imports half. Neither can drift
from what saving does, because saving calls them.

Two of these are quieter than they look. `<Space>gD` is answered by very few
servers, since declaration and definition are the same place in most
languages; C is the one where they are not. `<Space>aD` is the diagnostics
already known, not a request for more: gopls and golangci-lint push their
findings rather than answering a pull, so there is nothing to ask for.

`<Space>ar` asks for the new name in a one-line float at the symbol _(mivn)_
rather than on the bottom bar, prefilled and preselected: typing replaces the
old name, Enter applies the rename, `Esc` backs out with nothing changed.

`<Space>ax` runs the code lens on the cursor's line. Neovim leaves lenses off;
mivn asks for them wherever a server offers them _(mivn)_, and they draw in
dim italics above the line they belong to. What that amounts to, measured:
nothing on ordinary Go source, one "run test" above each test function, and
seven on a `go.mod` for tidy, vendor, govulncheck and the upgrades.
rust-analyzer adds a reference count per item and Run and Debug above each
test and above `main`.

Inlay hints are the other thing a server draws into a file: the type behind a
`:=`, the name of the parameter an argument is going into, the error a
statement drops on the floor. Neovim draws none of them until it is asked, and
mivn asks wherever a server offers them _(mivn)_. `<leader>tn` shows or hides
them for the buffer you are in _(mivn)_, and says which way it went.

Go is the one language that starts with them hidden _(mivn)_. gopls is asked
for all eight kinds and Go infers a type on nearly every line, so the eight
together end up on most of the file; `<leader>tn` is how you get them for the
one you are lost in. The answer belongs to that buffer and lasts as long as
the server stays attached, so a `:LspRestart` puts the language's default
back.

The hover float and the others Neovim opens are framed _(mivn)_, stock draws
them with no border and their text sits straight on top of the buffer. The
picker and the rename prompt always looked this way; this is the rest of them
matching.

`<Space>ai` twice puts the cursor inside the float, and from there it is an
ordinary window: `PageUp` and `PageDown`, `Ctrl+D` and `Ctrl+U`, `j` and `k` all
move in it. `Esc` closes it _(mivn)_, as does Neovim's own `q`. Left alone, the
float goes away by itself the moment the cursor moves in the buffer under it.
Signature help and the diagnostic float take the same two keys.

The markup stays hidden under the cursor while reading _(mivn)_. Stock shows
the line the cursor is on as raw text, so stepping into a float landed on
the ` ```rust ` that opens the signature and showed it. Select the line in
Visual mode and the markup comes back, which is the point when the reason to
be on it is to copy it.

Hover on Rust hides the link addresses _(mivn)_. Doc comments there link
with rustdoc's `[`Type`]` shorthand and rust-analyzer turns each one into a
full docs.rs URL. Neovim hides the URL but still counts it when sizing the
window, so a paragraph with two links came out a hundred columns wide and
broke its sentences in the middle. The link text stays; only the address is
gone, so following one means searching docs.rs by hand.

Servers come from `PATH` _(mivn)_, never from this config: it looks each one
up and starts it if it is there. A language whose server is not installed
keeps its tree-sitter colors and gets nothing else, which `:checkhealth mivn`
names, along with the version of every server found.

Servers wait for the workspace to be trusted _(mivn)_. A language server is
not a viewer: rust-analyzer builds the crate, build scripts and proc macros
included, expert compiles `mix.exs`, and gopls drives the Go toolchain. So
opening somebody else's checkout runs their code, and until the workspace is
trusted no server starts and nothing formats on save. Everything else works as
always, and a file no server covers, a `.txt` among them, opens in silence:
nothing was going to run for it, so nothing is said about it.

The workspace is the directory the editor is working in, the one `:pwd` names
and `:cd` moves, and it is the whole of the question. Not the root a language
server picks for itself, which is a different thing chosen out of whatever
markers that server likes, and which lands above the checkout as readily as
inside it. So everything under the workspace is covered by one answer, and a
file reached from outside it, a dependency's source or the standard library,
is carried by that same answer rather than asked about again.

The first time a file turns up that a server would have started for, one line
says nothing is running and names the way in. `:MivnTrust` is that way, taking
`allow`, `deny`, `forget` and `status`, and it acts on the workspace unless
given another directory. Trusting starts the servers there and then, without a
restart; denying, or moving to an untrusted workspace, stops the ones already
running. Answers are kept in Neovim's own trust list, the one `:trust` writes
for `.nvim.lua`, and the nearest answer above a directory wins, so trusting a
checkout covers everything in it.

Nothing is trusted ahead of time _(mivn)_. There is no list of directories the
question is skipped for, because such a list is one clone landing in the wrong
place away from running code nobody looked at, and being asked is cheap: once
per checkout, and it is also what keeps you aware the gate is there.

Cheap because it is not a prompt, and not for every file. Nothing blocks and
nothing waits for an answer. One line appears the first time you open a file
in an untrusted workspace that a language server would have started for, and
that is the whole of it. A `.txt` in the same directory says nothing, since
nothing was going to run for it either way, and the line comes once per
workspace per session rather than once per file.

Writing a file formats it _(mivn)_. Vim writes the buffer as it stands; here
the language server is asked to organize the imports and then to format, and
a language that names a formatter of its own runs that instead of the
server's, since a server having a formatter does not make it the right one.
Those are `stylua`, `shfmt`, `jq`, `taplo`, `yamlfmt`, `dockerfmt`, `xmllint`
and `rumdl` today. JSON that is allowed to carry comments is read as `jsonc`
and goes to the language server instead, since `jq` cannot parse one _(mivn)_:
that is `.jsonc` itself, `tsconfig.json` and the `rc` files Neovim already
names, plus a project's own `.vscode` files, `devcontainer.json`,
`pyrightconfig.json`, `.stylelintrc`, `.swcrc`, `.eslintrc.json` and
`deno.json`, which it does not. Markdown is the one that reads the project:
`rumdl` aligns the tables and leaves the rest of the file as it was typed,
unless the project the file sits in carries a `rumdl` or `markdownlint` config,
and then that config decides what saving does. Go takes a second pass after the
write, where `gci` re-splits the imports into blocks: the standard library,
everything else, then one block per prefix in `$GOIMPORTPREFIXES`, then this
module's own packages. `$GOIMPORTNOGCI` turns that pass off and leaves the
imports as the language server grouped them, which is what to do when the `gci`
on `PATH` is an older release than the standard library in use and reads one of
its packages as third party. It is read as a yes or a no, so `0`, `no`, `off`
and `false` leave the pass on and the variable can be flipped rather than unset. A formatter that is not installed
is skipped and the file is written as typed; one that refuses says so and
changes nothing.

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
