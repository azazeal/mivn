-- The entry point: the options, the few mappings no module owns, and, at the
-- bottom, the load order of every module under lua/mivn/.

-- Set before anything maps against it. Space in Normal mode only repeats `l`.
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- On by default. A project's .editorconfig wins over the fallbacks below.
vim.g.editorconfig = true

-- A .nvim.lua in the project or any directory above it runs after this file, so
-- its vim.lsp.config() calls merge over lua/mivn/languages/. Neovim asks before
-- trusting one; :trust manages the answers.
vim.o.exrc = true

-- The fallback, for files no .editorconfig covers.
vim.opt.expandtab = true
vim.opt.shiftwidth = 4
vim.opt.tabstop = 4

vim.opt.number = true
vim.opt.relativenumber = true

vim.opt.cursorline = true
vim.opt.scrolloff = 8
vim.opt.signcolumn = "yes" -- always reserved, so text never shifts sideways

-- Signs to the right of the numbers, beside the code they are about, rather
-- than at the window's edge, where a change bar reads as part of the border.
--
-- NOTE: no literal characters in this string. `%C`, `%l` and `%s` all collapse
-- to nothing in a window with no fold column, numbers or signs, so the tree,
-- the dashboard and every float keep a zero-width column. One literal space
-- gives each of them a stray empty column and puts the dashboard's centring off
-- by one.
--
-- `%l` is Neovim's own number item, not a hand-written `%{}`, so the cursor
-- line, wrapped rows and mini.diff's overlay lines are numbered as stock does
-- it; those are the three places a hand-written one gets wrong.
vim.opt.statuscolumn = "%C%l%s"

-- The whitespace worth seeing: tabs, trailing spaces, and the non-breaking
-- space that looks like a space and is not.
vim.opt.list = true
vim.opt.listchars = { tab = "» ", trail = "·", nbsp = "␣" }

-- Long lines run off the right edge, so a line is one screen row and the width
-- markers say when it is too long. 'linebreak' only matters once wrapping is
-- turned back on in a window: break between words, not mid-word.
vim.opt.wrap = false
vim.opt.linebreak = true

vim.opt.ignorecase = true
vim.opt.smartcase = true -- ...unless the search itself contains a capital

-- No search count on the command line; the status line shows it as "F: x/x".
vim.opt.shortmess:append("S")

-- No "match 5 of 141" from the completion menu, which opens as I type and
-- already shows it. "C", quiet while it is still scanning, is in the default.
vim.opt.shortmess:append("c")

-- Where a message is drawn. Everything is a toast, a box above the status line
-- that draws over the buffer and goes on its own. The pager, a window I can
-- search and yank from, takes list_cmd (`:ls`, `:registers`, `:map`) and
-- shell_out (`:!cmd`). Errors and `undo` stay toasts: the pager is entered, so
-- routing them there would drop me in a window every time I mistype.
--
-- NOTE: `target` is not in ui2's documented table, where `targets` is either
-- one string for every kind or a table per kind, never both. The module reads
-- `target` as the default under a `targets` table, so this is the one way to
-- ask for both. If an upgrade stops honouring it, every message goes back to
-- the command line; nothing breaks.
local MESSAGES = {
  msg = {
    target = "msg",
    targets = {
      list_cmd = "pager",
      shell_out = "pager",
    },
  },
}

-- ui2 is Neovim's experimental message and command-line layer (:h ui2): a long
-- message is cut short behind `[+x]` instead of blocking on "Press ENTER", and
-- `g<` or :messages shows it whole in a window I can search and yank from.
--
-- NOTE: guarded, because the module is private and has moved before (vim._extui
-- before 0.12). When it moves again the editor has to come up on the stock
-- message UI with a warning rather than fail on startup, so everything that
-- leans on ui2 sits behind this flag.
local ui2 = pcall(function()
  require("vim._core.ui2").enable(MESSAGES)
end)

if ui2 then
  -- No command-line row until something needs one: at 'cmdheight' 0 ui2 hides
  -- its cmdline window and shows it over the status line for `:`.
  --
  -- NOTE: this belongs inside the guard. On stock Neovim 'cmdheight' 0 turns a
  -- message with no row to print on into a "Press ENTER" prompt, and ui2 is
  -- what removes that prompt.
  vim.opt.cmdheight = 0

  -- A file opened while I am in the pager (`:view`, `gf`) lands inside its
  -- float, and ui2's repair of its window then leaves the file loaded and shown
  -- nowhere, or fails outright while the command-line window is open. So the
  -- file is moved out of the pager.
  --
  -- NOTE: 'winfixbuf' on the pager looks like the simpler guard, but it would
  -- refuse ui2's own rebuild of the window too.
  vim.api.nvim_create_autocmd("BufWinEnter", {
    group = vim.api.nvim_create_augroup("mivn.ui2.pager", { clear = true }),
    desc = "Open a file that landed in the message pager somewhere it belongs",
    callback = function(ev)
      local ok, ui = pcall(require, "vim._core.ui2")
      if not ok or ev.buf == ui.bufs.pager then
        return
      end

      local win = vim.api.nvim_get_current_win()
      if win ~= ui.wins.pager or not vim.api.nvim_win_is_valid(win) then
        return
      end

      -- ui2 must never find its own window holding another buffer
      vim.schedule(function()
        if vim.api.nvim_win_is_valid(win) and vim.api.nvim_buf_is_valid(ui.bufs.pager) then
          vim.api.nvim_win_set_buf(win, ui.bufs.pager)
        end
        vim.api.nvim_win_close(win, false)
        vim.cmd.buffer(ev.buf)
      end)
    end,
  })

  -- Esc closes the pager as well as q, the way it closes the hover float. The
  -- buffer outlives the window, so FileType fires once and covers every visit.
  vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("mivn.ui2", { clear = true }),
    pattern = "pager",
    desc = "Close the message pager with Esc as well as q",
    callback = function(ev)
      vim.keymap.set("n", "<Esc>", "<C-w>c", { buffer = ev.buf, desc = "Close the message pager" })
    end,
  })
else
  -- Scheduled, so the warning shows once the UI is up rather than before it.
  vim.schedule(function()
    vim.notify(
      "ui2 failed to load; messages fall back to stock Neovim. "
        .. "This Neovim probably moved the module: check :h ui2 and init.lua.",
      vim.log.levels.WARN
    )
  end)
end

-- No "-- INSERT --": the mode is on the status line, in a color per mode.
vim.opt.showmode = false

-- The count or operator I am halfway through goes on the status line, through
-- `%S`. A prefix which-key claims as a mapping (`Ctrl+W`, `"`) leaves nothing
-- pending there; which-key's panel answers it instead.
vim.opt.showcmdloc = "statusline"

-- One status line for the editor, so it lines up with the tab bar and draws no
-- strip under the tree.
vim.opt.laststatus = 3

-- A frame on the floats Neovim opens itself (hover, signature help, the
-- diagnostic float), the same one mivn's own floats ask for.
vim.opt.winborder = "rounded"

-- No history across sessions: shada's :oldfiles, marks and jumplist are keyed
-- by path and go stale once a directory is renamed. Undo history stays, since
-- it is only read for a file I already chose to open.
vim.opt.shadafile = "NONE"
vim.opt.undofile = true

vim.opt.splitbelow = true
vim.opt.splitright = true

-- The arrows cross line ends: "<" and ">" in Normal and Visual, "[" and "]" in
-- Insert. `h` and `l` keep Vim's stop at the edge of the line.
vim.opt.whichwrap:append("<,>,[,]")

-- An unshifted special key ends a selection, then runs Vim's own key and never
-- a mapping, so lua/mivn/keymaps.lua binds every unshifted key over a selection
-- as well. 'selectmode' stays unset, so a selection is Visual, where `y` and
-- `d` copy and cut it.
--
-- NOTE: "stopsel" only. "startsel" opens a selection on a shifted key without
-- repainting, so the screen keeps the old mode, highlight and cursor until the
-- next key; keymaps.lua binds every shifted key by hand instead.
--
-- 'selection' is exclusive so three presses of Shift+Right select three
-- characters; the floating prompt's preselection counts on it too.
vim.opt.keymodel = "stopsel"
vim.opt.selection = "exclusive"

-- The cursor may sit one past the last character, so the last word of a line
-- has a boundary after it: the word keys land there, and exclusive selection
-- needs it to select that word back to its start.
vim.opt.virtualedit = "onemore"

-- Leaving Insert leaves the caret where it was, not one place left. Vim's step
-- happens between InsertLeavePre and InsertLeave, so one takes the position and
-- the other puts it back. Only a step left is undone, so CTRL-O, which raises
-- both without moving the caret, is left alone.
local caret = nil
local caret_group = vim.api.nvim_create_augroup("mivn.insertleave", { clear = true })

vim.api.nvim_create_autocmd("InsertLeavePre", {
  group = caret_group,
  desc = "Remember the boundary the caret was typing at",
  callback = function()
    caret = vim.api.nvim_win_get_cursor(0)
  end,
})

vim.api.nvim_create_autocmd("InsertLeave", {
  group = caret_group,
  desc = "Put the caret back on the boundary it was typing at",
  callback = function()
    local was = caret
    caret = nil

    if not was then
      return
    end

    local now = vim.api.nvim_win_get_cursor(0)
    if now[1] ~= was[1] or now[2] >= was[2] then
      return
    end

    pcall(vim.api.nvim_win_set_cursor, 0, was)
  end,
})

-- A bar in Normal mode, since every key that acts on the character under the
-- cursor acts on the one right of the bar. Each mode draws in the hue of its
-- status line block; a terminal only gets the group's background, as OSC 12.
--
-- NOTE: `ve` has an entry of its own, where stock shares Insert's. Visual with
-- exclusive selection matches `ve` and not `v`, so on Insert's entry it would
-- draw in Insert's color.
--
-- NOTE: this is set before any module loads, because lua/mivn/caret.lua reads
-- it once at load and rebuilds the option from that. A change to 'guicursor'
-- made anywhere after that is lost at the next rebuild.
vim.opt.guicursor = "n:ver25-Cursor,v:block-vCursor,ve:ver25-vCursor,c-sm:block-cCursor,"
  .. "i-ci:ver25-iCursor,r-cr:hor20-rCursor,o:hor20-oCursor,"
  .. "t:block-blinkon500-blinkoff500-TermCursor"

-- NOTE: 'clipboard' stays empty. It can only make the unnamed register *be* the
-- clipboard, which puts every delete on it along with the copies; `y` and `p`
-- reach it through mappings in lua/mivn/keymaps.lua instead.

-- Greek layout: each Greek letter acts as the Latin one on the same key, in
-- Normal, Visual, Select and Operator-pending only, so Greek still types as
-- Greek. ς and σ both uppercase to Σ, so Σ goes to S and Shift+W has no twin.
-- 'langremap' is off by default, which keeps mappings from being translated
-- twice.
--
-- NOTE: letters only. 'langmap' is one global table that cannot tell which
-- layout is live, and letters are safe only because Greek and Latin letters
-- never overlap: mapping ; to q would rebind ; on the US layout too.
vim.opt.langmap = table.concat({
  "ςερτυθιοπασδφγηξκλζχψωβνμ;wertyuiopasdfghjklzxcvbnm",
  "ΣΕΡΤΥΘΙΟΠΑΔΦΓΗΞΚΛΖΧΨΩΒΝΜ;SERTYUIOPADFGHJKLZXCVBNM",
}, ",")

vim.cmd.colorscheme("basalt")

require("mivn.swap") -- answers the prompt about a swap file no editor is using
require("mivn.plugins") -- vim.pack; every module below is one of its consumers
require("mivn.treesitter") -- grammars, highlighting, injections
require("mivn.lsp") -- language servers, diagnostics, format on save; one file per language
require("mivn.hints") -- the LSP inlay hints, and which languages start without them
require("mivn.complete") -- the Insert-mode completion menu
require("mivn.pairs") -- auto-closing pairs
require("mivn.diff") -- git changes in the gutter
require("mivn.cmdline") -- completion as I type, and the typed commands mivn rewrites
require("mivn.restart") -- :restart, refused when the window is remote
require("mivn.terminal") -- the terminal panel and its toggle
require("mivn.margins") -- the 80/100/120 width markers
require("mivn.occurrences") -- the other copies of what is selected
require("mivn.yank") -- a flash over what a yank took
require("mivn.find") -- fuzzy finding, and the few keys Vim has no default for
require("mivn.external") -- PDFs and their kin offered to the system opener
require("mivn.prompt") -- vim.ui.input as a float instead of the bottom bar
require("mivn.select") -- Select mode's own tint, since Neovim paints it with Visual's
require("mivn.whichkey") -- shows what can follow a key I started typing
require("mivn.session") -- what happens when buffers and windows run out
require("mivn.dashboard") -- the landing buffer
require("mivn.update") -- whether a newer mivn is out, said once on the banner
require("mivn.tree") -- the file tree, loaded after the dashboard claims a window
require("mivn.tabline") -- the buffer tab bar
require("mivn.statusline") -- the status line, and where the mode is shown
require("mivn.title") -- the window title, in Neovide and on a terminal tab
require("mivn.keymaps") -- every key mivn takes; last, so it can call into them
