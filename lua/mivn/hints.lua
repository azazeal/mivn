-- The inlay hints: what the server worked out so that I did not have to
-- write it. A type behind a `:=`, the name of the parameter an argument is
-- going into, the error a statement drops on the floor. Neovim draws none of
-- them until it is asked, and this asks wherever a server offers them.
--
-- Go is the one language that starts with them hidden. gopls is asked for
-- all eight kinds (lua/mivn/languages/go.lua) and each one is worth reading,
-- but Go infers a type on nearly every line and passes its arguments by
-- position, so the eight together put something on most of the file and the
-- code stops being the thing on screen. Hidden is what I want walking into a
-- Go file, and <leader>tn is there for the one I am lost in.
--
-- The answer belongs to a buffer and not to the session, because it is a
-- question about the file in front of me. It does not outlive the server
-- reattaching either, which is what `:LspRestart` and a server that fell
-- over both do: the language's own default comes back, since the autocmd
-- below is the only thing that ever sets one.
--
-- How loud they read is the LspInlayHint highlight group, in
-- colors/basalt.lua.

local M = {}

--- The filetypes that start with the hints hidden.
local QUIET = { go = true }

--- Whether anything attached to `bufnr` has hints to offer at all. Without
--- this the toggle would report a state nothing on screen agrees with.
local function offered(bufnr)
  return #vim.lsp.get_clients({ bufnr = bufnr, method = "textDocument/inlayHint" }) > 0
end

vim.api.nvim_create_autocmd("LspAttach", {
  group = vim.api.nvim_create_augroup("mivn.hints", { clear = true }),
  desc = "Draw the hints a server offers, unless the language starts quiet",
  callback = function(ev)
    local client = vim.lsp.get_client_by_id(ev.data.client_id)

    if not client or not client:supports_method("textDocument/inlayHint") then
      return
    end

    vim.lsp.inlay_hint.enable(not QUIET[vim.bo[ev.buf].filetype], { bufnr = ev.buf })
  end,
})

--- The keys ------------------------------------------------------------------
--
-- lua/mivn/keymaps.lua binds this; the behavior is here.

--- Draw this buffer's inlay hints, or stop; <leader>tn.
---
--- It says which way it went, since a buffer whose server has nothing to hint
--- about looks the same either way.
function M.toggle()
  local bufnr = vim.api.nvim_get_current_buf()

  if not offered(bufnr) then
    vim.notify("No language server here offers inlay hints", vim.log.levels.WARN)
    return
  end

  local on = not vim.lsp.inlay_hint.is_enabled({ bufnr = bufnr })

  vim.lsp.inlay_hint.enable(on, { bufnr = bufnr })

  vim.notify(("Inlay hints: %s"):format(on and "on" or "off"))
end

--- Whether this buffer is drawing them, for the flags line under <leader>t?.
function M.on()
  return vim.lsp.inlay_hint.is_enabled({ bufnr = 0 })
end

return M
