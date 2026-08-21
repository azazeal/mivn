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

local complete = require("mivn.complete")
local filters = require("mivn.filters")
local find = require("mivn.find")
local format = require("mivn.format")
local margins = require("mivn.margins")
local page = require("mivn.page")
local restart = require("mivn.restart")
local terminal = require("mivn.terminal")
local tree = require("mivn.tree")
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

-- Ctrl and a horizontal arrow moves by a word, the small kind that stops at
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

-- Ctrl+Shift and a horizontal arrow selects by that same word. 'keymodel'
-- opens the selection on its own and always reaches for the WORD, and it
-- reads Vim's own key rather than the mapping above, so the two only agree if
-- the opening happens here instead.
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

-- Normal, Visual and Insert. Select mode is left to Vim: there an unshifted key
-- ends the selection first ('keymodel' has "stopsel"), and taking the key would
-- take that with it. lua/mivn/page.lua is why these are not Vim's own pair.
vim.keymap.set({ "n", "x", "i" }, "<PageDown>", page.down, {
  desc = "A page down, or the last line when there is no page left",
})

vim.keymap.set({ "n", "x", "i" }, "<PageUp>", page.up, {
  desc = "A page up, or the first line when there is no page left",
})

-- Not Insert: from there 'keymodel' still opens the selection itself, with the
-- unclamped motion. Reproducing the open would mean leaving Insert by hand and
-- re-anchoring the exclusive selection, and a page-selection mid-typing is not
-- worth that trade yet; TODO.md if the edge ever bites there.
vim.keymap.set({ "n", "x" }, "<S-PageDown>", page.select_down, {
  desc = "Select a page down, to the last line when there is no page left",
})

vim.keymap.set({ "n", "x" }, "<S-PageUp>", page.select_up, {
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
vim.keymap.set("n", "<C-Tab>", "<Cmd>bnext<CR>", {
  desc = "Next buffer in the tab bar",
})

vim.keymap.set("n", "<C-S-Tab>", "<Cmd>bprevious<CR>", {
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

leader("<leader>gd", vim.lsp.buf.definition, "Go to definition")
leader("<leader>gD", vim.lsp.buf.declaration, "Go to declaration")
leader("<leader>gi", vim.lsp.buf.implementation, "Go to implementation")
leader("<leader>gt", vim.lsp.buf.type_definition, "Go to type definition")
leader("<leader>gr", vim.lsp.buf.references, "Find references")
leader("<leader>gs", vim.lsp.buf.document_symbol, "Symbols in this document")
leader("<leader>gS", function()
  vim.lsp.buf.workspace_symbol("")
end, "Symbols in the workspace")

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
