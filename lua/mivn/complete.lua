-- Completion in Insert mode: the menu opens by itself as I type, the arrows
-- walk it, Enter and Tab take a match. No plugin: it is Neovim's own
-- 'autocomplete', with the language server as one of its sources.

--- What the menu is made of --------------------------------------------------

-- 'autocompletedelay' stays 0, since the wait is already the language server's
-- round trip.
vim.o.autocomplete = true

-- The sources, in priority order: `o` is the language server through
-- 'omnifunc'; `.`, `w` and `b` are words from this buffer, other windows and
-- the rest of the buffer list, ten matches each so a long file does not push
-- the server's off the end. A buffer with a completing server narrows to `o`
-- alone (below). `u` would read unloaded buffers off disk as I type, and `t`
-- wants a tags file I never generate.
vim.opt.complete = { "o", ".^10", "w^10", "b^10" }

-- `menuone` and `noselect` so nothing goes in until I choose it, which leaves
-- Enter free to break the line; `popup` for the docs, and `fuzzy` so "nsl"
-- finds "nvim_set_lines". 'autocomplete' sets `noselect` itself and ignores
-- `menuone`, but Ctrl+X completion still reads both.
vim.o.completeopt = "menuone,noselect,popup,fuzzy"

--- The language server's half ------------------------------------------------

-- `enable` makes accepting a match do what comes with it: expand a snippet,
-- apply its extra edits (the import for the symbol I picked), resolve the docs
-- in the popup. No `autotrigger`, since 'autocomplete' already fires on the
-- server's trigger characters and the two would race on the same one.
local group = vim.api.nvim_create_augroup("mivn.complete", { clear = true })

vim.api.nvim_create_autocmd("LspAttach", {
  group = group,
  callback = function(ev)
    local client = vim.lsp.get_client_by_id(ev.data.client_id)
    if client and client:supports_method("textDocument/completion") then
      vim.lsp.completion.enable(true, ev.data.client_id, ev.buf)

      -- the server alone, since words would repeat its matches without their
      -- signatures and Vim does not drop duplicates across sources
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

    -- back to the global list
    vim.api.nvim_buf_call(ev.buf, function()
      vim.cmd("setlocal complete<")
    end)
  end,
})

-- Vim's own sql completion is dropped, so the word sources answer in a sql
-- buffer. It asks a live database through the dbext plugin, which I do not
-- want; without dbext every call prints an error and sleeps two seconds, on
-- every key 'autocomplete' fires on. That sleep also runs the event loop while
-- completion locks the buffer, which raised E565 from ui2's message timer.
--
-- The flag goes first, since the sql ftplugin reads it while the filetype is
-- being set. It turns off the ftplugin's Ctrl+C mappings in Insert, which make
-- Ctrl+C wait for a second key instead of leaving Insert.
vim.g.omni_sql_no_default_maps = 1

vim.api.nvim_create_autocmd("FileType", {
  group = group,
  pattern = "sql",
  desc = "Drop the sql omni-completion, which wants a database behind it",
  callback = function(ev)
    -- only the sql one, so a server that got here first keeps its omnifunc
    if vim.bo[ev.buf].omnifunc == "sqlcomplete#Complete" then
      vim.bo[ev.buf].omnifunc = ""
    end
  end,
})

--- The keys -------------------------------------------------------------------

local M = {}

--- Whether a match in the open menu is currently highlighted.
local function selected()
  return vim.fn.complete_info({ "selected" }).selected ~= -1
end

--- Accept the highlighted completion with Ctrl+Y, which applies the server's
--- extra edits, or break the line through mini.pairs, as its docs ask of a
--- mapping that takes Enter.
---
--- NOTE: MiniPairs.cr() returns raw termcodes and the mapping does not replace
--- keycodes, so the Ctrl+Y branch has to be vim.keycode() too.
function M.enter()
  if selected() then
    return vim.keycode("<C-y>")
  end

  return require("mini.pairs").cr()
end

--- Accept the highlighted completion, or the first one, else jump to the next
--- snippet placeholder, else indent. The menu wins over a placeholder.
---
--- NOTE: the snippet branch stands in for Neovim's own Insert-mode Tab, which
--- jumps while a snippet is live and which this mapping replaces. Without it,
--- Tab types a tab into the middle of an expanded snippet.
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
--- NOTE: over the menu this is Ctrl+E, which puts back what I typed and keeps
--- me typing; Vim's Esc would close the menu and leave Insert at once. The menu
--- arrives on its own, so being rid of it should not cost me the mode.
function M.escape()
  if vim.fn.pumvisible() == 1 then
    return "<C-e>"
  end

  return "<Esc>"
end

-- Set by M.now() until the menu it asked for opens. That menu appears only
-- after the mapping returns, so the CompleteChanged below highlights its top
-- match. TextChangedI clears it when nothing matched, before 'autocomplete' can
-- open a menu M.now() never asked for.
local requested = false

-- The highlighted match and the list's length. A source that answers late
-- re-fills the menu and the highlight drops to nothing, so it goes back onto
-- its match, or the top when the match is gone. The length tells a re-fill
-- apart from me walking onto the "what I typed" entry, which is also no
-- selection: walking never changes it.
local kept = nil

--- Highlight the match at `to` without inserting it, and remember it.
---
--- NOTE: the remembering has to happen here. This runs inside CompleteChanged
--- and autocmds do not nest, so the handler never sees its own selections.
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
      -- same length, so I walked here; leave later re-fills alone too
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

--- Open the completion menu here, with the top match highlighted. It is `<C-n>`
--- rather than `<C-x><C-o>`, so the sources are the automatic menu's and not
--- the server's alone.
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
