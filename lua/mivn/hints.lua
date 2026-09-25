-- The inlay hints, drawn wherever a server offers them. Go starts with them
-- hidden: it infers a type on nearly every line and passes arguments by
-- position, so its hints cover most of the file.
--
-- The toggle is per buffer and lasts until the server attaches again
-- (`:LspRestart`, a crash), when the language's default comes back.

local M = {}

--- The filetypes that start with the hints hidden.
local QUIET = { go = true }

--- Whether anything attached to `bufnr` offers hints, so the toggle does not
--- report a state nothing on screen shows.
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

    -- the first server with hints decides, so a later one cannot undo a toggle
    for _, other in ipairs(vim.lsp.get_clients({ bufnr = ev.buf, method = "textDocument/inlayHint" })) do
      if other.id ~= client.id then
        return
      end
    end

    vim.lsp.inlay_hint.enable(not QUIET[vim.bo[ev.buf].filetype], { bufnr = ev.buf })
  end,
})

--- The keys ------------------------------------------------------------------

--- Draw this buffer's inlay hints, or stop, and say which: a buffer with
--- nothing to hint looks the same either way.
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

--- Whether this buffer is drawing its inlay hints.
function M.on()
  return vim.lsp.inlay_hint.is_enabled({ bufnr = 0 })
end

return M
