-- Language servers, and what happens when I save.
--
-- Neovim ships the LSP client; nvim-lspconfig only supplies each server's
-- connection details. A server whose binary is not installed is skipped
-- quietly, and that must never become an error: no server means no LSP for
-- that language while tree-sitter carries on. `:MivnServers` lists both.
--
-- Format on save lives here because most of it *is* the language server:
-- organize imports, then format. Completion is in lua/mivn/complete.lua.

--- Which server handles what, and what binary proves it is installed ---------

-- Keys are nvim-lspconfig's names. Values are the executable to look for,
-- which is usually but not always the same string.
local servers = {
  gopls = "gopls",
  golangci_lint_ls = "golangci-lint-langserver", -- lint diagnostics beside gopls
  rust_analyzer = "rust-analyzer",
  expert = "expert", -- Elixir
  lua_ls = "lua-language-server",

  jsonls = "vscode-json-language-server",
  jsonnet_ls = "jsonnet-language-server",
  yamlls = "yaml-language-server",
  lemminx = "lemminx", -- XML
  taplo = "taplo", -- TOML

  bashls = "bash-language-server",
  buf_ls = "buf", -- Protocol Buffers
  cssls = "vscode-css-language-server",
  dockerls = "docker-langserver",
  html = "vscode-html-language-server",
  marksman = "marksman", -- Markdown
  nil_ls = "nil", -- Nix
  pyright = "pyright-langserver",
  ruby_lsp = "ruby-lsp",
  templ = "templ",
  terraformls = "terraform-ls",
  ts_ls = "typescript-language-server",
}

--- Local overrides ------------------------------------------------------------

-- The personal knobs that do not belong in a public config. lua/mivn/local.lua
-- is optional, gitignored, and returns a table. The keys so far:
--
--   go_import_prefixes   the Go import prefixes that count as ours, as a
--                        list: each earns a gci block of its own, between
--                        everything-else and this module, in the order
--                        listed, and gopls' `local` gets the same set. Empty
--                        or absent, imports group as standard / everything
--                        else / this module. Different checkouts want
--                        different prefixes, so this key usually lives under
--                        `projects`, which scopes it by where Neovim started.
--
--   lsp_servers          changes to the server table above, nvim-lspconfig
--                        name to binary. A new pair adds a server, a different
--                        binary re-points one, and `false` drops one.
--
--   lsp_settings         per-server settings, deep-merged over the defaults
--                        this file ships, so a key here wins.
--
--   lsp_probes           how :checkhealth mivn (lua/mivn/health.lua) asks a
--                        binary for its version; see local.example.lua.
--
-- Any key can also be scoped to a directory through local.lua's `projects`
-- table; lua/mivn/overrides.lua resolves that against the startup directory,
-- and local.example.lua shows every shape.
local overrides = require("mivn.overrides")

-- One list for the whole session, like every other override: `projects` in
-- local.lua is the scoping mechanism, resolved by where Neovim started. The
-- cost is deliberate and small: a file from another workspace edited in this
-- session gets this workspace's blocks.
local import_prefixes = overrides.go_import_prefixes or {}

for server, binary in pairs(overrides.lsp_servers or {}) do
  servers[server] = binary ~= false and binary or nil
end

--- Per-server settings -------------------------------------------------------

-- The codelenses are the ones I use.
--
-- `local` groups our prefixes into one block ahead of the module's own; gci
-- re-splits the file afterwards and owns the final layout, so this mostly
-- matters when gci is not installed.
vim.lsp.config("gopls", {
  settings = {
    gopls = {
      -- Quoted because `local` is a Lua keyword and cannot be a bare key.
      ["local"] = table.concat(import_prefixes, ","),
      codelenses = {
        generate = true,
        regenerate_cgo = true,
        test = true,
        tidy = true,
        upgrade_dependency = true,
        vendor = true,
        vulncheck = true,
      },
      hints = { parameterNames = true, constantValues = true },

      -- What colors a package qualifier in call position: tree-sitter cannot
      -- tell `pkg.Exec(...)` from a variable. gopls sends no semantic tokens
      -- unless asked.
      semanticTokens = true,
    },
  },
})

-- Clippy rather than `cargo check`: same compiler front end plus several
-- hundred extra lints. No `checkOnSave` beside it, since that defaults to
-- true.
--
-- The cost: clippy and `cargo check` do not share a build cache, so the first
-- save in a session recompiles the dependency graph under clippy's flags.
vim.lsp.config("rust_analyzer", {
  settings = {
    -- The hyphen is rust-analyzer's own spelling of its settings root, so the
    -- key has to be quoted the way gopls' `local` above does.
    ["rust-analyzer"] = {
      check = { command = "clippy" },
    },
  },
})

-- schemastore.org's catalog, so .golangci.yml or package.json is validated
-- with nothing declared by hand. yamlls' own downloader is turned off.
local ok_schemastore, schemastore = pcall(require, "schemastore")
if ok_schemastore then
  vim.lsp.config("jsonls", {
    settings = {
      json = {
        schemas = schemastore.json.schemas(),
        validate = { enable = true },
      },
    },
  })

  vim.lsp.config("yamlls", {
    settings = {
      yaml = {
        schemaStore = { enable = false, url = "" },
        schemas = schemastore.yaml.schemas(),
      },
    },
  })
end

vim.lsp.config("lua_ls", {
  settings = {
    Lua = {
      runtime = { version = "LuaJIT" },
      workspace = {
        checkThirdParty = false,
        library = { vim.env.VIMRUNTIME },
      },
      telemetry = { enable = false },
    },
  },
})

-- Personal settings last, so they win: vim.lsp.config() merges repeated
-- calls, later ones taking precedence, which is the whole implementation.
for server, settings in pairs(overrides.lsp_settings or {}) do
  vim.lsp.config(server, { settings = settings })
end

--- Start whatever is actually installed --------------------------------------

-- A server that dies right after starting otherwise fails in silence: the
-- client detaches, features quietly stop, and nothing says why. Measured
-- with rust-analyzer behind a rustup shim with no component installed:
-- executable() said yes, the process recursed and died, and :MivnServers
-- kept reporting it on. Once per server per session, and not on shutdown.
local exit_warned = {}

vim.lsp.config("*", {
  on_exit = function(code, _, client_id)
    if code == 0 or vim.v.exiting ~= vim.NIL then
      return
    end

    local client = vim.lsp.get_client_by_id(client_id)
    local name = client and client.name or ("client %d"):format(client_id)
    if exit_warned[name] then
      return
    end
    exit_warned[name] = true

    -- Scheduled, because on_exit can run in a fast context.
    vim.schedule(function()
      vim.notify(("%s exited with code %d. :checkhealth mivn has details."):format(name, code), vim.log.levels.WARN)
    end)
  end,
})

local enabled = {}
for server, binary in pairs(servers) do
  if vim.fn.executable(binary) == 1 then
    enabled[#enabled + 1] = server
  end
end
table.sort(enabled)
vim.lsp.enable(enabled)

vim.api.nvim_create_user_command("MivnServers", function()
  local lines = {}
  for server, binary in vim.spairs(servers) do
    local mark = vim.fn.executable(binary) == 1 and "on " or "off"
    lines[#lines + 1] = ("  %s %-16s %s"):format(mark, server, binary)
  end
  vim.notify("Language servers\n" .. table.concat(lines, "\n"))
end, { desc = "Show which language servers are installed and which are missing" })

--- Inlay hints ----------------------------------------------------------------

-- The facts the server inferred, drawn dimly inline. Neovim leaves this off;
-- the dial for how loud they read is the LspInlayHint highlight group.
vim.api.nvim_create_autocmd("LspAttach", {
  group = vim.api.nvim_create_augroup("mivn.lsp.hints", { clear = true }),
  callback = function(ev)
    local client = vim.lsp.get_client_by_id(ev.data.client_id)
    if client and client:supports_method("textDocument/inlayHint") then
      vim.lsp.inlay_hint.enable(true, { bufnr = ev.buf })
    end
  end,
})

--- Diagnostics ---------------------------------------------------------------

-- The message for the line I am on is drawn *under* it rather than after it:
-- 'virtual_text' gets whatever space is left at the end of the line, which
-- truncates a rust-analyzer type mismatch where it starts to say something.
--
-- The trade is movement: text below the cursor is pushed down while a
-- diagnostic is open and springs back as I leave the line. `current_line`
-- keeps that to one place at a time; every other diagnostic stays a letter in
-- the sign column.
vim.diagnostic.config({
  severity_sort = true,
  virtual_lines = { current_line = true },
  underline = true,
  signs = {
    text = {
      [vim.diagnostic.severity.ERROR] = "E",
      [vim.diagnostic.severity.WARN] = "W",
      [vim.diagnostic.severity.INFO] = "I",
      [vim.diagnostic.severity.HINT] = "H",
    },
  },
  float = { border = "rounded", source = true },
})

--- Format on save ------------------------------------------------------------

local group = vim.api.nvim_create_augroup("mivn.lsp.format", { clear = true })

-- gci's import blocks, in output order: standard library, everything else, a
-- block per prefix from the local overrides, then this module's own packages
-- (`localmodule` reads that from go.mod). gopls runs first, gci owns the end.
local gci_sections = { "standard", "default" }
for _, prefix in ipairs(import_prefixes) do
  gci_sections[#gci_sections + 1] = ("Prefix(%s)"):format(prefix)
end
gci_sections[#gci_sections + 1] = "localmodule"

--- Re-split a saved Go file's imports with gci, in place.
---
--- Runs after the write, not before, because gci resolves `localmodule` by
--- walking up from the file to its go.mod, which a temp copy elsewhere would
--- not find. Spliced back with nvim_buf_set_lines rather than reloaded, so the
--- change joins the undo history instead of clearing it.
local function gci_format(buf)
  if vim.fn.executable("gci") ~= 1 then
    return
  end

  local path = vim.api.nvim_buf_get_name(buf)
  local cmd = { "gci", "write", "--skip-generated", "--custom-order" }
  for _, section in ipairs(gci_sections) do
    cmd[#cmd + 1] = "-s"
    cmd[#cmd + 1] = section
  end
  cmd[#cmd + 1] = path

  vim.system(cmd, { text = true }, function(result)
    if result.code ~= 0 then
      return
    end

    vim.schedule(function()
      if not vim.api.nvim_buf_is_valid(buf) then
        return
      end

      local file = io.open(path, "r")
      if not file then
        return
      end
      local content = file:read("*a")
      file:close()

      local new = vim.split(content, "\n")
      if new[#new] == "" then
        table.remove(new)
      end

      if not vim.deep_equal(new, vim.api.nvim_buf_get_lines(buf, 0, -1, false)) then
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, new)
        vim.bo[buf].modified = false
      end
    end)
  end)
end

--- Formatters that are not language servers ----------------------------------
--
-- An entry here is an **override**, not a fallback: it wins over the language
-- server, because a server having a formatter does not make it the right one.
--
-- Each command must read the file on stdin and write it to stdout. FILE stands
-- for the buffer's path where a tool needs it, usually to find its own config.

local FILE = "\0file\0" -- a sentinel no real argument can collide with

local formatters = {
  lua = { "stylua", "--stdin-filepath", FILE, "-" },

  -- shfmt reads .editorconfig itself when it is given no formatting flags,
  -- which is why it gets the filename and nothing else.
  sh = { "shfmt", "--filename", FILE },
  bash = { "shfmt", "--filename", FILE },

  toml = { "taplo", "format", "-" },

  -- Adds an <?xml?> declaration to a file that has none.
  xml = { "xmllint", "--format", "-" },

  -- jq knows nothing about EditorConfig, so the indent is handed to it from
  -- the buffer, where EditorConfig has settled it. `--indent` caps at 7.
  json = function(buf)
    if not vim.bo[buf].expandtab then
      return { "jq", "--tab", "." }
    end

    local width = vim.bo[buf].shiftwidth
    if width == 0 then
      width = vim.bo[buf].tabstop
    end

    return { "jq", "--indent", tostring(math.min(width, 7)), "." }
  end,
}

--- Format `buf` with its external formatter. Returns whether one ran.
---
--- Synchronous, unlike gci: these all read stdin, so there is no file on disk
--- to wait for, and the write that follows has to see the result.
local function external_format(buf)
  local spec = formatters[vim.bo[buf].filetype]
  if type(spec) == "function" then
    spec = spec(buf)
  end

  if not spec or vim.fn.executable(spec[1]) ~= 1 then
    return false
  end

  local path = vim.api.nvim_buf_get_name(buf)
  local cmd = vim.tbl_map(function(arg)
    return arg == FILE and path or arg
  end, spec)

  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local result = vim
    .system(cmd, {
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

vim.api.nvim_create_autocmd("BufWritePre", {
  group = group,
  callback = function(ev)
    if external_format(ev.buf) then
      return
    end

    local clients = vim.lsp.get_clients({ bufnr = ev.buf })
    if #clients == 0 then
      return
    end

    -- Organize imports first, because it edits the same region the formatter
    -- is about to lay out. A server that does not offer it no-ops.
    for _, client in ipairs(clients) do
      if client:supports_method("textDocument/codeAction") then
        local params = vim.tbl_extend("force", vim.lsp.util.make_range_params(0, client.offset_encoding), {
          context = { only = { "source.organizeImports" }, diagnostics = {} },
        })

        local responses = client:request_sync("textDocument/codeAction", params, 1000, ev.buf)
        for _, action in pairs((responses or {}).result or {}) do
          if action.edit then
            vim.lsp.util.apply_workspace_edit(action.edit, client.offset_encoding)
          end
        end
      end
    end

    vim.lsp.buf.format({ bufnr = ev.buf, timeout_ms = 2000 })
  end,
})

-- Go gets a second pass. gopls has already run gofmt and organized imports;
-- gci then re-splits those imports into the blocks above.
vim.api.nvim_create_autocmd("BufWritePost", {
  group = group,
  pattern = "*.go",
  callback = function(ev)
    gci_format(ev.buf)
  end,
})

-- For lua/mivn/health.lua, which probes these instead of trusting
-- executable(); nothing else reads this.
return { servers = servers, formatters = formatters }
