-- The CUA edit keys Vim has no option for, so they need an actual mapping.
-- The selection bridge is pure options and lives in init.lua instead.

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

-- Ctrl and an arrow moves by a word, the small kind that stops at
-- punctuation. Vim has it the other way around on the arrows: Shift+arrow is
-- `w` and Ctrl+arrow is `W`. Shift is spent on selecting here ('keymodel' in
-- init.lua), so the arrows would be left with the WORD alone, which crosses a
-- whole `foo::bar(baz(r, g, b))` in one press. Every editor I have used moves
-- by the small word on Ctrl+arrow, and so does Insert mode right here, which
-- needed no mapping to do it.
--
-- Normal and operator-pending only, so `d<C-Right>` deletes a word. Not
-- Visual or Select: there an unshifted special key ends the selection
-- ('keymodel' has "stopsel"), and a mapping would take the key over and keep
-- the selection alive instead. `W` and `B` keep the WORD, one unshifted key
-- each.
vim.keymap.set({ "n", "o" }, "<C-Right>", "w", {
  desc = "Move to the start of the next word",
})

vim.keymap.set({ "n", "o" }, "<C-Left>", "b", {
  desc = "Move to the start of the previous word",
})

-- Ctrl+Shift and an arrow selects by that same word. 'keymodel' opens the
-- selection on its own and always reaches for the WORD, and it reads Vim's
-- own key rather than the mapping above, so the two only agree if the
-- opening happens here instead.
--
-- Three mappings each, because the opening is what differs. From Normal
-- there is no selection yet, so this opens Visual the way a shifted arrow
-- does ('selectmode' is unset in init.lua). In Select, which the floating
-- prompt still preselects in, the motion has to be borrowed through <C-o> or
-- `w` would replace the selection with the letter. In Visual it is the plain
-- motion. After an operator the key is left as it was: `d` and a shifted
-- arrow is not something I press.
--
-- One order comes out wrong and is TODO.md's: a single Shift+Right and then
-- this key selects two words, because Vim runs the built-in WORD first while
-- the selection is still one character wide, and the mapping's `w` lands on
-- top of that.
for _, sel in ipairs({
  { lhs = "<C-S-Right>", motion = "w", word = "next" },
  { lhs = "<C-S-Left>", motion = "b", word = "previous" },
}) do
  vim.keymap.set("n", sel.lhs, "v" .. sel.motion, {
    desc = "Select to the start of the " .. sel.word .. " word",
  })

  vim.keymap.set("x", sel.lhs, sel.motion, {
    desc = "Extend the selection to the start of the " .. sel.word .. " word",
  })

  vim.keymap.set("s", sel.lhs, "<C-o>" .. sel.motion, {
    desc = "Extend the selection to the start of the " .. sel.word .. " word",
  })
end

-- Ctrl+Shift and a vertical arrow carries the line, or the selected lines,
-- up or down. The chord is my own from Zed and VS Code, rebound to it in
-- both, and it is free here: without a mapping it extended the selection by
-- one line, which plain Shift already does.
--
-- Built on :move because `dd`/`p` would overwrite the clipboard on every
-- press ('clipboard' is unnamedplus); :move touches no register. The customary
-- reindent (`==`, and mini.move's default) is deliberately absent: it trusts
-- the filetype's indent, and Rust's flattens a `.method()` chain line to
-- column zero. The move is exact and indentation stays mine.
--
-- At the buffer's edges :move fails and `silent!` is what keeps that quiet;
-- the key becomes a no-op instead of an error. In Visual, `gv` reselects, so
-- holding the key walks the block through the file; the mapping also takes
-- the key away from 'keymodel', which is the point rather than a loss, per
-- the redundancy above.
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
  { lhs = "<C-S-Up>", line = ".-2", lines = "'<-2", word = "up" },
  { lhs = "<C-S-Down>", line = ".+1", lines = "'>+1", word = "down" },
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
