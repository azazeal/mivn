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

-- Esc clears leftover search highlighting, which Vim otherwise keeps lit until
-- :noh (Ctrl+L, a Neovim default, does the same plus a redraw). The real Esc
-- is sent on afterwards, so everything it already did still happens.
vim.keymap.set("n", "<Esc>", "<Cmd>nohlsearch<CR><Esc>", {
  desc = "Clear search highlighting",
})
