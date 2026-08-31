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
-- This is the serverless default; a buffer a completing server attaches to
-- narrows to `o` alone, in the LspAttach below.
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
local group = vim.api.nvim_create_augroup("mivn.complete", { clear = true })

vim.api.nvim_create_autocmd("LspAttach", {
  group = group,
  callback = function(ev)
    local client = vim.lsp.get_client_by_id(ev.data.client_id)
    if client and client:supports_method("textDocument/completion") then
      vim.lsp.completion.enable(true, ev.data.client_id, ev.buf)

      -- The server becomes the only source, which is Zed's rule. The word
      -- sources would re-offer identifiers the server already answered with:
      -- every call site is also a word, the server's entry carries the
      -- signature while the word carries nothing, and Vim has no dedup
      -- across sources (the LSP marks its items dup on purpose).
      vim.bo[ev.buf].complete = "o"
    end
  end,
})

vim.api.nvim_create_autocmd("LspDetach", {
  group = group,
  desc = "Give a buffer its word sources back when the last server leaves",
  callback = function(ev)
    for _, client in ipairs(vim.lsp.get_clients({ bufnr = ev.buf })) do
      if client.id ~= ev.data.client_id and client:supports_method("textDocument/completion") then
        return
      end
    end

    -- Drops the buffer-local value, back to the global list above.
    vim.api.nvim_buf_call(ev.buf, function()
      vim.cmd("setlocal complete<")
    end)
  end,
})

-- Vim's own sql completion is dropped, so `o` finds nothing in a sql buffer
-- and the word sources answer instead.
--
-- It completes table and column names by asking a live database, through the
-- dbext plugin, which is not installed here and is not going to be: I do not
-- want the editor talking to a database as I type. Without dbext every call
-- prints an error and then sits in `:sleep 2`, and 'autocomplete' calls it on
-- the keys I type, so a sql buffer stalls two seconds at a time. Measured: a
-- burst of five characters took 2.08s to land.
--
-- The sleep is also what raised E565 out of ui2's message timer: `:sleep`
-- runs the event loop while completion holds the buffer against changes, so a
-- message on its way out was removed at the one moment that is not allowed.
-- The timer is Neovim's and the missing guard is Neovim's; this only takes
-- away the one thing here that reaches it.
--
-- The flag is the sql ftplugin's own switch and goes first, since the
-- ftplugin reads it while the file type is being set. It turns off thirteen
-- Insert-mode mappings the ftplugin makes on Ctrl+C, all of them ways into
-- the completion below: with them, Ctrl+C in a sql buffer waits to see
-- whether a second key is coming instead of leaving Insert.
vim.g.omni_sql_no_default_maps = 1

vim.api.nvim_create_autocmd("FileType", {
  group = group,
  pattern = "sql",
  desc = "Drop the sql omni-completion, which wants a database behind it",
  callback = function(ev)
    -- Named rather than blanked, so that a language server which got there
    -- first keeps the omnifunc it set.
    if vim.bo[ev.buf].omnifunc == "sqlcomplete#Complete" then
      vim.bo[ev.buf].omnifunc = ""
    end
  end,
})

--- The keys -------------------------------------------------------------------
--
-- Which keys these are is lua/mivn/keymaps.lua's; this is what they do.

local M = {}

--- Whether a match in the open menu is currently highlighted.
local function selected()
  return vim.fn.complete_info({ "selected" }).selected ~= -1
end

--- Accept the highlighted completion, or break the line.
---
--- Acceptance goes through Ctrl+Y, the key the language server hangs its extra
--- edits off. The newline path goes through mini.pairs, which is the
--- integration its own docs ask completion mappings to do; the plugin maps
--- <CR> itself only when nothing else has. MiniPairs.cr() returns raw
--- termcodes, hence vim.keycode() on the other branches. The pcall keeps Enter
--- a plain newline if mini.pairs is ever dropped.
function M.enter()
  if selected() then
    return vim.keycode("<C-y>")
  end

  local ok, pairs = pcall(require, "mini.pairs")
  return ok and pairs.cr() or vim.keycode("<CR>")
end

--- Accept the highlighted completion, or the first one, else jump to the next
--- placeholder, else indent.
---
--- WARN: the placeholder branch is Neovim's own Insert-mode Tab, and taking
--- the key here took it with it. Neovim maps Tab in Insert and Select to
--- vim.snippet.jump when a snippet is live, so accepting a server's snippet
--- and pressing Tab for the next placeholder typed a tab into the middle of
--- the line. Shift+Tab is not mapped here, so jumping back never broke, which
--- is how it went unnoticed.
---
--- The menu comes first, and Zed reads the same way round: its snippet
--- bindings carry `!showing_completions`, so a match beats a placeholder
--- there too.
function M.tab()
  if selected() then
    return "<C-y>"
  end

  if vim.fn.pumvisible() == 1 then
    return "<C-n><C-y>"
  end

  if vim.snippet.active({ direction = 1 }) then
    return "<Cmd>lua vim.snippet.jump(1)<CR>"
  end

  return "<Tab>"
end

--- Close the menu, or stop typing when there is none.
---
--- The menu arrives on its own, so being rid of it should not cost me the mode
--- I am in: this puts back what I typed and leaves me typing, which is Ctrl+E,
--- Vim's own key for it. A second Esc then leaves Insert, where Vim spends the
--- first press on both at once. `<Insert>` is still one press out of typing,
--- menu or no menu.
function M.escape()
  if vim.fn.pumvisible() == 1 then
    return "<C-e>"
  end

  return "<Esc>"
end

-- Ctrl+Space asks for the menu and it arrives stepped in: the top match is
-- highlighted, so Enter takes it and the arrows move from it. It earns its
-- place where the automatic trigger has nothing to go on: a fresh line or just
-- after a space. `<C-n>` rather than `<C-x><C-o>`, so it is the same set of
-- sources as the automatic menu instead of the server alone.
--
-- The menu `<C-n>` opens only shows up after the mapping returns, so the
-- highlight is placed by the CompleteChanged below, armed by `requested`.
-- TextChangedI disarms it when `<C-n>` found nothing: it fires on the next
-- typed character, before 'autocomplete' can open a menu this key never asked
-- for.
local requested = false

-- The highlighted match, remembered because a highlight does not survive a
-- re-fill of the list: a source that answers late (the language server,
-- usually) lands its matches after the menu is already up, and the selection
-- resets to nothing. Measured with a server that takes 1.5s to answer. When
-- that happens the highlight goes back onto its match, wherever the re-fill
-- moved it, or to the top when the match is gone. This guards every
-- highlight, the arrows' included, not only Ctrl+Space's.
--
-- `n` is the length of the list, and it is how a re-fill is told apart from
-- me walking onto the "what I typed" entry, which is also "nothing selected":
-- walking never changes the length.
local kept = nil

--- Highlight the match at `to` and remember it; the line is left alone. The
--- remembering has to happen here: this runs inside CompleteChanged, and
--- autocmds do not nest, so the handler cannot see its own selections.
local function highlight(to, items, n)
  kept = { word = items[to + 1].word, n = n }
  vim.api.nvim_select_popupmenu_item(to, false, false, {})
end

vim.api.nvim_create_autocmd("CompleteChanged", {
  group = group,
  desc = "Step into the menu Ctrl+Space asked for, and stay in it",
  callback = function()
    local info = vim.fn.complete_info({ "selected", "items" })
    local n = #info.items

    if info.selected >= 0 then
      requested = false
      kept = { word = info.items[info.selected + 1].word, n = n }
      return
    end

    if n == 0 then
      return
    end

    if requested then
      requested = false
      highlight(0, info.items, n)
      return
    end

    if not kept then
      return
    end

    if n == kept.n then
      -- Same list, so I walked here on purpose; from now on re-fills leave
      -- the nothing-selected state alone too.
      kept = nil
      return
    end

    local to = 0
    for i, item in ipairs(info.items) do
      if item.word == kept.word then
        to = i - 1
        break
      end
    end

    highlight(to, info.items, n)
  end,
})

vim.api.nvim_create_autocmd({ "CompleteDone", "TextChangedI", "InsertLeave" }, {
  group = group,
  desc = "Forget the menu that just closed, or a Ctrl+Space that found nothing",
  callback = function()
    requested = false
    kept = nil
  end,
})

--- Open the completion menu here, with the top match highlighted.
function M.now()
  if vim.fn.pumvisible() == 1 then
    if not selected() then
      local info = vim.fn.complete_info({ "items" })
      highlight(0, info.items, #info.items)
    end

    return
  end

  requested = true
  vim.api.nvim_feedkeys(vim.keycode("<C-n>"), "n", false)
end

return M
