-- Language servers: which ones, what to tell them, and what they may touch.
--
-- Neovim ships the LSP client; nvim-lspconfig only supplies each server's
-- connection details, which is its filetypes, its root markers and the
-- command when this config does not name one. A server whose binary is not
-- installed is skipped quietly, and that must never become an error: no
-- server means no LSP for that language while tree-sitter carries on.
-- `:checkhealth mivn` lists everything, on and off.
--
-- Nothing here installs anything. What runs is whatever `PATH` resolves,
-- which is the environment the editor was launched with and none of this
-- config's business; a language whose server is not on it gets tree-sitter
-- colours and nothing else.
--
-- There are no personal knobs either, and that is the point: this config is
-- mine and it is in git, so wanting a server configured differently is an
-- edit to its language file. The one thing that cannot be committed, which
-- Go's import prefixes are, arrives as an environment variable. A project
-- that wants its own settings carries a .nvim.lua, the stock way.
--
-- One file per language under lua/mivn/languages/, picked up by being there,
-- each returning:
--
--   servers     nvim-lspconfig's name for a server, to the entry below
--   formatters  filetype to the command that formats it, which **overrides**
--               whatever the language server offers. lua/mivn/format.lua
--               owns the save chain both halves hang off.
--   probes      how `:checkhealth mivn` asks one of those formatters for its
--               version, by binary name. Only for the ones that do not take
--               `--version`; a server says this in its own entry instead.
--
-- An entry, in full:
--
--   binary   what proves the server is installed. Defaults to cmd[1], and
--            has to be written out when cmd is a function or absent.
--   cmd      the command, replacing nvim-lspconfig's, in either shape
--            vim.lsp.config() takes. Omitted keeps lspconfig's.
--   config   what vim.lsp.config() takes, merged over lspconfig's defaults.
--            A function returning that table when building it costs enough
--            to be worth skipping on a machine without the server.
--   format   false when the server must never be asked to format, whatever
--            it answers about supporting it.
--   probe    the arguments `:checkhealth mivn` asks the version with; false
--            when the binary has no harmless one-shot flag at all.
--
-- A language file is also free to do its own work when it is loaded: Go's
-- second import pass is an autocmd it registers itself, since nothing else
-- has any business knowing about it. Nothing but languages lives in that
-- directory, which is what lets the list above be a glob.

--- The languages -------------------------------------------------------------

-- Found rather than listed. A list would be one more thing to keep in step
-- with the directory it describes, and a language left off it would sit
-- there doing nothing, without a word.
local languages = {}
for _, path in ipairs(vim.api.nvim_get_runtime_file("lua/mivn/languages/*.lua", true)) do
  languages[#languages + 1] = vim.fn.fnamemodify(path, ":t:r")
end
table.sort(languages)

local servers = {}
local formatters = {}
local probes = {}
local muted = {}

for _, language in ipairs(languages) do
  local loaded = require("mivn.languages." .. language)

  for name, entry in pairs(loaded.servers or {}) do
    entry.binary = entry.binary or (type(entry.cmd) == "table" and entry.cmd[1] or nil)
    assert(entry.binary, ("mivn.languages.%s: %s names no binary"):format(language, name))

    if entry.format == false then
      muted[name] = true
    end

    servers[name] = entry
  end

  for filetype, spec in pairs(loaded.formatters or {}) do
    formatters[filetype] = spec
  end

  for binary, probe in pairs(loaded.probes or {}) do
    probes[binary] = probe
  end
end

--- Which of them are actually here -------------------------------------------

local enabled = {}
for name, entry in pairs(servers) do
  if vim.fn.executable(entry.binary) == 1 then
    enabled[#enabled + 1] = name
  end
end
table.sort(enabled)

--- Starting them --------------------------------------------------------------

--- Hand `name`'s settings and command to Neovim.
---
--- `config` is allowed to be a function because building it can cost more
--- than a machine without the server should pay: jsonls' settings carry the
--- whole SchemaStore catalog.
local function configure(name, entry)
  local settings = entry.config
  if type(settings) == "function" then
    settings = settings()
  end

  local config = vim.deepcopy(settings or {})
  config.cmd = entry.cmd or config.cmd

  vim.lsp.config(name, config)
end

-- A server that dies right after starting otherwise fails in silence: the
-- client detaches, features quietly stop, and nothing says why. Measured
-- with rust-analyzer behind a rustup shim with no component installed:
-- executable() said yes, the process recursed and died, and nothing said so.
-- Once per server per session, and not on shutdown.
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

-- Installed ones only. Configuring a server this machine does not have costs
-- a runtime file lookup and, for jsonls, reading the whole SchemaStore
-- catalog off disk.
for _, name in ipairs(enabled) do
  configure(name, servers[name])
end

vim.lsp.enable(enabled)

require("mivn.format").setup(formatters, muted)

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

-- For lua/mivn/health.lua, which probes binaries instead of trusting
-- executable(). Nothing else reads any of these.
return { servers = servers, formatters = formatters, probes = probes }
