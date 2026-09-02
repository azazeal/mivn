-- Formatting, and what happens when I save.
--
-- Most of it *is* the language server: organize imports, then format. The
-- exception is a language whose file in this directory names a formatter of
-- its own, and that is an **override**, not a fallback: a server having a
-- formatter does not make it the right one.
--
-- The same two halves are <leader>af and <leader>aF, so a formatting asked
-- for by hand and one that happens on a write are the same code and cannot
-- drift into disagreeing about which tool owns a filetype.
--
-- Each such command must read the file on stdin and write it to stdout. FILE
-- stands for the buffer's path where a tool needs it, usually to find its own
-- config.

local M = {}

--- A sentinel no real argument can collide with, replaced by the buffer's
--- path when the command is built.
M.FILE = "\0file\0"

--- Filetype to the command that formats it, and the servers that must never
--- be asked. Both arrive from the language files through setup() below.
local formatters, muted = {}, {}

--- The formatter for `filetype`, or nil.
---
--- A dotted file type is "this, then more specific" (`yaml.docker-compose` is
--- yaml first), so the whole name is looked up and then each part in front of
--- a dot, nearest first. Looked up whole alone, a compose file matched nothing
--- and was never formatted (measured 2026-09-03).
local function formatter_for(filetype)
  local spec = formatters[filetype]

  while spec == nil do
    local shorter = filetype:match("^(.*)%.[^.]*$")
    if not shorter then
      return nil
    end

    filetype = shorter
    spec = formatters[filetype]
  end

  return spec
end

--- Format `buf` with its external formatter. Returns whether one ran.
---
--- Synchronous: these all read stdin, so there is no file on disk to wait
--- for, and the write that follows has to see the result.
local function external(buf)
  local spec = formatter_for(vim.bo[buf].filetype)
  if type(spec) == "function" then
    spec = spec(buf)
  end

  if not spec or vim.fn.executable(spec[1]) ~= 1 then
    return false
  end

  local path = vim.api.nvim_buf_get_name(buf)
  local cmd = vim.tbl_map(function(arg)
    return arg == M.FILE and path or arg
  end, spec)

  -- Run beside the file, not where the editor started. Every one of these
  -- tools that reads a project's configuration looks for it from its working
  -- directory upwards (taplo and yamlfmt among them), so a file from another
  -- checkout was formatted by this checkout's rules; lua/mivn/languages/
  -- markdown.lua walks for rumdl's by hand for the same reason. A buffer with
  -- no file behind it keeps the editor's directory.
  local cwd = path ~= "" and vim.fs.dirname(path) or nil

  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local result = vim
    .system(cmd, {
      cwd = cwd,
      stdin = table.concat(lines, "\n") .. "\n",
      text = true,
    })
    :wait(3000)

  -- A formatter that fails was usually handed something it cannot parse, so
  -- its stdout is empty or half a file; writing that over the buffer would
  -- destroy the work that caused it.
  if result.code ~= 0 or (result.stdout or "") == "" then
    local reason = vim.trim(result.stderr or "")
    vim.notify(("%s: %s"):format(spec[1], reason ~= "" and reason or "no output"), vim.log.levels.WARN)
    return true
  end

  local new = vim.split(result.stdout, "\n")
  if new[#new] == "" then
    table.remove(new)
  end

  if not vim.deep_equal(new, lines) then
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, new)
  end

  return true
end

local ORGANIZE_IMPORTS = "source.organizeImports"

--- Whether `kind` is the imports action that was asked for, or a refinement
--- of it.
---
--- The request already names the kind it wants, and this checks the answer
--- again, because a server is free to reply with whatever it likes. marksman
--- answers a source.organizeImports request with its "Create a Table of
--- Contents" action, kind `source`, and applying that on every write grew a
--- table of contents in every markdown file this editor had ever saved, in
--- silence. Kinds are dotted and hierarchical, so a refinement of the kind
--- asked for counts (source.organizeImports.ts) and a parent of it does not.
local function organizes_imports(kind)
  kind = kind or ""
  return kind == ORGANIZE_IMPORTS or kind:sub(1, #ORGANIZE_IMPORTS + 1) == ORGANIZE_IMPORTS .. "."
end

--- The clients attached to `buf`, in a settled order.
---
--- More than one server attaches to most files here: gopls and
--- golangci-lint-langserver both claim Go, ruff and ty both claim Python, the
--- two HTML servers both claim HTML. vim.lsp.get_clients() hands them back in
--- whatever order the table iterates, so anything that picks one has to sort
--- first or it picks a different one on different days.
local function clients_of(buf)
  local clients = vim.lsp.get_clients({ bufnr = buf })
  table.sort(clients, function(a, b)
    return a.id < b.id
  end)

  return clients
end

--- Whether `client` answers codeAction/resolve.
---
--- Not client:supports_method, which returns true for any method it has no
--- capability mapped for, and codeAction/resolve is one of those. The
--- capability itself is a boolean or a table, so only the table shape can
--- carry the answer.
local function resolves_actions(client)
  local provider = client.server_capabilities.codeActionProvider

  return type(provider) == "table" and provider.resolveProvider == true
end

--- The workspace edit `action` carries, asking for it when it carries none.
---
--- A server may answer with the action's `data` and no edit at all, which
--- means "ask me again with this and I will compute it". ruff does exactly
--- that, and only when the client says it can cope, which this one does: the
--- edit is in Neovim's resolveSupport list, so ruff takes it out of the first
--- answer. So Python imports were never organised, on save or by hand,
--- silently, since the action was there and the edit inside it was not.
--- gopls hides the same shape by filling the edit in eagerly.
local function edit_of(client, action, buf)
  if action.edit then
    return action.edit
  end

  if not action.data or not resolves_actions(client) then
    return nil
  end

  local resolved = client:request_sync("codeAction/resolve", action, 1000, buf)

  return ((resolved or {}).result or {}).edit
end

--- Organize `buf`'s imports with the first attached server that offers it.
---
--- The first, and then it stops. Two servers organizing the same file is not
--- something that should happen, and if it did the second one's edit was
--- computed against the document as it stood before the first one's landed,
--- so applying both writes a stale edit over a fresh one.
local function organize_imports(buf, clients)
  for _, client in ipairs(clients) do
    if client:supports_method("textDocument/codeAction") then
      local params = vim.tbl_extend("force", vim.lsp.util.make_range_params(0, client.offset_encoding), {
        context = { only = { ORGANIZE_IMPORTS }, diagnostics = {} },
      })

      local responses = client:request_sync("textDocument/codeAction", params, 1000, buf)
      for _, action in pairs((responses or {}).result or {}) do
        if organizes_imports(action.kind) then
          local edit = edit_of(client, action, buf)
          if edit then
            vim.lsp.util.apply_workspace_edit(edit, client.offset_encoding)
            return
          end
        end
      end
    end
  end
end

--- The one server that may format `buf`, or nil.
---
--- One, named outright. vim.lsp.buf.format() runs *every* client that
--- matches, applying each one's edits over the last, so handing it a filter
--- that two servers pass formats the file twice against a document only one
--- of them has seen. `format = false` in a language file is how the wrong one
--- steps aside.
local function formatter_of(clients)
  for _, client in ipairs(clients) do
    if not muted[client.name] and client:supports_method("textDocument/formatting") then
      return client
    end
  end

  return nil
end

--- Format `buf` with the server chosen for it, if any.
---
--- Only when one of them can: vim.lsp.buf.format says "no matching language
--- servers" into the message area otherwise, which would be every markdown
--- write, marksman being attached and offering no formatter.
local function by_server(buf)
  local chosen = formatter_of(clients_of(buf))
  if chosen then
    vim.lsp.buf.format({ bufnr = buf, id = chosen.id, timeout_ms = 2000 })
  end
end

--- Format `buf` now: its language's own formatter when there is one, and the
--- one server that may otherwise. <leader>af in lua/mivn/keymaps.lua.
---
--- Not gated on the workspace being trusted, unlike the write below. This one
--- was asked for by hand, and its language-server half cannot run in an
--- untrusted workspace anyway, there being no server attached to ask.
function M.buffer(buf)
  buf = buf or vim.api.nvim_get_current_buf()

  if not external(buf) then
    by_server(buf)
  end
end

--- Organize `buf`'s imports now; <leader>aF in lua/mivn/keymaps.lua.
function M.imports(buf)
  buf = buf or vim.api.nvim_get_current_buf()

  organize_imports(buf, clients_of(buf))
end

--- Wire the save chain. `spec` is filetype to command, collected from the
--- language files; `silent` is the set of server names that must never be
--- asked to format, whatever they claim to support.
---
--- Muting is by name rather than by capability because a capability can be a
--- lie: nvim-lspconfig's yamlls config sets `documentFormattingProvider` back
--- to true in `on_init`, since the server reports false while still
--- formatting.
function M.setup(spec, silent)
  formatters, muted = spec, silent

  local group = vim.api.nvim_create_augroup("mivn.format", { clear = true })

  vim.api.nvim_create_autocmd("BufWritePre", {
    group = group,
    callback = function(ev)
      -- Nothing runs on save in a workspace I have not trusted. The server
      -- half of this is already covered, since none is even started there,
      -- and the formatters are named here rather than by the project; the
      -- rule is the one that stays right the day one of them starts reading
      -- a project's own configuration for plugins to load.
      local trust = require("mivn.trust")
      if not trust.allows(trust.workspace()) then
        return
      end

      -- A language that names a formatter of its own owns the write end to
      -- end; nothing after this runs for it. Otherwise imports first, since
      -- that edits the same region the formatter is about to lay out.
      if external(ev.buf) then
        return
      end

      M.imports(ev.buf)
      by_server(ev.buf)
    end,
  })
end

return M
