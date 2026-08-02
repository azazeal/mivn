-- Completion in Insert mode: the menu opens by itself, the arrows walk it,
-- Enter and Tab take a match.
--
-- No plugin. 'autocomplete' is Neovim's own option for a menu that appears as
-- I type, new in 0.12, and the language server reaches it through 'complete'
-- like any other source.

--- What the menu is made of --------------------------------------------------

-- The menu appears as I type rather than only on Ctrl+X Ctrl+O.
-- 'autocompletedelay' stays 0, since the wait is already the language server's
-- round trip.
vim.o.autocomplete = true

-- Where the matches come from, in order, which is also the priority: Neovim
-- gives each source a slice of time and the earlier ones get more. `o` is the
-- language server through 'omnifunc'; `.`, `w` and `b` are words already
-- written, in this buffer, other windows, then the rest of the buffer list.
--
-- The `^10` on the word sources is a match limit: without it a long file fills
-- the menu with its own identifiers and pushes the server's answers off the
-- end. Vim's `u` is left out because it reads unloaded buffers off disk
-- mid-keystroke, and `t` wants a tags file this setup never generates.
vim.opt.complete = { "o", ".^10", "w^10", "b^10" }

-- `menuone` so a single match still gets a menu rather than being inserted
-- from under me, `noselect` so nothing is chosen until I choose it (which is
-- what leaves Enter free to be a newline), `popup` for the doc window, and
-- `fuzzy` so "nsl" reaches "nvim_set_lines". 'autocomplete' turns `noselect`
-- on by itself and ignores `menuone`; both are written out anyway because they
-- still govern the Ctrl+X completion underneath.
vim.o.completeopt = "menuone,noselect,popup,fuzzy"

--- The language server's half ------------------------------------------------

-- `enable` is what makes accepting a match do the work that comes with it:
-- expanding a snippet, applying the extra edits an item carries (the import
-- line for the symbol I picked), resolving the documentation in the popup.
--
-- No `autotrigger`: it fires on the trigger characters the server names, which
-- 'autocomplete' already covers, so both on means two requests racing on the
-- same character.
vim.api.nvim_create_autocmd("LspAttach", {
  group = vim.api.nvim_create_augroup("mivn.complete", { clear = true }),
  callback = function(ev)
    local client = vim.lsp.get_client_by_id(ev.data.client_id)
    if client and client:supports_method("textDocument/completion") then
      vim.lsp.completion.enable(true, ev.data.client_id, ev.buf)
    end
  end,
})

--- The two keys ---------------------------------------------------------------

--- Whether a match in the open menu is currently highlighted.
local function selected()
  return vim.fn.complete_info({ "selected" }).selected ~= -1
end

-- Up and Down are not bound and must not be: they already walk the menu the
-- useful way, moving the highlight without writing the match into the buffer.
-- Ctrl+E closes the menu and gives back what I typed. `:h popupmenu-keys`.

-- Enter takes the highlighted match, and is a newline the rest of the time.
-- The condition is the point: `noselect` means nothing is highlighted until I
-- press an arrow, so Enter while the menu is merely *open* still breaks the
-- line. Acceptance goes through Ctrl+Y, the key the language server hangs its
-- extra edits off.
--
-- The newline path goes through mini.pairs, which is the integration its own
-- docs ask completion mappings to do; the plugin maps <CR> itself only when
-- nothing else has. MiniPairs.cr() returns raw termcodes, hence
-- `replace_keycodes = false` and vim.keycode() on the other branches. The
-- pcall keeps Enter a plain newline if mini.pairs is ever dropped.
vim.keymap.set("i", "<CR>", function()
  if selected() then
    return vim.keycode("<C-y>")
  end

  local ok, pairs = pcall(require, "mini.pairs")
  return ok and pairs.cr() or vim.keycode("<CR>")
end, {
  expr = true,
  replace_keycodes = false,
  desc = "Accept the highlighted completion, or break the line",
})

-- Tab takes a match without asking for the arrow first: the highlighted one if
-- there is one, otherwise the top of the list. What it costs is a literal Tab
-- while the menu happens to be open, which is close to free, since indentation
-- is settled by EditorConfig and applied on save.
vim.keymap.set("i", "<Tab>", function()
  if selected() then
    return "<C-y>"
  end

  if vim.fn.pumvisible() == 1 then
    return "<C-n><C-y>"
  end

  return "<Tab>"
end, {
  expr = true,
  desc = "Accept the highlighted completion, or the first one, else indent",
})

-- Ctrl+Space asks for the menu, the way it does in Zed and VS Code. It earns
-- its place where the automatic trigger has nothing to go on: a fresh line or
-- just after a space. `<C-n>` rather than `<C-x><C-o>`, so it is the same set
-- of sources as the automatic menu instead of the server alone.
--
-- Bound twice for one key: a terminal sends Ctrl+Space as NUL, which arrives
-- as `<C-@>`, while a GUI sends the key itself.
local function complete_now()
  return vim.fn.pumvisible() == 1 and "" or "<C-n>"
end

vim.keymap.set("i", "<C-Space>", complete_now, {
  expr = true,
  desc = "Open the completion menu here",
})

vim.keymap.set("i", "<C-@>", complete_now, {
  expr = true,
  desc = "Open the completion menu here (terminal spelling of Ctrl+Space)",
})

-- PageUp and PageDown are not here. They belong to the file as much as to the
-- menu, and which one they move is decided in lua/mivn/page.lua.
