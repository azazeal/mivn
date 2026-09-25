-- Language servers: which ones run, what they are told, and how what they say
-- is drawn (code lenses, floats, diagnostics).
--
-- The client is Neovim's; nvim-lspconfig supplies each server's filetypes, root
-- markers and default command. A server whose binary is not on `PATH` is
-- skipped quietly, never as an error, and `:checkhealth mivn` lists every
-- server, on and off. Settings live in the language files; a project that wants
-- its own carries a .nvim.lua.
--
-- Every file under lua/mivn/languages/ is loaded, and each returns:
--
--   servers     nvim-lspconfig's name for a server, to an entry (below)
--   formatters  filetype to the command that formats it; this overrides what
--               the language server offers (lua/mivn/format.lua runs both)
--   probes      binary name to the arguments `:checkhealth mivn` asks its
--               version with, for a formatter that does not take `--version`
--   health      a function `:checkhealth mivn` runs under the language's name
--
-- An entry:
--
--   binary   what proves the server is installed; defaults to cmd[1], so it
--            is required when cmd is a function or absent
--   cmd      replaces nvim-lspconfig's command, in either shape
--            vim.lsp.config() takes
--   config   what vim.lsp.config() takes, merged over nvim-lspconfig's
--   format   false when the server must never be asked to format, whatever
--            it says it supports
--   probe    the arguments `:checkhealth mivn` asks the version with; false
--            when the binary has no harmless one-shot flag
--
-- A language file may also do its own work when it loads (Go registers its
-- second import pass). Since every file in that directory is loaded, nothing
-- but languages lives there.

--- The languages -------------------------------------------------------------

local languages = {}
for _, path in ipairs(vim.api.nvim_get_runtime_file("lua/mivn/languages/*.lua", true)) do
  languages[#languages + 1] = vim.fn.fnamemodify(path, ":t:r")
end
table.sort(languages)

local servers = {}
local formatters = {}
local probes = {}
local checks = {}
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

  checks[language] = loaded.health
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

local function configure(name, entry)
  local config = vim.deepcopy(entry.config or {})
  config.cmd = entry.cmd or config.cmd

  vim.lsp.config(name, config)
end

-- A server that dies right after starting otherwise fails in silence: the
-- client detaches and nothing says why (rust-analyzer behind a rustup shim with
-- no component installed passes executable() and then dies). This says so once
-- per server per session, and not on shutdown.
local exit_warned = {}

vim.lsp.config("*", {
  on_exit = function(code, _, client_id)
    if code == 0 or vim.v.exiting ~= vim.NIL then
      return
    end

    -- one that was asked to stop is not news, whatever it exits with (gopls: 2)
    local client = vim.lsp.get_client_by_id(client_id)
    if client and client._is_stopping then
      return
    end

    local name = client and client.name or ("client %d"):format(client_id)
    if exit_warned[name] then
      return
    end
    exit_warned[name] = true

    -- on_exit can run in a fast context
    vim.schedule(function()
      vim.notify(("%s exited with code %d. :checkhealth mivn has details."):format(name, code), vim.log.levels.WARN)
    end)
  end,
})

-- Installed ones only, since configuring a server costs a runtime file lookup.
for _, name in ipairs(enabled) do
  configure(name, servers[name])
end

-- Not enabled here: none starts until the directory I opened is trusted, and
-- that answer can change while the editor runs.
require("mivn.trust").gate(enabled)

require("mivn.format").setup(formatters, muted)

--- Code lenses ----------------------------------------------------------------

-- The actions a server offers on a line, drawn above it. Neovim leaves them
-- off; enabling asks for them and keeps them up to date on its own.
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

-- Neovim closes an LSP float on `q` and leaves Esc doing nothing in there,
-- while everywhere else in mivn Esc is the way back. This wraps the stock
-- function, which still decides the size, the highlighting and when the float
-- closes, and adds Esc on the float's own buffer. Signature help and the
-- diagnostic float come through here too.
local open_floating_preview = vim.lsp.util.open_floating_preview

---@diagnostic disable-next-line: duplicate-set-field it is the point
vim.lsp.util.open_floating_preview = function(...)
  local buf, win = open_floating_preview(...)

  -- a reused float hands back the same buffer, and mapping it again is harmless
  vim.keymap.set("n", "<Esc>", "<cmd>bdelete<cr>", {
    buffer = buf,
    silent = true,
    nowait = true,
    desc = "Close this float",
  })

  -- stock leaves 'concealcursor' empty, so the cursor's line shows raw
  -- markdown; Visual still shows it, since there I am copying the text
  vim.wo[win].concealcursor = "n"

  return buf, win
end

--- Diagnostics ---------------------------------------------------------------

-- The message for the cursor's line is drawn under it, as virtual lines, rather
-- than after it where it gets only what the line leaves over; every other
-- diagnostic is a letter in the sign column. The handler cannot wrap those
-- lines (its overflow is 'trunc' or 'scroll'), but it draws one per line of the
-- message, so `format` puts the breaks in.

-- The elbow the handler draws before the first line, `└──── `, which is also
-- the indent of every line after it.
local ELBOW = 6

-- The narrowest a message is wrapped to. Deep in an indented block in a split
-- it would get two words to the line, so it runs off the edge instead.
local NARROWEST = 40

-- The fewest rows a message gets, in a window so short that a third of it is
-- one row.
local SHORTEST = 3

--- The window showing `bufnr`, the current one if it is, or nil when none is.
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

--- How many cells wide and how many rows `diagnostic`'s message may be drawn.
--- Per diagnostic, since the handler indents the block to the diagnostic's
--- column. A buffer in no window gets the screen's size as a guess.
local function room_for(diagnostic)
  local win = window_showing(diagnostic.bufnr)

  if not win then
    local guess = math.max(vim.o.columns - ELBOW, NARROWEST)

    return guess, math.max(math.floor(vim.o.lines / 3), SHORTEST)
  end

  local info = vim.fn.getwininfo(win)[1]

  -- NOTE: virtcol() counts one cell more than the indent the handler draws, and
  -- that is on purpose: the longest line stops one column short of the edge,
  -- since a row that ends on the last column reads as cut off. It runs in the
  -- diagnostic's buffer because a tab is worth that buffer's 'tabstop'.
  local indent = vim.api.nvim_buf_call(diagnostic.bufnr, function()
    return vim.fn.virtcol({ diagnostic.lnum + 1, diagnostic.col + 1 })
  end)

  local width = info.width - info.textoff - indent - ELBOW

  return math.max(width, NARROWEST), math.max(math.floor(info.height / 3), SHORTEST)
end

--- `message` broken into at most `rows` lines of at most `width` cells, joined
--- with newlines. It breaks only on the message's own spaces, so a token wider
--- than `width` runs off the edge whole; each of the message's own lines is
--- wrapped alone and keeps its leading whitespace. Past `rows` the last line
--- ends in an ellipsis.
---
--- NOTE: every width here is strdisplaywidth(), never `#s`. A byte count wraps
--- Greek about a third too early and lets Japanese run off the edge.
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

      -- the gap as it stands, so a run of spaces survives (dropped at a break)
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

  -- trimmed by characters, to make room for the ellipsis
  local last = lines[rows]
  while vim.fn.strdisplaywidth(last) >= width do
    last = vim.fn.strcharpart(last, 0, vim.fn.strchars(last) - 1)
  end

  lines[rows] = last .. "…"

  return table.concat(lines, "\n", 1, rows)
end

--- The message the virtual lines handler draws for one diagnostic.
---
--- NOTE: this runs for every diagnostic in the buffer on every publish, not
--- only the cursor line's, because the handler formats the whole list before
--- `current_line` picks from it. Keep it cheap.
local function drawn(diagnostic)
  local message = diagnostic.message

  -- the code in front, as Neovim's own formatter does: it names the check
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

-- The breaks go in when diagnostics are published, not when they are drawn, so
-- a window that changes size keeps the old width until they are shown again.
-- This shows them again for the buffers in the windows that changed, and only
-- the ones that have any.
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

-- What the language files declared, for `:checkhealth mivn`.
return { servers = servers, formatters = formatters, probes = probes, checks = checks }
