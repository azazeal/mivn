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

    -- One that was asked to go is not news, whatever it exits with. gopls
    -- leaves with 2 when the client in front of its daemon is shut down, and
    -- taking a directory's trust back stops every server it had.
    local client = vim.lsp.get_client_by_id(client_id)
    if client and client._is_stopping then
      return
    end

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

-- Enabled by the workspace's answer rather than here: none of them starts
-- until the directory this editor was opened in is trusted, and that answer
-- can change while it runs. lua/mivn/trust.lua says why and owns both.
require("mivn.trust").gate(enabled)

require("mivn.format").setup(formatters, muted)

--- Code lenses ----------------------------------------------------------------

-- The actions a server offers on a line, drawn above it. Neovim leaves them
-- off, so the ones a language file asks for (Go names seven in its gopls
-- settings) were being configured and never requested.
--
-- What they are in practice, measured: nothing at all on ordinary Go source,
-- one "run test" per test function in a _test.go, and seven on a go.mod for
-- tidy, vendor, govulncheck and the upgrades. rust-analyzer adds a reference
-- count per item and Run and Debug above each test and above main.
--
-- Running the one under the cursor is <leader>ax in lua/mivn/keymaps.lua.
-- Nothing else about them is a key: enabling asks for them and keeps them up
-- to date on its own, so refresh and clear are machinery rather than
-- decisions.
vim.api.nvim_create_autocmd("LspAttach", {
  group = vim.api.nvim_create_augroup("mivn.lsp.lenses", { clear = true }),
  callback = function(ev)
    local client = vim.lsp.get_client_by_id(ev.data.client_id)
    if client and client:supports_method("textDocument/codeLens") then
      vim.lsp.codelens.enable(true, { bufnr = ev.buf })
    end
  end,
})

--- Getting back out of a float ------------------------------------------------

-- <leader>ai opens the documentation float and a second one steps into it.
-- Neovim
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
--
-- Under the line is not enough on its own, though, because the block does not
-- wrap either. Neovim's handler draws it with `virt_lines_overflow = 'scroll'`
-- and that field only takes 'trunc' or 'scroll', so with 'wrap' off
-- (init.lua) a long gopls message is cut at the right edge with nothing
-- saying there is more, and the tail is only reachable with `zL`, which drags
-- the code sideways to read a message about it.
--
-- What the handler does give is one virtual line per line of the message it
-- is handed, elbow on the first and an indent on the rest. So the wrapping is
-- a `format` that puts the breaks in, and there is no custom handler here.

-- The elbow the handler draws in front of the first line, `└──── `, and the
-- six spaces it indents every line after it with.
local ELBOW = 6

-- Narrower than this and the wrapping does more harm than the truncation did:
-- a diagnostic deep in an indented block, in a split, would get two words to
-- the line. It overflows the edge instead, and `Ctrl+W d` has the whole
-- message either way.
local NARROWEST = 40

-- The floor under that third, for a window short enough that a third of it is
-- one row. Three rows of a message is worth reading; one is the truncation
-- back again with an ellipsis on it.
local SHORTEST = 3

--- The window `bufnr` is showing in: the one I am in when it is one of them,
--- and otherwise the first of them. A buffer in no window at all has
--- diagnostics that arrived before I opened it, and then the screen's width
--- is the best guess there is.
local function window_showing(bufnr)
  local wins = vim.fn.win_findbuf(bufnr)
  if #wins == 0 then
    return nil
  end

  local current = vim.api.nvim_get_current_win()
  for _, win in ipairs(wins) do
    if win == current then
      return win
    end
  end

  return wins[1]
end

--- How wide one diagnostic's message may be drawn, in screen cells, and how
--- many lines of it are worth drawing there.
---
--- Both are per diagnostic, because the handler indents the block to the
--- column the diagnostic starts on: the same message on a deeply indented
--- line has that much less room.
local function room_for(diagnostic)
  local win = window_showing(diagnostic.bufnr)

  if not win then
    local guess = math.max(vim.o.columns - ELBOW, NARROWEST)

    return guess, math.max(math.floor(vim.o.lines / 3), SHORTEST)
  end

  local info = vim.fn.getwininfo(win)[1]

  -- virtcol() counts the cells up to and including the character the
  -- diagnostic sits on, which is one more than the indent the handler draws.
  -- That extra one is kept on purpose: the longest line then stops one column
  -- short of the right edge, and a row that ends on the last column reads as
  -- cut off whether or not anything was lost. Buffer-local, since what a tab
  -- is worth is 'tabstop' over there and not here.
  local indent = vim.api.nvim_buf_call(diagnostic.bufnr, function()
    return vim.fn.virtcol({ diagnostic.lnum + 1, diagnostic.col + 1 })
  end)

  local width = info.width - info.textoff - indent - ELBOW

  return math.max(width, NARROWEST), math.max(math.floor(info.height / 3), SHORTEST)
end

--- `message` broken into at most `rows` lines of at most `width` cells, as
--- one string with newlines in it, which is what the handler draws a virtual
--- line each of.
---
--- Breaks on the spaces the message already has and never inside a token, so
--- a token wider than `width` gets a line of its own and runs off the edge:
--- half a path or half an identifier is worse than one that overflows. Each
--- of the message's own lines is wrapped on its own and keeps the whitespace
--- it opens with, since a server that sent me an indented snippet meant it.
---
--- Every width in here is `strdisplaywidth` and never `#s`. A byte count
--- wraps a Greek message about a third too early and lets a Japanese one run
--- off the edge, because neither of them has one byte to the cell.
local function wrap(message, width, rows)
  local lines = {}
  local pieces = {}

  for source in vim.gsplit(message, "\n", { plain = true }) do
    local held, used = 0, 0

    for gap, token in source:gmatch("(%s*)(%S+)") do
      local room = vim.fn.strdisplaywidth(token)
      local between = vim.fn.strdisplaywidth(gap)

      if held > 0 and used + between + room > width then
        lines[#lines + 1] = table.concat(pieces, "", 1, held)
        held, used = 0, 0
        gap, between = "", 0
      end

      -- The gap goes in as it stands rather than as one space, so a run of
      -- them inside a line survives; the one a break lands on is the break.
      if gap ~= "" then
        held = held + 1
        pieces[held] = gap
      end

      held = held + 1
      pieces[held] = token
      used = used + between + room
    end

    lines[#lines + 1] = table.concat(pieces, "", 1, held)
  end

  if #lines <= rows then
    return table.concat(lines, "\n")
  end

  -- Cut, with the marker that says so on the last line kept. Trimmed by
  -- characters rather than by tokens, since the sentence is being cut in the
  -- middle whatever I do, and the ellipsis is the thing that points at
  -- `Ctrl+W d` for the rest.
  local last = lines[rows]
  while vim.fn.strdisplaywidth(last) >= width do
    last = vim.fn.strcharpart(last, 0, vim.fn.strchars(last) - 1)
  end

  lines[rows] = last .. "…"

  return table.concat(lines, "\n", 1, rows)
end

--- The message the virtual lines handler draws for one diagnostic.
---
--- WARN: this runs for every diagnostic in the buffer on every publish, not
--- only the one the cursor is on, because the handler formats the whole list
--- before `current_line` picks out of it. Keep the work in here to the string
--- and the two tables it takes.
local function drawn(diagnostic)
  local message = diagnostic.message

  -- The code in front, which is what Neovim's own formatter does and worth
  -- keeping: "unusedparams" names which of gopls' checks is talking.
  if diagnostic.code then
    message = ("%s: %s"):format(diagnostic.code, message)
  end

  local width, rows = room_for(diagnostic)

  return wrap(message, width, rows)
end

vim.diagnostic.config({
  severity_sort = true,
  virtual_lines = { current_line = true, format = drawn },
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

-- The breaks above go in when the diagnostics are published and not when they
-- are drawn, so they are the widths the windows had at the time. Opening the
-- tree, splitting, or resizing the terminal leaves every message wrapped for
-- a width that is gone, and the truncation is back until the server says
-- something new. Publishing them again is what re-measures them.
--
-- WinResized carries the windows that changed, so this touches those buffers
-- and no others: a session with twenty files open re-publishes the two that
-- are on screen, and only if they have anything to say. It covers the whole
-- screen changing too, since resizing the terminal resizes the windows in it.
vim.api.nvim_create_autocmd("WinResized", {
  group = vim.api.nvim_create_augroup("mivn.lsp.diagnostics", { clear = true }),
  callback = function()
    local seen = {}

    for _, win in ipairs(vim.v.event.windows or {}) do
      if vim.api.nvim_win_is_valid(win) then
        local buf = vim.api.nvim_win_get_buf(win)

        if not seen[buf] and next(vim.diagnostic.count(buf)) then
          seen[buf] = true
          vim.diagnostic.show(nil, buf)
        end
      end
    end
  end,
})

-- For lua/mivn/health.lua, which probes binaries instead of trusting
-- executable(). Nothing else reads any of these.
return { servers = servers, formatters = formatters, probes = probes }
