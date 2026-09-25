-- Formatting, and what happens when I save: organize imports, then format, both
-- through a language server. A language file that names a formatter of its own
-- overrides the server rather than backing it up, on save and by hand alike,
-- since a server having a formatter does not make it the right one.
--
-- Such a command reads the file on stdin and writes it to stdout.

local M = {}

--- A sentinel no real argument can collide with, replaced by the buffer's path
--- when a formatter's command is built.
M.FILE = "\0file\0"

--- Filled by setup(): filetype to formatter, and the servers never asked to
--- format.
local formatters, muted = {}, {}

--- The formatter for `filetype`, or nil. A dotted filetype is looked up whole
--- and then with its last part dropped, one at a time, so `yaml.docker-compose`
--- falls back to yaml's.
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

--- Make `buf` read `new`, touching only the lines that differ, so marks,
--- extmarks and the cursor stay with their text rather than their line number.
--- Hunks go in from the bottom up, so each one's line numbers still hold when
--- it lands.
function M.replace(buf, new)
  local old = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local hunks = vim.text.diff(table.concat(old, "\n") .. "\n", table.concat(new, "\n") .. "\n", {
    result_type = "indices",
  }) --[[@as integer[][] ]]

  for i = #hunks, 1, -1 do
    local old_start, old_count, new_start, new_count = unpack(hunks[i])

    -- a pure insertion names the line it goes after
    if old_count == 0 then
      old_start = old_start + 1
    end

    local lines = vim.list_slice(new, new_start, new_start + new_count - 1)
    vim.api.nvim_buf_set_lines(buf, old_start - 1, old_start - 1 + old_count, false, lines)
  end
end

--- Format `buf` with its language's own formatter. Returns whether there is
--- one. Synchronous, since the write that follows has to see the result.
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

  -- beside the file, since taplo, yamlfmt and the like look for their config
  -- from the working directory up
  local cwd = path ~= "" and vim.fs.dirname(path) or nil

  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local result = vim
    .system(cmd, {
      cwd = cwd,
      stdin = table.concat(lines, "\n") .. "\n",
      text = true,
    })
    :wait(3000)

  -- a failed run's stdout is empty or half a file, and must not replace mine
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
    M.replace(buf, new)
  end

  return true
end

local ORGANIZE_IMPORTS = "source.organizeImports"

--- Whether `kind` is the imports action that was asked for, or a refinement of
--- it (`source.organizeImports.ts`).
---
--- NOTE: the request names the kind, but a server may answer with anything.
--- marksman answers with its "Create a Table of Contents" action, kind
--- `source`, which applied on every write puts a table of contents in every
--- markdown file I save.
local function organizes_imports(kind)
  kind = kind or ""
  return kind == ORGANIZE_IMPORTS or kind:sub(1, #ORGANIZE_IMPORTS + 1) == ORGANIZE_IMPORTS .. "."
end

--- The clients attached to `buf`, sorted by id.
---
--- NOTE: most files here have more than one server (gopls and
--- golangci-lint-langserver, ruff and ty), and vim.lsp.get_clients() returns
--- them in table order. Anything that picks one has to sort first, or it picks
--- a different one from one session to the next.
local function clients_of(buf)
  local clients = vim.lsp.get_clients({ bufnr = buf })
  table.sort(clients, function(a, b)
    return a.id < b.id
  end)

  return clients
end

--- Whether `client` answers codeAction/resolve.
---
--- NOTE: not client:supports_method(), which says yes to any method it has no
--- capability mapped for, and this is one of them. Only the table shape of the
--- capability can carry the answer.
local function resolves_actions(client)
  local provider = client.server_capabilities.codeActionProvider

  return type(provider) == "table" and provider.resolveProvider == true
end

--- The workspace edit `action` carries, asking the server for it when it
--- carries none, or nil.
---
--- NOTE: a server may answer with the action's `data` and no edit, meaning "ask
--- me again with this". ruff does, since Neovim says it can resolve the edit,
--- so without this step Python imports are never organized and nothing says so.
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
--- NOTE: only the first. A second server's edit is computed against the
--- document from before the first one's lands, so applying both writes a stale
--- edit over a fresh one.
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

--- The first of `clients` that may format, or nil.
---
--- NOTE: one server, named by id. vim.lsp.buf.format() runs every client that
--- passes its filter, each over the last one's edits, so two would format the
--- file twice against a document only one of them has seen. `format = false` in
--- a language file keeps a server out.
local function formatter_of(clients)
  for _, client in ipairs(clients) do
    if not muted[client.name] and client:supports_method("textDocument/formatting") then
      return client
    end
  end

  return nil
end

--- Format `buf` with the server chosen for it, if there is one; without one,
--- vim.lsp.buf.format() complains on every markdown write.
local function by_server(buf)
  local chosen = formatter_of(clients_of(buf))
  if chosen then
    vim.lsp.buf.format({ bufnr = buf, id = chosen.id, timeout_ms = 2000 })
  end
end

--- Format `buf` (the current buffer by default) now: with its language's own
--- formatter when there is one, otherwise with the one server that may. Unlike
--- a write, this runs in an untrusted workspace too, since I asked.
function M.buffer(buf)
  buf = buf or vim.api.nvim_get_current_buf()

  if not external(buf) then
    by_server(buf)
  end
end

--- Organize `buf`'s imports (the current buffer by default) now.
function M.imports(buf)
  buf = buf or vim.api.nvim_get_current_buf()

  organize_imports(buf, clients_of(buf))
end

--- Wire the save chain. `spec` maps filetype to formatter command; `silent` is
--- the set of server names never asked to format.
---
--- Muting is by name because a capability can be wrong: nvim-lspconfig's yamlls
--- turns formatting back on in `on_init`, since the server reports false while
--- it still formats.
function M.setup(spec, silent)
  formatters, muted = spec, silent

  local group = vim.api.nvim_create_augroup("mivn.format", { clear = true })

  vim.api.nvim_create_autocmd("BufWritePre", {
    group = group,
    callback = function(ev)
      -- nothing runs on save in a workspace I have not trusted
      local trust = require("mivn.trust")
      if not trust.allows(trust.workspace()) then
        return
      end

      -- a language's own formatter owns the write; otherwise imports go first,
      -- since they edit what the formatter is about to lay out
      if external(ev.buf) then
        return
      end

      M.imports(ev.buf)
      by_server(ev.buf)
    end,
  })
end

return M
