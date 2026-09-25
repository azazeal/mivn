-- Every key mivn takes for the whole session. The module that owns a behavior
-- exports a function, and this file picks its key. A mapping that lives only as
-- long as some buffer stays with that buffer's module, and the CUA habits Vim
-- has an option for ('keymodel', 'whichwrap', 'langmap') are in init.lua.

local blame = require("mivn.blame")
local complete = require("mivn.complete")
local diff = require("mivn.diff")
local filters = require("mivn.filters")
local find = require("mivn.find")
local format = require("mivn.format")
local hints = require("mivn.hints")
local indent = require("mivn.indent")
local margins = require("mivn.margins")
local move = require("mivn.move")
local page = require("mivn.page")
local pairing = require("mivn.pairs") -- not `pairs`, which is Lua's own
local restart = require("mivn.restart")
local terminal = require("mivn.terminal")
local tree = require("mivn.tree")
local words = require("mivn.words")
local zoom = require("mivn.zoom")

--- The clipboard --------------------------------------------------------------
--
-- Copy and paste reach the system clipboard; delete and change do not, and
-- Alt+d and Alt+c are the cut that does. Vim's registers stay as they ship.
--
-- NOTE: every one of these is an <expr> mapping so that a register I name wins.
-- A plain `"+p` on the right-hand side overrides the one I typed, so `"1p` and
-- `"ap` would paste the clipboard too. The prefix goes on only when v:register
-- is `"`, so a literal `""p` pastes the clipboard as well.
local function clipboard(keys)
  return function()
    return (vim.v.register == '"' and '"+' or "") .. keys
  end
end

local function copy_paste(mode, lhs, keys, desc)
  vim.keymap.set(mode, lhs, clipboard(keys), { expr = true, desc = desc })
end

-- NOTE: Normal's `Y` is written as `y$` because these are noremap. A bare `Y`
-- reaches Vim's own, which is `yy`, and loses Neovim's default.
copy_paste({ "n", "x" }, "y", "y", "Copy to the clipboard")
copy_paste("n", "Y", "y$", "Copy to the end of the line, to the clipboard")
copy_paste("x", "Y", "Y", "Copy the selected lines to the clipboard")

--- Paste, leaving the caret after what was pasted rather than on its last
--- character, through `gp` and `gP`; 'virtualedit' lets that be past the end of
--- the line. Charwise only: on a line-wise or block-wise register `gp` lands
--- past the text, so those keep Vim's landing.
local function paste(keys)
  return function()
    local register = vim.v.register == '"' and "+" or vim.v.register
    local after = vim.fn.getregtype(register):sub(1, 1) == "v" and "g" or ""

    return clipboard(after .. keys)()
  end
end

vim.keymap.set("n", "p", paste("p"), {
  expr = true,
  desc = "Paste the clipboard after the cursor",
})

vim.keymap.set("n", "P", paste("P"), {
  expr = true,
  desc = "Paste the clipboard before the cursor",
})

-- NOTE: over a selection both keys are `P` (`:h v_P`), which leaves the
-- registers alone. `p` there moves the replaced text onto the clipboard, so a
-- paste over a second selection would paste that instead.
for _, lhs in ipairs({ "p", "P" }) do
  vim.keymap.set("x", lhs, paste("P"), {
    expr = true,
    desc = "Paste the clipboard over the selection",
  })
end

copy_paste({ "n", "x" }, "<A-d>", "d", "Delete, and put it on the clipboard")
copy_paste({ "n", "x" }, "<A-c>", "c", "Change, and put what was there on the clipboard")

--- Editing --------------------------------------------------------------------

-- `<C-g>u` breaks the undo block first, as Neovim does for Ctrl+W, so one `u`
-- brings the word back without taking the typing with it.
vim.keymap.set("i", "<C-Del>", "<C-g>u<C-o>dw", {
  desc = "Delete the word after the cursor",
})

-- In Normal Vim would read it as Del, which is `x`. Over a selection it stays
-- Vim's Del.
vim.keymap.set("n", "<C-Del>", "dw", {
  desc = "Delete the word after the cursor",
})

-- `u` over a selection undoes, where Vim lowercases (`:h v_u`), so the case
-- keys move to the backtick. Ctrl and a backtick needs Neovide or a terminal
-- that speaks the kitty keyboard protocol; `U` works everywhere.
vim.keymap.set("x", "u", "<Esc>u", {
  desc = "Drop the selection, then undo",
})

vim.keymap.set("x", "`", "~", {
  desc = "Toggle the case of the selection",
})

vim.keymap.set("x", "<C-`>", "U", {
  desc = "Make the selection uppercase",
})

vim.keymap.set("x", "<A-`>", "u", {
  desc = "Make the selection lowercase",
})

for _, mv in ipairs({
  { lhs = "<C-Up>", to = move.up, word = "up" },
  { lhs = "<C-Down>", to = move.down, word = "down" },
}) do
  vim.keymap.set({ "n", "i" }, mv.lhs, mv.to, {
    desc = "Move the line " .. mv.word,
  })

  vim.keymap.set({ "x", "s" }, mv.lhs, mv.to, {
    desc = "Move the selected lines " .. mv.word,
  })
end

-- A bracket or a quote typed over a selection wraps it. The characters come
-- from mini.pairs' table, so the pairs are configured in one place.
for _, wrap in ipairs(pairing.surrounds()) do
  vim.keymap.set("s", wrap.key, function()
    pairing.surround(wrap.open, wrap.close)
  end, {
    desc = ("Wrap the selection in %s%s"):format(wrap.open, wrap.close),
  })
end

-- The real Esc still follows, so it keeps doing what it did.
vim.keymap.set("n", "<Esc>", "<Cmd>nohlsearch<CR><Esc>", {
  desc = "Clear search highlighting",
})

--- Moving and selecting -------------------------------------------------------

-- Ctrl and a horizontal arrow moves by a word, Alt by a subword: right lands
-- past the end, left on the start, which is Zed's shape. Insert is bound too,
-- since Vim's own key there is a different distance. Visual and Select reach
-- these through the drop at the end of this section.
for _, key in ipairs({
  { lhs = "<C-Right>", forward = true, size = "word", to = "past the end of the word" },
  { lhs = "<C-Left>", forward = false, size = "word", to = "to the start of the previous word" },
  { lhs = "<A-Right>", forward = true, size = "subword", to = "past the end of the subword" },
  { lhs = "<A-Left>", forward = false, size = "subword", to = "to the start of the previous subword" },
}) do
  -- going right stops at an end, going left at a start
  vim.keymap.set({ "n", "i" }, key.lhs, words.move(key.forward, key.forward, key.size), {
    desc = "Move " .. key.to,
  })
end

-- After an operator the arrows run Vim's `e` and `b`: `e` is inclusive, so
-- `d<C-Right>` covers the word and no more. The Alt pair has no operator form.
vim.keymap.set("o", "<C-Right>", "e", {
  desc = "Through the end of the word",
})

vim.keymap.set("o", "<C-Left>", "b", {
  desc = "To the start of the previous word",
})

-- The four end keys land past the last character, in Normal and Visual. After
-- an operator they stay Vim's inclusive motions, so `de` covers the word.
--
-- NOTE: these go through words.lua, not Vim's key plus a column. `e` at the end
-- of a word skips to the end of the next one, `ge` skips the same way
-- backwards, and `gE` plus a column right lands back where it started.
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

--- The keys Home runs, by Zed's `indented_line_beginning`: from past the indent
--- or from column zero, the indent; from the indent or inside it, column zero.
--- A line that is all whitespace goes to column zero.
local function home()
  local indent = vim.api.nvim_get_current_line():find("%S")
  if not indent then
    return "0"
  end

  local col = vim.fn.col(".")

  return (col > indent or col == 1) and "^" or "0"
end

vim.keymap.set({ "n", "o" }, "<Home>", home, {
  expr = true,
  desc = "Move to the first character of the line, or to column zero",
})

-- The same rule while typing. End needs nothing here: Vim's own already goes
-- past the last character.
vim.keymap.set("i", "<Home>", function()
  return "<C-o>" .. home()
end, {
  expr = true,
  desc = "Move to the first character of the line, or to column zero",
})

-- Normal only: `d<End>` already covers the line, and exclusive selection gives
-- Visual the extra column.
vim.keymap.set("n", "<End>", "$l", {
  desc = "Move past the end of the line",
})

-- Vim's own pair misses both ends: `G` lands on the last character, and `gg`
-- keeps the column while 'startofline' is off.
vim.keymap.set("n", "<C-Home>", "gg0", {
  desc = "Move to the start of the file",
})

vim.keymap.set("n", "<C-End>", "G$l", {
  desc = "Move past the end of the file",
})

-- Shift and an arrow selects by a character or a line, bound by hand since
-- 'keymodel' has no "startsel" (init.lua says why). The motion is the unshifted
-- key's.
--
-- NOTE: the arrow runs with 'keymodel' cleared. "stopsel" cannot tell an arrow
-- I typed from one a mapping fed it, so `v<Right>` would open a selection and
-- end it at once.
--
-- NOTE: :normal and not nvim_feedkeys. The keys must run before 'keymodel' goes
-- back, which takes feedkeys' "x" flag, and "x" runs whatever I typed ahead
-- first: `abc`, Shift+Left twice and `x` in one burst left `abcx` and not `ax`.
-- :normal leaves the typeahead alone.
local function arrow(keys)
  return function()
    local saved = vim.o.keymodel
    vim.o.keymodel = ""
    local ok, err = pcall(vim.cmd.normal, { vim.keycode(keys), bang = true })
    vim.o.keymodel = saved

    if not ok then
      error(err, 0)
    end
  end
end

-- A shifted key pressed while typing opens a selection at the caret, then
-- presses the key again for the Select mapping beside it to move, which is why
-- those mappings remap. It opens Select and not Visual, since what I do to a
-- selection made while typing is type over it.
--
-- NOTE: the opening is a <Plug> so that its own keys are not remapped: `gh` in
-- Normal is mini.diff's staging operator.
--
-- NOTE: `<C-o>` is what keeps the caret. Leaving Insert any other way moves the
-- cursor one column left, and putting it back by hand lands after the mapping
-- has returned, dragging the open selection with it.
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

  -- select borrows the motion through <C-o>, as Visual for one key
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

-- The file's two ends with Shift. Normal opens Visual, Insert opens Select
-- through the <Plug>, and Visual and Select take the plain motion. `$` needs no
-- `l` here, since exclusive selection gives it the extra column.
--
-- NOTE: in Select each command needs its own `<C-o>`, which covers one command
-- and no more. Written `<C-o>G$`, the `$` arrives back in Select and types over
-- the selection.
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

-- Ctrl or Alt with Shift selects by a word or a subword, in the same four modes
-- as the file's two ends above. After an operator it is left alone.
for _, sel in ipairs({
  { lhs = "<C-S-Right>", forward = true, size = "word", to = "past the end of the word" },
  { lhs = "<C-S-Left>", forward = false, size = "word", to = "to the start of the previous word" },
  { lhs = "<A-S-Right>", forward = true, size = "subword", to = "past the end of the subword" },
  { lhs = "<A-S-Left>", forward = false, size = "subword", to = "to the start of the previous subword" },
}) do
  -- sets the cursor rather than typing, so Select needs no <C-o> around it
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

-- Insert is the way out of typing as well as in, so it no longer toggles
-- Replace; `R` still enters it.
vim.keymap.set("i", "<Insert>", "<C-\\><C-N>", {
  desc = "Stop typing",
})

vim.keymap.set({ "x", "s" }, "<Insert>", "<C-\\><C-N>i", {
  desc = "Type on from where the caret is",
})

-- Visual and Select reach these through the drop at the end of this section.
-- Bound there directly, only the scroll would go through 'keymodel', so the
-- selection would live on a short file and die on a long one.
vim.keymap.set({ "n", "i" }, "<PageDown>", page.down, {
  desc = "A page down, or the last line when there is no page left",
})

vim.keymap.set({ "n", "i" }, "<PageUp>", page.up, {
  desc = "A page up, or the first line when there is no page left",
})

-- These open a selection only from Normal and otherwise just move, which
-- extends one. Insert goes through the <Plug> like the other shifted keys.
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

-- An unshifted key over a selection drops it, then means what it means without
-- one. Bound for every unshifted key this file binds in Normal or Insert, since
-- "stopsel" runs Vim's own key and never a mapping.
--
-- The key is fed again after Esc and resolves against Normal's table, even from
-- a Select opened while typing: Vim holds back the return to Insert until the
-- mapping's keys are spent (`old_mapped_len` in normal.c). Every key here lands
-- the same from either mode.
--
-- The description is read from the Normal mapping, so this stays below every
-- key it lists.
local function dropping(lhs)
  return "<Esc>" .. lhs
end

for _, lhs in ipairs({
  "<C-Right>",
  "<C-Left>",
  "<A-Right>",
  "<A-Left>",
  "<Home>",
  "<End>",
  "<C-Home>",
  "<C-End>",
  "<PageDown>",
  "<PageUp>",
}) do
  local plain = vim.fn.maparg(lhs, "n", false, true).desc

  vim.keymap.set({ "x", "s" }, lhs, dropping(lhs), {
    remap = true,
    desc = "Drop the selection, then " .. plain:sub(1, 1):lower() .. plain:sub(2),
  })
end

-- `{count}|` counts characters, not screen cells: the column the status line
-- shows and a compiler prints.
vim.keymap.set({ "n", "x", "o" }, "|", margins.to_char_column, {
  desc = "To the {count}'th character of the line",
})

-- The tab bar's two chords; `:bnext` and `:bprevious` wrap at both ends.
-- Terminal mode is left out, since its keys belong to the shell and `:bnext`
-- would put a file in the panel's split.
--
-- NOTE: `<C-Tab>` only, never Tab. A legacy terminal sends Ctrl+Tab as Tab, and
-- Normal-mode Tab is Ctrl+I, forward through the jumplist. The chords arrive as
-- themselves from Neovide and extended-keyboard terminals and do nothing
-- elsewhere.
vim.keymap.set({ "n", "i", "x", "s" }, "<C-Tab>", "<Cmd>bnext<CR>", {
  desc = "Next buffer in the tab bar",
})

vim.keymap.set({ "n", "i", "x", "s" }, "<C-S-Tab>", "<Cmd>bprevious<CR>", {
  desc = "Previous buffer in the tab bar",
})

--- Completion, in Insert mode -------------------------------------------------
--
-- NOTE: Up and Down are not bound. They already walk the menu without writing
-- the match into the buffer (`:h popupmenu-keys`). PageUp and PageDown are
-- page.lua's, above.

-- `noselect` leaves nothing highlighted until an arrow, so Enter with the menu
-- merely open still breaks the line.
--
-- NOTE: `replace_keycodes = false`, because the newline comes from mini.pairs
-- as raw termcodes already.
vim.keymap.set("i", "<CR>", complete.enter, {
  expr = true,
  replace_keycodes = false,
  desc = "Accept the highlighted completion, or break the line",
})

-- With the menu open Tab takes a match without an arrow first, the top one when
-- none is highlighted.
vim.keymap.set("i", "<Tab>", complete.tab, {
  expr = true,
  desc = "Accept the completion, or jump to the next placeholder, else a tab",
})

-- This replaces Neovim's own Insert-mode Shift+Tab, so a snippet placeholder
-- still comes first.
vim.keymap.set("i", "<S-Tab>", indent.dedent_line, {
  expr = true,
  desc = "Jump to the previous placeholder, or dedent the line",
})

-- Select loses nothing here: Tab is not a printable key there.
vim.keymap.set({ "x", "s" }, "<Tab>", indent.indent, {
  desc = "Indent the selected lines, and keep the selection",
})

vim.keymap.set({ "x", "s" }, "<S-Tab>", indent.dedent, {
  desc = "Dedent the selected lines, and keep the selection",
})

vim.keymap.set("i", "<Esc>", complete.escape, {
  expr = true,
  desc = "Close the completion menu, or stop typing",
})

-- The menu opens with the top match highlighted, unlike the automatic one,
-- since asking is the sign that a match is wanted.
vim.keymap.set("i", "<C-Space>", complete.now, {
  desc = "Open the completion menu here, top match highlighted",
})

vim.keymap.set("i", "<C-@>", complete.now, {
  desc = "Open the completion menu here (terminal spelling of Ctrl+Space)",
})

--- The leader -----------------------------------------------------------------
--
-- Short on purpose: anything rare goes through the command palette. The first
-- six open the same mini.pick window.

local function leader(lhs, rhs, desc)
  vim.keymap.set("n", lhs, rhs, { desc = desc, silent = true })
end

leader("<leader>f", find.files, "Find file")
leader("<leader>/", find.grep, "Search the project")
leader("<leader>b", find.buffers, "Open buffers")
leader("<leader>:", find.palette, "Command palette")
leader("<leader>h", find.help, "Help")
leader("<leader>?", find.keymaps, "Every key, searchable")

-- Every toggle lives under <leader>t. Dotfiles and ignored files reach the tree
-- and the finders at once, since those are two views of one directory.
leader("<leader>tt", tree.toggle, "Toggle tree")
leader("<leader>t`", terminal.toggle, "Toggle terminal")
leader("<leader>tw", margins.toggle_wrap, "Toggle wrap")
leader("<leader>th", filters.toggle_dotfiles, "Toggle dotfiles")
leader("<leader>ti", filters.toggle_ignored, "Toggle ignored files")
leader("<leader>tb", blame.toggle, "Toggle blame")

-- The key is `n` because `h` and `i` are taken.
leader("<leader>tn", hints.toggle, "Toggle inlay hints")

-- The gutter says which lines changed; review shows what they were.
leader("<leader>tr", diff.toggle_review, "Toggle review")

-- The six flags in one line, keyed by the letter that flips each; the tree and
-- the terminal are on screen or not. Read at the press, since wrap belongs to
-- the window and review and the hints to the buffer.
leader("<leader>t?", function()
  local function say(flag, yes, no)
    return flag and yes or no
  end

  vim.notify(
    ("(b: %s, h: %s, i: %s, n: %s, r: %s, w: %s)"):format(
      say(blame.on(), "on", "off"),
      say(filters.dotfiles(), "shown", "hidden"),
      say(filters.ignored(), "shown", "hidden"),
      say(hints.on(), "on", "off"),
      say(diff.reviewing(), "on", "off"),
      say(vim.wo.wrap, "on", "off")
    )
  )
end, "What is on")

-- <leader>a is what I ask the language server to do to this code, <leader>g
-- where I ask it to take me. Set here rather than on LspAttach, so without a
-- server they answer "no clients attached" instead of being missing. Code
-- action takes a selection too, since a server offers actions on a range.
vim.keymap.set({ "n", "x" }, "<leader>aa", vim.lsp.buf.code_action, {
  desc = "Code action",
  silent = true,
})
leader("<leader>ar", vim.lsp.buf.rename, "Rename symbol")
leader("<leader>af", format.buffer, "Format this buffer")
leader("<leader>aF", format.imports, "Organize imports")
leader("<leader>ai", vim.lsp.buf.hover, "Hover documentation")
leader("<leader>ax", vim.lsp.codelens.run, "Run the code lens on this line")
leader("<leader>ad", find.buffer_diagnostics, "Diagnostics in this buffer")
leader("<leader>aD", find.diagnostics, "Diagnostics in the workspace")

-- Each goes through find.list, so one answer is a jump and several open the
-- picker rather than the quickfix window.
leader("<leader>gd", find.list(vim.lsp.buf.definition), "Go to definition")
leader("<leader>gD", find.list(vim.lsp.buf.declaration), "Go to declaration")
leader("<leader>gi", find.list(vim.lsp.buf.implementation), "Go to implementation")
leader("<leader>gt", find.list(vim.lsp.buf.type_definition), "Go to type definition")
-- NOTE: references takes the LSP context first and its options second, so it is
-- wrapped. Handed over first, the options go to the server as the request's
-- context, and a function in there cannot cross the wire.
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

-- Neovim's own gr-keys and `gO` come off, so each request has one key, and `gO`
-- is the outline of a help or man page again. Neovim sets `gra` in Visual as
-- well, hence the second delete.
for _, lhs in ipairs({ "grn", "gra", "grr", "gri", "grt", "grx", "gO" }) do
  pcall(vim.keymap.del, "n", lhs)
end

pcall(vim.keymap.del, "x", "gra")

-- Neovim sets `K` per buffer as a server attaches, so it comes off the same
-- way. Without it `K` is 'keywordprg' again.
vim.api.nvim_create_autocmd("LspAttach", {
  group = vim.api.nvim_create_augroup("mivn.keymaps.lsp", { clear = true }),
  desc = "Take Neovim's K off; hover is <leader>ai",
  callback = function(ev)
    pcall(vim.keymap.del, "n", "K", { buffer = ev.buf })
  end,
})

--- The window -----------------------------------------------------------------

-- Neovide only: a terminal takes these keys for its own font. The keypad sends
-- its own codes, so each action has two keys.
--
-- NOTE: the keypad digits are <k0> to <k9>. <C-kZero> parses as nothing and
-- maps a literal sequence no key sends.
if vim.g.neovide then
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

-- ZR is :restart's built-in Normal-mode spelling. A count keeps Vim's meaning,
-- a restart without the session, so `1ZR` is still `:restart!`.
vim.keymap.set("n", "ZR", function()
  restart.restart(vim.v.count > 0)
end, {
  desc = "Restart, unless the window is on another machine",
})

--- The command line -----------------------------------------------------------
--
-- The completion menu opens as I type, so the arrows walk it while it is open
-- and are history otherwise; `:h cmdline-autocompletion` has this recipe with
-- the two arms the other way round. Stock arrows in a file menu do nothing
-- (`Down`) or climb to the parent directory (`Up`).
--
-- Shift and an arrow is history either way, so it sends Ctrl+E first to end the
-- menu. It walks the whole history, where `Up` and `Down` recall only what
-- starts with the line.
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
