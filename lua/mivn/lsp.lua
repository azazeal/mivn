-- Language servers, and what happens when I save.
--
-- Neovim ships the LSP client; nvim-lspconfig only supplies each server's
-- connection details. A server whose binary is not installed is skipped
-- quietly, and that must never become an error: no server means no LSP for
-- that language while tree-sitter carries on. `:checkhealth mivn` lists
-- everything, on and off, and says which of them are sandboxed.
--
-- Nothing here installs anything any more. mise owns that, so this file's
-- whole job is the two things mise cannot express: what to tell a server
-- once it starts, and what to run after it (lua/mivn/sandbox.lua wraps how
-- they start, and the save chain at the bottom is the other half).
--
-- Format on save lives here because most of it *is* the language server:
-- organize imports, then format. Completion is in lua/mivn/complete.lua.

--- Which server handles what, and what binary proves it is installed ---------

-- Keys are nvim-lspconfig's names, values the executable to look for on
-- PATH, where mise puts it. A name missing from mise's config is simply a
-- language without a server, said once in `:checkhealth mivn`. The `lsp`
-- overrides below add or re-point anything else.
local servers = {
  gopls = "gopls",
  golangci_lint_ls = "golangci-lint-langserver", -- lint diagnostics beside gopls
  ruby_lsp = "ruby-lsp",
  gleam = "gleam", -- the Gleam compiler's own LSP, `gleam lsp`

  -- JSON and YAML, both of them Node programs, which is the whole cost of
  -- having them: mise installs node, the two servers, and nothing else uses
  -- it. What they buy is JSON Schema, and for YAML that is mostly the
  -- GitHub workflow schema over the several hundred workflow files here.
  jsonls = "vscode-json-language-server",
  yamlls = "yaml-language-server",

  -- Moved out of the store on 2026-08-15, because mise installs every one of
  -- them and two copies of a server is one copy too many. The store keeps
  -- only what mise has no entry for yet.
  buf_ls = "buf",
  docker_language_server = "docker-language-server",
  expert = "expert",
  lua_ls = "lua-language-server",
  marksman = "marksman",
  rust_analyzer = "rust-analyzer",
  taplo = "taplo",
  templ = "templ",
  terraformls = "terraform-ls",

  -- The TypeScript 7 compiler, whose language server is a flag on the
  -- compiler. mise installs it under the name the release carries, `tsc`,
  -- and nvim-lspconfig looks for `tsgo`; the config below re-points it.
  tsgo = "tsc",

  -- The last three out of the store, 2026-08-15. Python gets two servers
  -- because they do different halves: ty types and navigates, ruff lints and
  -- formats.
  ruff = "ruff",
  ty = "ty",
  superhtml = "superhtml",
}

--- Local overrides ------------------------------------------------------------

-- The personal knobs that do not belong in a public config. lua/mivn/local.lua
-- is optional, gitignored, and returns a table. The keys so far:
--
--   lsp                  per-server tuning, one entry per nvim-lspconfig
--                        name. `false` turns a server off. A table carries
--                        the finer knobs: `path` (an executable of your own,
--                        instead of the one on PATH), `config` (handed to
--                        vim.lsp.config(), deep-merged over the defaults
--                        here), `probe` (how :checkhealth mivn asks for a
--                        version), `sandbox = false` (this server runs
--                        unconfined), and gopls' `prefixes` (the Go import
--                        prefixes that count as ours). local.example.lua
--                        documents them all.
--
-- Any key can also be scoped to a directory through local.lua's `projects`
-- table; lua/mivn/overrides.lua resolves that against the startup directory,
-- and local.example.lua shows every shape.
local overrides = require("mivn.overrides")

-- One list for the whole session, like every other override: `projects` in
-- local.lua is the scoping mechanism, resolved by where Neovim started. The
-- cost is deliberate and small: a file from another workspace edited in this
-- session gets this workspace's blocks. The list rides gopls' entry in the
-- `lsp` overrides because both consumers are Go plumbing: gopls' `local`
-- setting, and the gci run this module drives itself on save.
local gopls_overrides = (overrides.lsp or {}).gopls
local import_prefixes = type(gopls_overrides) == "table" and gopls_overrides.prefixes or {}

for server, o in pairs(overrides.lsp or {}) do
  if o == false then
    servers[server] = nil
  elseif type(o) == "table" and o.path then
    servers[server] = o.path
  end
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

      -- Rust doc comments link with rustdoc's own `[`Type`]` shorthand, and
      -- rust-analyzer expands each one into a full docs.rs URL before
      -- sending the hover. Neovim then conceals the URL but still measures
      -- the line with it, so one link makes the float a hundred columns
      -- wider than its text and wraps the sentence in the middle of itself.
      -- Off, the link text stays and the URL never arrives.
      hover = { links = { enable = false } },
    },
  },
})

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

-- Both of these ship a `cmd` **function** in nvim-lspconfig that prefers
-- `<root>/node_modules/.bin/<server>` whenever the project has one, so
-- opening a repository would run the language server that repository
-- shipped. Replaced with the plain command, which also turns cmd back into
-- a list, and a list is what lua/mivn/sandbox.lua can wrap.
vim.lsp.config("jsonls", {
  cmd = { "vscode-json-language-server", "--stdio" },

  -- The catalog this server does not carry; lua/mivn/schemas.lua says why.
  --
  -- `validate.enable` is not optional here even though it reads like a
  -- default. The server computes `validateEnabled = !!settings.json.validate
  -- .enable` when configuration arrives, so sending any settings at all
  -- without it turns validation off entirely, schemas and `$schema` lines
  -- included. Measured 2026-08-15: adding the catalog alone made
  -- package.json stop reporting anything.
  settings = {
    json = {
      schemas = require("mivn.schemas").json(),
      validate = { enable = true },
    },
  },
})

vim.lsp.config("yamlls", { cmd = { "yaml-language-server", "--stdio" } })

-- Same two corrections for tsgo, which nvim-lspconfig also gives a `cmd`
-- function that reaches into `<root>/node_modules/.bin`: the binary mise
-- installs is called `tsc`, and a list is what the sandbox can wrap.
vim.lsp.config("tsgo", { cmd = { "tsc", "--lsp", "--stdio" } })

-- TOML's own catalog, so a `Cargo.toml` or a `mise.toml` gets its schema
-- from its name the way JSON and YAML now do, rather than only from a
-- `#:schema` line. `evenBetterToml` is the section taplo asks the editor
-- for, named after its VS Code extension. lua/mivn/schemas.lua explains why
-- the URL is a local file rather than SchemaStore's own.
local taplo_catalog = require("mivn.schemas").taplo()
if taplo_catalog then
  vim.lsp.config("taplo", {
    settings = {
      evenBetterToml = {
        schema = { enabled = true, catalogs = { taplo_catalog } },
      },
    },
  })
end

-- Opening one .tf file outside a Terraform directory is normal here, and
-- terraform-ls says so every time in a message long enough to raise the
-- hit-enter prompt, which stops everything until a key arrives. The server
-- offers this switch for exactly that; nothing else about it changes.
vim.lsp.config("terraformls", {
  init_options = { ignoreSingleFileWarning = true },
})

-- Personal configuration last, so it wins: vim.lsp.config() merges repeated
-- calls, later ones taking precedence, which is the whole implementation.
-- `config` is the full vim.lsp.config shape, not just `settings`, because
-- servers differ in where they read from (ruff wants `init_options`).
for server, o in pairs(overrides.lsp or {}) do
  if type(o) == "table" and o.config then
    vim.lsp.config(server, o.config)
  end
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

-- Confined before any of them starts; lua/mivn/sandbox.lua decides which
-- ones it covers and leaves the rest exactly as they were.
local sandbox = require("mivn.sandbox")
for _, server in ipairs(enabled) do
  local cmd = (vim.lsp.config[server] or {}).cmd
  if type(cmd) == "table" then
    vim.lsp.config(server, { cmd = sandbox.wrap(server, cmd) })
  end
end

vim.lsp.enable(enabled)

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

--- Getting back out of a float ------------------------------------------------

-- `K` opens the documentation float and a second `K` steps into it. Neovim
-- maps `q` in there to close it and leaves Esc doing nothing, which is the
-- one place in mivn where Esc is not the way back: the rename prompt and
-- the trust dialog both take it. This is that key doing the same thing here.
-- `q` still works, and the mapping is on the float's own buffer, so it
-- reaches nothing else.
--
-- Wrapped rather than replaced: the stock function decides the size, the
-- highlighting and when the float closes on its own. All this adds is the
-- mapping, to the buffer it hands back. Signature help and the diagnostic
-- float come through here too, and get it for the same reason.
local open_floating_preview = vim.lsp.util.open_floating_preview

---@diagnostic disable-next-line: duplicate-set-field it is the point
vim.lsp.util.open_floating_preview = function(...)
  local buf, win = open_floating_preview(...)

  -- Reusing a float that is already up hands back the same buffer, so this
  -- can run twice for one window; setting the same mapping again is free.
  vim.keymap.set("n", "<Esc>", "<cmd>bdelete<cr>", {
    buffer = buf,
    silent = true,
    nowait = true,
    desc = "Close this float",
  })

  -- Stock leaves 'concealcursor' empty, so the line the cursor is on drops
  -- back to raw markdown. Stepping into the float lands on line one, which
  -- is the ```rust that opens the signature, and reading documentation is
  -- not the moment to be shown its markup. Normal mode only: a Visual
  -- selection is usually me taking the text, and then the markup is the
  -- point.
  vim.wo[win].concealcursor = "n"

  return buf, win
end

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

  -- The buffer matches the disk right now, just after the write. If it does
  -- not by the time gci's result comes back, I typed in the window in
  -- between, and splicing the file over the buffer would throw those
  -- keystrokes away; the changedtick is the guard against exactly that.
  local tick = vim.api.nvim_buf_get_changedtick(buf)

  vim.system(cmd, { text = true }, function(result)
    if result.code ~= 0 then
      return
    end

    vim.schedule(function()
      if not vim.api.nvim_buf_is_valid(buf) or vim.api.nvim_buf_get_changedtick(buf) ~= tick then
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
          context = { only = { ORGANIZE_IMPORTS }, diagnostics = {} },
        })

        local responses = client:request_sync("textDocument/codeAction", params, 1000, ev.buf)
        for _, action in pairs((responses or {}).result or {}) do
          if action.edit and organizes_imports(action.kind) then
            vim.lsp.util.apply_workspace_edit(action.edit, client.offset_encoding)
          end
        end
      end
    end

    -- Only when one of them can. vim.lsp.buf.format says "no matching language
    -- servers" into the message area otherwise, which is every markdown save,
    -- marksman being attached and offering no formatter.
    local formats = vim.iter(clients):any(function(client)
      return client:supports_method("textDocument/formatting")
    end)

    if formats then
      vim.lsp.buf.format({ bufnr = ev.buf, timeout_ms = 2000 })
    end
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
