-- Every key mivn takes, in one file.
--
-- A mapping that is on for the whole session lives here, whatever module owns
-- the behavior behind it: that module keeps the work and exports a function,
-- and this file decides which key runs it. One place to read, and `<Space>?`
-- is the same list from inside a running editor.
--
-- What is deliberately not here: a mapping that exists only while some buffer
-- does. It is made when that buffer is, and it belongs with the thing it acts
-- on. The hover float's Esc is lua/mivn/lsp.lua's, the message
-- pager's Esc is init.lua's, the tree's keys are lua/mivn/tree.lua's, the
-- dashboard's are lua/mivn/dashboard.lua's, the floating prompt's are
-- lua/mivn/prompt.lua's, and the picker's keys are mini.pick's own key loop
-- rather than mappings at all.
--
-- What is also not here: the CUA bridges Vim has an option for. Shift and an
-- arrow selecting, an arrow crossing the line boundary, the Greek layout, all
-- of them are 'keymodel', 'whichwrap' and 'langmap' in init.lua, and no
-- mapping is involved.

local blame = require("mivn.blame")
local complete = require("mivn.complete")
local filters = require("mivn.filters")
local find = require("mivn.find")
local format = require("mivn.format")
local margins = require("mivn.margins")
local page = require("mivn.page")
local restart = require("mivn.restart")
local terminal = require("mivn.terminal")
local tree = require("mivn.tree")
local words = require("mivn.words")
local zoom = require("mivn.zoom")

--- The clipboard --------------------------------------------------------------
--
-- Copy and paste reach the system clipboard. Delete and change do not.
--
-- 'clipboard' was `unnamedplus` here until 2026-08-16, which makes the unnamed
-- register and the clipboard one register. That is all it can do, and it takes
-- `d`, `c` and `x` with it, since those write to a register too: every delete
-- replaced whatever I had copied, sometimes an hour earlier and in another
-- application. Which keys reach the clipboard is not something the option can
-- express, so the option is gone and these carry it instead.
--
-- What that leaves is Vim's registers exactly as they ship. A delete still
-- fills `""` and the numbered ones, so nothing is lost to a cut: `"1p` pastes
-- the last line-wise delete, `"2p` the one before it, `"-p` the last small
-- one. What changes is only where an unprefixed `p` reads from.
--
-- Alt+d and Alt+c are the deliberate ones, the pair xileh uses in helix: cut
-- rather than delete, for when the clipboard is what I meant.
--
-- Every one of these is an <expr> mapping for one reason: a register I name
-- has to win. A plain `"+p` in the right-hand side names its register outright
-- and takes the one I typed with it, so `"1p` and `"ap` would both have pasted
-- the clipboard (measured 2026-08-16, which is how this stopped being a plain
-- mapping). `v:register` is the key I typed, or `"` when I typed none, so the
-- prefix is added only in that second case and every explicit register goes
-- through untouched.
--
-- The one thing that cannot be told apart is a literal `""p`, since v:register
-- reads `"` either way; that spelling reaches the clipboard like a bare `p`.
-- `"1p` and `"-p` are the ones that matter, and both work: the numbered
-- registers hold the last nine line-wise deletes and `"-` the last small one.
--
-- `"0` is a casualty and worth knowing about: Vim fills it on a yank that
-- names no register, and these always name `+`, so it stays empty here. It
-- also has nothing left to do, since `p` is the last yank by definition now.
local function clipboard(keys)
  return function()
    return (vim.v.register == '"' and '"+' or "") .. keys
  end
end

local function copy_paste(mode, lhs, keys, desc)
  vim.keymap.set(mode, lhs, clipboard(keys), { expr = true, desc = desc })
end

-- Normal's `Y` is Neovim's `y$` written out, because these are noremap: a bare
-- `Y` would reach Vim's own, which is `yy`, and quietly undo that default.
copy_paste({ "n", "x" }, "y", "y", "Copy to the clipboard")
copy_paste("n", "Y", "y$", "Copy to the end of the line, to the clipboard")
copy_paste("x", "Y", "Y", "Copy the selected lines to the clipboard")

copy_paste("n", "p", "p", "Paste the clipboard after the cursor")
copy_paste("n", "P", "P", "Paste the clipboard before the cursor")

-- Over a selection both keys are `P`, which puts without touching a register
-- (`:h v_P`). Plain `p` there would replace the selection *and* move the
-- replaced text into the clipboard, so pasting the same thing over two
-- selections in a row would paste something different the second time.
copy_paste("x", "p", "P", "Paste the clipboard over the selection")
copy_paste("x", "P", "P", "Paste the clipboard over the selection")

copy_paste({ "n", "x" }, "<A-d>", "d", "Delete, and put it on the clipboard")
copy_paste({ "n", "x" }, "<A-c>", "c", "Change, and put what was there on the clipboard")

--- Editing --------------------------------------------------------------------

-- Ctrl+Del deletes the word after the cursor: `dw` through i_CTRL-O, so it is
-- Vim's own motion doing the work. `<C-g>u` first breaks the undo block, the
-- same courtesy Neovim extends to Ctrl+W, so one `u` brings the word back
-- without taking the typing with it. Ctrl+W, the word *before* the cursor,
-- already ships with Vim.
--
-- An older terminal has no way to encode Ctrl+Del, so there the key stays a
-- plain Del; nothing to guard.
vim.keymap.set("i", "<C-Del>", "<C-g>u<C-o>dw", {
  desc = "Delete the word after the cursor",
})

-- Ctrl and a vertical arrow carries the line, or the selected lines, up or
-- down. The chord is the one I rebind to in every editor that lets me, and
-- xileh has it too, which is the whole reason it is not Ctrl+Shift here any
-- more. It is free: without a mapping Ctrl+Up scrolled by a line, which
-- Ctrl+E and Ctrl+Y already do.
--
-- Built on :move because `dd`/`p` would overwrite the unnamed register on
-- every press, and `p` is the clipboard now besides; :move touches no
-- register at all. The customary reindent (`==`, and mini.move's default) is
-- deliberately absent: it trusts the filetype's indent, and Rust's flattens a
-- `.method()` chain line to column zero. The move is exact and indentation
-- stays mine.
--
-- At the buffer's edges :move fails and `silent!` is what keeps that quiet;
-- the key becomes a no-op instead of an error. In Visual, `gv` reselects, so
-- holding the key walks the block through the file.
-- In Insert the completion menu is the land mine: while it is open the text
-- is locked (:move dies with E565, silently here), and the menu is open a
-- lot as I type. So the menu is dismissed first, and only then the line
-- moves.
local function insert_move(dst)
  return function()
    return (vim.fn.pumvisible() == 1 and "<C-e>" or "") .. "<Cmd>silent! move " .. dst .. "<CR>"
  end
end

-- `line` addresses the cursor's line, `lines` the selection, and they lean
-- opposite ways: up moves to before the line above '<, down to after the
-- line below '>.
for _, mv in ipairs({
  { lhs = "<C-Up>", line = ".-2", lines = "'<-2", word = "up" },
  { lhs = "<C-Down>", line = ".+1", lines = "'>+1", word = "down" },
}) do
  vim.keymap.set("n", mv.lhs, "<Cmd>silent! move " .. mv.line .. "<CR>", {
    desc = "Move the line " .. mv.word,
  })

  vim.keymap.set("x", mv.lhs, ":<C-u>silent! '<,'>move " .. mv.lines .. "<CR>gv", {
    silent = true,
    desc = "Move the selected lines " .. mv.word,
  })

  vim.keymap.set("i", mv.lhs, insert_move(mv.line), {
    expr = true,
    desc = "Move the line " .. mv.word,
  })
end

-- Esc clears leftover search highlighting, which Vim otherwise keeps lit until
-- :noh (Ctrl+L, a Neovim default, does the same plus a redraw). The real Esc
-- is sent on afterwards, so everything it already did still happens.
vim.keymap.set("n", "<Esc>", "<Cmd>nohlsearch<CR><Esc>", {
  desc = "Clear search highlighting",
})

--- Moving and selecting -------------------------------------------------------

-- Ctrl and a horizontal arrow moves by a word, and Alt by a piece of one.
-- Both stop at the far side of what they crossed: the end of the word going
-- right, the start of it going left. That is Zed's shape, and the asymmetry
-- is the point, since the far side of a word depends on which way you came at
-- it. lua/mivn/words.lua carries the argument and the subword.
--
-- Going right lands *after* the last letter rather than on it. 'selection' is
-- exclusive (init.lua), so the cursor is a boundary between characters, and
-- landing after the word is what makes a selection back to its start hold the
-- word and nothing else. Measured on "foo bar": stopping on the second "o"
-- and selecting back gives "fo", stopping past it gives "foo".
--
-- The WORD reaches no arrow. It crosses `foo::bar(baz(r, g, b))` in one
-- press, which is never the distance meant. `W`, `B` and `gE` are untouched
-- and still Vim's.
--
-- Normal and Insert, and not Visual or Select: there an unshifted special key
-- ends the selection ('keymodel' has "stopsel") and a mapping would keep it
-- alive instead. Insert is bound for the same reason the shifted keys are,
-- which is that Vim's own meaning for the key there is a different distance:
-- `<C-Right>` while typing is the start of the next word, so the key measured
-- one thing in Normal and another one letter later. Measured on
-- `foo parseHTTPUrl baz`, and the Alt pair meant nothing at all there.
--
-- The step is the same function in both, since it puts the cursor at a column
-- rather than running a motion, and the column it picks is a boundary either
-- way (lua/mivn/words.lua).
--
-- Operator-pending takes plain `e`, since an inclusive motion already covers
-- the same text: `d<C-Right>` is `de`, the word and no more.
for _, key in ipairs({
  { lhs = "<C-Right>", forward = true, size = "word", to = "past the end of the word" },
  { lhs = "<C-Left>", forward = false, size = "word", to = "to the start of the previous word" },
  { lhs = "<A-Right>", forward = true, size = "subword", to = "past the end of the subword" },
  { lhs = "<A-Left>", forward = false, size = "subword", to = "to the start of the previous subword" },
}) do
  -- Going right stops at an end and going left at a start, which is the one
  -- combination of the two axes the arrows want.
  vim.keymap.set({ "n", "i" }, key.lhs, words.move(key.forward, key.forward, key.size), {
    desc = "Move " .. key.to,
  })
end

-- After an operator the arrows fall back to Vim's own, which cover the same
-- text: `e` is inclusive, so `d<C-Right>` is the word and no more, and `b` is
-- what Ctrl+Left runs anyway. The Alt pair has no operator form; select with
-- Alt+Shift and operate on that.
vim.keymap.set("o", "<C-Right>", "e", {
  desc = "Through the end of the word",
})

vim.keymap.set("o", "<C-Left>", "b", {
  desc = "To the start of the previous word",
})

-- The four end keys land past the last character rather than on it. The end
-- of a piece is one place, and with a bar cursor drawn at the left edge of
-- the character it sits on, stopping on the last letter of a word puts the
-- caret one place short of where the word ends. A macro recorded there then
-- means something other than what I pressed it for, which is the whole
-- reason these moved.
--
-- All four run on words.lua rather than on Vim's keys plus a column, because
-- Vim's own skip: `e` moves to the end of the *next* word when the caret
-- already sits at the end of one, so on `foo (bar) baz` landing past `bar`
-- puts the caret on `)`, which has already ended, and the next press crosses
-- `)` and `baz` together. `ge` skips the same way going the other direction,
-- and `gE` plus a column right is a fixed point: it lands back where it
-- started every time. Measured, all three.
--
-- Visual as well as Normal. Vim moves an inclusive motion one further there
-- when the caret is past the anchor, so `vE` looks right, but only in that
-- direction: extend a selection leftwards and the compensation is gone. One
-- rule in both modes is the point.
--
-- Operator-pending is left alone, so `de`, `dE`, `dge` and `dgE` are Vim's
-- inclusive motions and cover the piece and no more. What this costs is `ea`,
-- which appended at the end of a word and now appends one character further
-- on; plain `i` is what does that job now.
--
-- `w`, `b` and their capitals are untouched. They stop at the first character
-- of a piece, which is already the boundary a piece starts at.
for _, key in ipairs({
  { lhs = "e", forward = true, size = "word", of = "word" },
  { lhs = "E", forward = true, size = "WORD", of = "WORD" },
  { lhs = "ge", forward = false, size = "word", of = "previous word" },
  { lhs = "gE", forward = false, size = "WORD", of = "previous WORD" },
}) do
  vim.keymap.set({ "n", "x" }, key.lhs, words.move(key.forward, true, key.size), {
    desc = "Move past the end of the " .. key.of,
  })
end

-- Home and End, on the same model and with Zed's rule for the indent.
--
-- Home goes to the first character that is not whitespace, which is where a
-- line actually starts, and to column zero from there: three presses walk
-- indent, zero, indent. Zed's own is `stop_at_indent`, and its rule is this
-- one exactly, taken from its movement code rather than guessed. Vim has both
-- halves as `^` and `0` and no key that alternates.
--
-- End takes the same `l` as `$`, in Normal only for the same reasons: after
-- an operator `d<End>` already covers the line, and in Visual exclusive
-- selection gives it the extra column. Zed has no indent notion at that end,
-- and neither does this.
--- Zed's three branches, in its own order (`indented_line_beginning` in
--- crates/editor/src/movement.rs): past the indent goes to the indent, and so
--- does column zero, while anything else, meaning the indent itself or a
--- column inside the whitespace, goes to column zero.
---
--- So from the text it is one press to the indent and a second to column
--- zero, and from inside the indentation it is one press to column zero. A
--- line that is all whitespace has no indent to go to.
local function home()
  local indent = vim.api.nvim_get_current_line():find("%S")
  if not indent then
    return "0"
  end

  local col = vim.fn.col(".")

  return (col > indent or col == 1) and "^" or "0"
end

vim.keymap.set({ "n", "x", "o" }, "<Home>", home, {
  expr = true,
  desc = "Move to the first character of the line, or to column zero",
})

-- The same rule while typing, where Vim's own Home is column zero and nothing
-- else. `<C-o>` runs the one Normal command and leaves the caret where it put
-- it. End needs none of this: Vim's own already goes past the last character
-- there, which is where this one goes too.
vim.keymap.set("i", "<Home>", function()
  return "<C-o>" .. home()
end, {
  expr = true,
  desc = "Move to the first character of the line, or to column zero",
})

vim.keymap.set("n", "<End>", "$l", {
  desc = "Move past the end of the line",
})

-- Ctrl with either goes to the file's own ends, and Vim's pair misses both.
--
-- Ctrl+End is not `G`: it lands *on* the last character rather than past it,
-- a column short of where End stops. Ctrl+Home is `gg`, and `gg` keeps the
-- column while 'startofline' is off, which is Neovim's default, so from the
-- middle of a line it goes to line one and stays in the column I happened to
-- be in. Neither shows on a file I have just opened, with the caret at the
-- top already, which is how both lasted this long.
--
-- Normal only, for the same reasons End is: after an operator Vim's own pair
-- already covers the text I would be asking for, and in Visual an unshifted
-- key ends the selection before any mapping of mine is reached ('keymodel'
-- has "stopsel").
vim.keymap.set("n", "<C-Home>", "gg0", {
  desc = "Move to the start of the file",
})

vim.keymap.set("n", "<C-End>", "G$l", {
  desc = "Move past the end of the file",
})

-- Shift and an arrow selects by a character or a line. Said here rather than
-- left to 'keymodel', which is the whole reason 'keymodel' no longer carries
-- "startsel" at all (init.lua).
--
-- What that path did wrong: the selection started and the screen did not
-- repaint until the next key arrived, so the mode block still read N, nothing
-- was highlighted, and the cursor sat where it had been. Every key that
-- behaved was one bound by hand, which is how it was found. Shift+End made it
-- obvious because it jumps far; the arrows hid it by moving one cell, where a
-- screen one keypress behind looks much like a screen that is up to date.
--
-- The motion is the *unshifted* key's, which is what "startsel" did too: it
-- spends the Shift on opening the selection and runs the key plain. So these
-- move by one character and one line, not by a word.
-- WARN: the arrow has to run with 'keymodel' out of the way. "stopsel" ends a
-- selection the moment an unshifted special key arrives and cannot tell one I
-- typed from one a mapping fed it, so `v<Right>` opened a selection and closed
-- it in the same breath, leaving the cursor moved and nothing selected.
-- Clearing the option for the length of one keystroke lets the arrow keep its
-- own meaning, wrapping across lines and all ('whichwrap' in init.lua), while
-- the selection survives.
local function arrow(keys)
  return function()
    local saved = vim.o.keymodel
    vim.o.keymodel = ""
    vim.api.nvim_feedkeys(vim.keycode(keys), "nx", false)
    vim.o.keymodel = saved
  end
end

-- The same keys pressed while typing, which is where they were missing: in
-- Insert the shifted arrows moved by a word and by a page, Vim's own meaning
-- for them there, and nothing was ever picked out.
--
-- Every one of them is the same two steps, so they are written the same way:
-- open a selection at the caret, then press the key again and let the Select
-- mapping beside it do the moving. That second press is why these are the one
-- group here that remaps its own right-hand side.
--
-- What it opens is Select and not Visual. I am in the middle of typing, and
-- what I do next to something picked out while typing is type over it, which
-- is the one thing Select is for. Keys pressed from Normal are untouched and
-- still open Visual, where `y` and `d` mean what they say; 'selectmode' stays
-- unset (init.lua).
--
-- The opening is a <Plug> of its own rather than the two keys written into
-- each mapping, because those two keys must *not* be remapped: `gh` in Normal
-- is mini.diff's staging operator (lua/mivn/diff.lua), which is what ran the
-- first time this was written the short way.
--
-- WARN: `<C-o>` is what keeps the caret. Leaving Insert any other way moves
-- the cursor one column left, whatever 'virtualedit' says, and putting it
-- back by hand does not work either: that move lands after the mapping has
-- returned, so it drags the open selection left with it. Measured. `<C-o>`
-- is Vim's own "one command from where I am", and where I am is exactly where
-- the selection has to start.
vim.keymap.set("i", "<Plug>(mivn-select)", "<C-o>gh", {
  desc = "Open a selection at the caret",
})

local function selecting(lhs)
  return "<Plug>(mivn-select)" .. lhs
end

for _, name in ipairs({ "Left", "Right", "Up", "Down" }) do
  local shifted = ("<S-%s>"):format(name)
  local plain = ("<%s>"):format(name)
  local what = name:lower()

  -- In Select the motion is borrowed through <C-o>, which runs it in Visual
  -- for the one key and comes back, since Select is where typing replaces.
  local extend = arrow("<C-o>" .. plain)

  vim.keymap.set("n", shifted, arrow("v" .. plain), {
    desc = "Select " .. what,
  })

  vim.keymap.set("x", shifted, arrow(plain), {
    desc = "Extend the selection " .. what,
  })

  vim.keymap.set("s", shifted, extend, {
    desc = "Extend the selection " .. what,
  })

  vim.keymap.set("i", shifted, selecting(shifted), {
    remap = true,
    desc = "Select " .. what,
  })
end

-- Shift with either is said outright rather than left to 'keymodel'.
--
-- Home needs it because 'keymodel' runs Vim's own meaning of the key, which
-- is column zero rather than the indent. End needs it for a worse reason: on
-- the keymodel path the selection starts and the screen does not repaint
-- until the next key arrives, so the mode block still reads N, nothing is
-- highlighted, and the cursor sits where it was. Measured against the keys
-- beside it, every one that behaves is one bound here by hand.
vim.keymap.set("n", "<S-End>", "v$", {
  desc = "Select to the end of the line",
})

vim.keymap.set("x", "<S-End>", "$", {
  desc = "Extend the selection to the end of the line",
})

vim.keymap.set("s", "<S-End>", "<C-o>$", {
  desc = "Extend the selection to the end of the line",
})

vim.keymap.set("n", "<S-Home>", function()
  return "v" .. home()
end, {
  expr = true,
  desc = "Select to the first character of the line",
})

vim.keymap.set("x", "<S-Home>", home, {
  expr = true,
  desc = "Extend the selection to the first character of the line",
})

vim.keymap.set("s", "<S-Home>", function()
  return "<C-o>" .. home()
end, {
  expr = true,
  desc = "Extend the selection to the first character of the line",
})

vim.keymap.set("i", "<S-End>", selecting("<S-End>"), {
  remap = true,
  desc = "Select to the end of the line",
})

vim.keymap.set("i", "<S-Home>", selecting("<S-Home>"), {
  remap = true,
  desc = "Select to the first character of the line",
})

-- The same two ends with Shift, and four mappings each the way the Ctrl and
-- Alt arrows below have them: Normal has no selection yet so it opens Visual,
-- Insert opens Select through the <Plug> above, and Visual and Select have
-- one already so they take the plain motion. `$` needs no `l` on this side,
-- since an exclusive selection gives it the extra column on its own.
--
-- WARN: both motions are two commands, and in Select each needs its own
-- `<C-o>`, which covers one command and no more. Written `<C-o>G$` the `G`
-- runs in Visual and the `$` arrives back in Select, where a printable key
-- types over what is picked out.
for _, sel in ipairs({
  { lhs = "<C-S-Home>", line = "gg", column = "0", to = "to the start of the file" },
  { lhs = "<C-S-End>", line = "G", column = "$", to = "past the end of the file" },
}) do
  local extend = sel.line .. sel.column

  vim.keymap.set("n", sel.lhs, "v" .. extend, {
    desc = "Select " .. sel.to,
  })

  vim.keymap.set("x", sel.lhs, extend, {
    desc = "Extend the selection " .. sel.to,
  })

  vim.keymap.set("s", sel.lhs, ("<C-o>%s<C-o>%s"):format(sel.line, sel.column), {
    desc = "Extend the selection " .. sel.to,
  })

  vim.keymap.set("i", sel.lhs, selecting(sel.lhs), {
    remap = true,
    desc = "Select " .. sel.to,
  })
end

-- Ctrl or Alt with Shift selects by the same step. 'keymodel' opens a
-- selection on its own and reaches for Vim's own meaning of the key, which is
-- the WORD, so the opening happens here instead.
--
-- Four mappings each, because the opening is what differs. From Normal there
-- is no selection yet, so this opens Visual the way a shifted arrow does
-- ('selectmode' is unset in init.lua), and from Insert it opens Select. In
-- Visual and Select, where there is one already, it is the plain motion.
-- After an operator the key is left alone: `d` and a shifted arrow is not
-- something I press.
for _, sel in ipairs({
  { lhs = "<C-S-Right>", forward = true, size = "word", to = "past the end of the word" },
  { lhs = "<C-S-Left>", forward = false, size = "word", to = "to the start of the previous word" },
  { lhs = "<A-S-Right>", forward = true, size = "subword", to = "past the end of the subword" },
  { lhs = "<A-S-Left>", forward = false, size = "subword", to = "to the start of the previous subword" },
}) do
  -- The one motion Visual and Select share, and what the Insert mapping
  -- reaches on its second press. It puts the cursor somewhere rather than
  -- typing anything, so Select needs no <C-o> around it.
  local extend = words.move(sel.forward, sel.forward, sel.size)

  vim.keymap.set("n", sel.lhs, words.select(sel.forward, sel.forward, sel.size), {
    desc = "Select " .. sel.to,
  })

  vim.keymap.set("x", sel.lhs, extend, {
    desc = "Extend the selection " .. sel.to,
  })

  vim.keymap.set("s", sel.lhs, extend, {
    desc = "Extend the selection " .. sel.to,
  })

  vim.keymap.set("i", sel.lhs, selecting(sel.lhs), {
    remap = true,
    desc = "Select " .. sel.to,
  })
end

-- Insert is the way out of typing and back into it.
--
-- Vim already opens Insert with it from Normal, and its other job, toggling
-- Replace, is one I have no use for: replacing something is deleting it and
-- writing over it, or picking it out and pressing `r`. So the key stops being
-- a Replace toggle and becomes the pair of the one Vim gave me, with `R`
-- still the way into Replace for the day I want it.
--
-- From a selection it drops it, leaves the text alone, and starts typing
-- where the caret already is, which is the end I was moving, or the other one
-- when `o` has sent it there. Visual and Select both, since the key means the
-- same in either: I have something picked out and what I want next is to
-- type. Vim gives Visual no meaning for it at all.
vim.keymap.set("i", "<Insert>", "<C-\\><C-N>", {
  desc = "Stop typing",
})

vim.keymap.set({ "x", "s" }, "<Insert>", "<C-\\><C-N>i", {
  desc = "Type on from where the caret is",
})

-- Normal, Visual and Insert. Select mode is left to Vim: there an unshifted key
-- ends the selection first ('keymodel' has "stopsel"), and taking the key would
-- take that with it. lua/mivn/page.lua is why these are not Vim's own pair.
vim.keymap.set({ "n", "x", "i" }, "<PageDown>", page.down, {
  desc = "A page down, or the last line when there is no page left",
})

vim.keymap.set({ "n", "x", "i" }, "<PageUp>", page.up, {
  desc = "A page up, or the first line when there is no page left",
})

-- Select as well as Visual, since lua/mivn/page.lua's pair only opens a
-- selection when it is in Normal and otherwise just moves, which is what
-- extends one either way. Insert then goes through the same <Plug> as the
-- other shifted keys: it used to be left out because 'keymodel' would open
-- the selection itself with the unclamped motion, and 'keymodel' no longer
-- has "startsel" to do that with.
vim.keymap.set({ "n", "x", "s" }, "<S-PageDown>", page.select_down, {
  desc = "Select a page down, to the last line when there is no page left",
})

vim.keymap.set({ "n", "x", "s" }, "<S-PageUp>", page.select_up, {
  desc = "Select a page up, to the first line when there is no page left",
})

vim.keymap.set("i", "<S-PageDown>", selecting("<S-PageDown>"), {
  remap = true,
  desc = "Select a page down, to the last line when there is no page left",
})

vim.keymap.set("i", "<S-PageUp>", selecting("<S-PageUp>"), {
  remap = true,
  desc = "Select a page up, to the first line when there is no page left",
})

-- `{count}|` goes to a column, and Vim counts that column in screen cells;
-- lua/mivn/margins.lua respells it as the character column, the number the
-- status line shows and a compiler prints. `g|` keeps the screen-cell meaning.
vim.keymap.set({ "n", "x", "o" }, "|", margins.to_char_column, {
  desc = "To the {count}'th character of the line",
})

-- The tab bar's two chords. `Ctrl+Tab` is unbound in stock Vim, and
-- `:bnext`/`:bprevious` wrap at both ends, which is what makes this a cycle
-- rather than two keys that stop at the edges.
--
-- The trap is what these must *not* be mapped to. In the legacy encoding a
-- terminal cannot say Ctrl+Tab and sends a plain Tab, and Normal-mode Tab is
-- `Ctrl+I`, forward through the jumplist; mapping Tab would quietly cost the
-- other half of `Ctrl+O`. So `<C-Tab>` and `<C-S-Tab>` only: they arrive as
-- themselves from Neovide and from a terminal speaking the extended keyboard
-- protocol, and on anything older they do nothing while Tab keeps its job.
-- Bound wherever I can be looking at a buffer, typing and selecting included,
-- because the tab bar is the window's and not the mode's; the zoom keys below
-- are the same argument. Terminal mode is the one left out, on purpose: in
-- there nearly every key belongs to the shell (lua/mivn/terminal.lua), and
-- `:bnext` would put a file in the panel's own split.
vim.keymap.set({ "n", "i", "x", "s" }, "<C-Tab>", "<Cmd>bnext<CR>", {
  desc = "Next buffer in the tab bar",
})

vim.keymap.set({ "n", "i", "x", "s" }, "<C-S-Tab>", "<Cmd>bprevious<CR>", {
  desc = "Previous buffer in the tab bar",
})

--- Completion, in Insert mode -------------------------------------------------
--
-- Up and Down are not bound and must not be: they already walk the menu the
-- useful way, moving the highlight without writing the match into the buffer.
-- Ctrl+E closes the menu and gives back what I typed. `:h popupmenu-keys`.
--
-- PageUp and PageDown are not here either. They belong to the file as much as
-- to the menu, and which one they move is decided above, in page.lua.

-- Enter takes the highlighted match, and is a newline the rest of the time.
-- The condition is the point: `noselect` means nothing is highlighted until I
-- press an arrow, so Enter while the menu is merely *open* still breaks the
-- line.
--
-- The newline path goes through mini.pairs, which returns raw termcodes,
-- hence `replace_keycodes = false`.
vim.keymap.set("i", "<CR>", complete.enter, {
  expr = true,
  replace_keycodes = false,
  desc = "Accept the highlighted completion, or break the line",
})

-- Tab takes a match without asking for the arrow first: the highlighted one if
-- there is one, otherwise the top of the list. What it costs is a literal Tab
-- while the menu happens to be open, which is close to free, since indentation
-- is settled by EditorConfig and applied on save.
vim.keymap.set("i", "<Tab>", complete.tab, {
  expr = true,
  desc = "Accept the highlighted completion, or the first one, else indent",
})

-- Ctrl+Space asks for the menu, the way it does in Zed and VS Code, and like
-- there it arrives stepped in: the top match is highlighted, so Enter takes
-- it, the arrows move from it, and PageUp and PageDown page the list. Asking
-- is the signal that a match is wanted, which is the signal the automatic menu
-- never has, and why that one stays unselected.
--
-- Bound twice for one key: a terminal sends Ctrl+Space as NUL, which arrives
-- as `<C-@>`, while a GUI sends the key itself.
vim.keymap.set("i", "<C-Space>", complete.now, {
  desc = "Open the completion menu here, top match highlighted",
})

vim.keymap.set("i", "<C-@>", complete.now, {
  desc = "Open the completion menu here (terminal spelling of Ctrl+Space)",
})

--- The leader -----------------------------------------------------------------
--
-- The whole custom surface, and it is meant to stay this short: anything rare
-- goes through the command palette instead of earning a key. The first six
-- open the same floating window, from mini.pick, so the keys inside it are
-- learned once (lua/mivn/find.lua).

local function leader(lhs, rhs, desc)
  vim.keymap.set("n", lhs, rhs, { desc = desc, silent = true })
end

leader("<leader>f", find.files, "Find file")
leader("<leader>/", find.grep, "Search the project")
leader("<leader>b", find.buffers, "Open buffers")
leader("<leader>:", find.palette, "Command palette")
leader("<leader>h", find.help, "Help")
leader("<leader>?", find.keymaps, "Every key, searchable")

-- <leader>t is where the toggles live, all of them, so that the question
-- "what turns this on" has one answer and the panel under <leader>t is the
-- list. The two that decide what a listing shows reach the tree and the
-- finders at once, since those are two views of one directory;
-- lua/mivn/filters.lua holds that answer and says why.
leader("<leader>tt", tree.toggle, "Show or hide the file tree")
leader("<leader>t`", terminal.toggle, "Show or hide the terminal")
leader("<leader>tw", margins.toggle_wrap, "Wrap long lines in this window, or stop")
leader("<leader>th", filters.toggle_dotfiles, "Show or hide dotfiles, in the tree and the finders")
leader("<leader>ti", filters.toggle_ignored, "Show or hide ignored files, in the tree and the finders")
leader("<leader>tb", blame.toggle, "Show or hide who wrote each line")

-- The gutter says which lines changed; this says what they were. mini.diff
-- ships no key for it, and the question it answers, "what did I do to this
-- file", is one I ask far more often than I stage a hunk, which has two keys.
-- Guarded, because mini.diff only attaches to a buffer that has a file behind
-- it. On the banner, the tree or the terminal it raised "Buffer N is not
-- enabled" from inside the plugin, which is a stack trace for a key that
-- simply has nothing to do there.
leader("<leader>tr", function()
  local diff = require("mini.diff")
  if not diff.get_buf_data(0) then
    vim.notify("Nothing to compare here: this buffer has no file behind it.", vim.log.levels.WARN)
    return
  end

  diff.toggle_overlay()
end, "Show the old text inline for every changed line, or stop")

-- <leader>a is what I ask the language server to do to this code, and
-- <leader>g is where I ask it to take me. Neovim's own gr-keys still work and
-- are left alone: these are a second way in, grouped so the panel under a
-- prefix is the list of what a server can do rather than five letters
-- scattered through the g-commands.
--
-- Both are set here rather than on LspAttach, which is what Neovim does with
-- its own: without a server they answer "no clients attached", which is a
-- better thing to meet than a key that silently is not there.
leader("<leader>aa", vim.lsp.buf.code_action, "Code action")
leader("<leader>ar", vim.lsp.buf.rename, "Rename symbol")
leader("<leader>af", format.buffer, "Format this buffer")
leader("<leader>aF", format.imports, "Organize imports")
leader("<leader>ai", vim.lsp.buf.hover, "Hover documentation")
leader("<leader>ax", vim.lsp.codelens.run, "Run the code lens on this line")
leader("<leader>ad", find.buffer_diagnostics, "Diagnostics in this buffer")
leader("<leader>aD", find.diagnostics, "Diagnostics in the workspace")

--
-- Each goes through find.list, so one answer is a jump and several are the
-- picker every other list in this config opens, rather than the quickfix
-- window stock puts them in.
leader("<leader>gd", find.list(vim.lsp.buf.definition), "Go to definition")
leader("<leader>gD", find.list(vim.lsp.buf.declaration), "Go to declaration")
leader("<leader>gi", find.list(vim.lsp.buf.implementation), "Go to implementation")
leader("<leader>gt", find.list(vim.lsp.buf.type_definition), "Go to type definition")
-- references takes the LSP context first and its options second, unlike the
-- four above, so the options cannot simply be passed along: handed over as
-- the first argument they are sent to the server as the request's context,
-- and a function in there is not something the wire can carry.
leader(
  "<leader>gr",
  find.list(function(opts)
    vim.lsp.buf.references(nil, opts)
  end),
  "Find references"
)
leader("<leader>gs", find.list(vim.lsp.buf.document_symbol), "Symbols in this document")
leader(
  "<leader>gS",
  find.list(function(opts)
    vim.lsp.buf.workspace_symbol("", opts)
  end),
  "Symbols in the workspace"
)

-- And Neovim's own, off, because the chains above are the way and one way is
-- the point: a second key for the same request is a thing to keep in step and
-- a second row in every panel that lists what is bound.
--
-- What comes back by dropping them is Vim's: `gO` is the outline of a help
-- page or a man page again, and `gd` its local declaration search, which is
-- what those keys mean everywhere this editor has no server attached anyway.
for _, lhs in ipairs({ "grn", "gra", "grr", "gri", "grt", "grx", "gO" }) do
  pcall(vim.keymap.del, "n", lhs)
end

-- `K` is not among them because it is not global: Neovim sets it on the
-- buffer as a server attaches, and only where nothing has claimed the key
-- already. So it comes off the same way, one buffer at a time. Without it `K`
-- is 'keywordprg' again, which is `:help` in Vim files and `man` elsewhere.
vim.api.nvim_create_autocmd("LspAttach", {
  group = vim.api.nvim_create_augroup("mivn.keymaps.lsp", { clear = true }),
  desc = "Take Neovim's K off; hover is <leader>ai",
  callback = function(ev)
    pcall(vim.keymap.del, "n", "K", { buffer = ev.buf })
  end,
})

--- The window -----------------------------------------------------------------

-- Ctrl with =, - or 0 zooms, and the numpad's +, - and 0 do the same. Neovide
-- only: in a terminal these keys never reach nvim, since foot takes them
-- itself and resizes its own font, which is the right owner there.
--
-- Each action maps two keys, because the keypad sends its own codes and a
-- <C-=> map never sees <C-kPlus>. The keypad digits are <k0> through <k9> in
-- key notation, not spelled-out names: <C-kZero> parses as nothing and maps a
-- literal sequence no key sends.
if vim.g.neovide then
  -- Zooming while typing, while selecting and in the terminal panel too: the
  -- window is the same window in all of them.
  local MODES = { "n", "i", "x", "s", "t" }

  for _, z in ipairs({
    { keys = { "<C-=>", "<C-kPlus>" }, to = zoom.into, desc = "Zoom in" },
    { keys = { "<C-->", "<C-kMinus>" }, to = zoom.out, desc = "Zoom out" },
    { keys = { "<C-0>", "<C-k0>" }, to = zoom.reset, desc = "Zoom back to 100%" },
  }) do
    for _, lhs in ipairs(z.keys) do
      vim.keymap.set(MODES, lhs, z.to, { desc = z.desc })
    end
  end
end

-- ZR is :restart's Normal-mode spelling. It is a built-in, not a mapping, so
-- one mapping shadows it; lua/mivn/restart.lua refuses it when the window is
-- on another machine and feeds the real key back through when it is not.
vim.keymap.set("n", "ZR", restart.restart, {
  desc = "Restart, unless the window is on another machine",
})

--- The command line -----------------------------------------------------------
--
-- The four keys the automatic completion menu needs.
-- `:h cmdline-autocompletion` gives this exact recipe with the two arms the
-- other way round; the menu is open most of the time here (init.lua opens it
-- as I type), and a menu I cannot walk with the arrows is a menu I have to
-- learn a key for.
--
-- Measured, in file completion: `Down` does nothing at all and `Up` moves the
-- completion out into the parent directory, silently turning `:e lua/mivn/tr`
-- into `:e lua/`. Shift+Up and Shift+Down are not reliably history either,
-- since an open file menu takes them too, so they get `Ctrl+E` first: the key
-- that ends completion and puts back what I typed.
--
-- Note the two kinds of history key differ. `Up` and `Down` recall only the
-- commands starting with what is on the line; Shift and the arrows walk the
-- whole history unfiltered. PageUp and PageDown are left alone, because while
-- the menu is open they page it.
local function cmdline_key(in_menu, plain)
  return function()
    return vim.fn.wildmenumode() == 1 and in_menu or plain
  end
end

vim.keymap.set("c", "<Down>", cmdline_key("<C-n>", "<Down>"), {
  expr = true,
  desc = "Next match while the menu is open, newer history otherwise",
})

vim.keymap.set("c", "<Up>", cmdline_key("<C-p>", "<Up>"), {
  expr = true,
  desc = "Previous match while the menu is open, older history otherwise",
})

vim.keymap.set("c", "<S-Down>", cmdline_key("<C-e><S-Down>", "<S-Down>"), {
  expr = true,
  desc = "Newer command-line history, menu or no menu",
})

vim.keymap.set("c", "<S-Up>", cmdline_key("<C-e><S-Up>", "<S-Up>"), {
  expr = true,
  desc = "Older command-line history, menu or no menu",
})
