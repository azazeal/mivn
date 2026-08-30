-- The entry point: the options, the few mappings no module owns, and, at
-- the bottom, the load order of every module under lua/mivn/.

-- Leader is Space, and it has to be set before anything maps against it.
-- Nothing is lost: Space in Normal mode repeats `l`.
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- On by default since 0.9, set explicitly because it is the source of truth
-- for indentation: a project's .editorconfig wins over the fallbacks below.
vim.g.editorconfig = true

-- A project can carry its own editor config: a .nvim.lua in the project or
-- any directory above it runs after this file, so vim.lsp.config() calls
-- there merge over lua/mivn/languages/'s defaults. Guarded by Neovim's trust
-- prompt on first load; :trust manages the answers.
vim.o.exrc = true

-- The fallback, for files no .editorconfig covers.
vim.opt.expandtab = true
vim.opt.shiftwidth = 4
vim.opt.tabstop = 4

-- Both at once: the cursor line shows its real number and every other line the
-- distance to it, so the number beside a line is also the count a motion needs
-- to reach it.
vim.opt.number = true
vim.opt.relativenumber = true

vim.opt.cursorline = true
vim.opt.scrolloff = 8
vim.opt.signcolumn = "yes" -- always reserved, so text never shifts sideways

-- Signs to the right of the numbers, between them and the code.
--
-- Stock order puts them leftmost, where a change bar is a thin vertical line
-- at the very edge of the window, parallel to sway's border and a few pixels
-- from it. The eye groups two parallel lines, so the bar reads as chrome
-- rather than as something about the file. Padding does not un-group them;
-- foot already has 8px of it. Beside the code the bar points at what it is
-- about, which is also the order ~/.config/helix orders its gutters in.
--
-- WARN: no literal characters in this string, ever. `%C`, `%l` and `%s` all
-- collapse to nothing where a window has no fold column, no numbers and no
-- signs, so the tree, the dashboard and every float keep a zero-width column
-- exactly as they do now. One literal space in here and all of them gain a
-- stray empty column, and the dashboard's centring goes off by one.
--
-- `%l` is Neovim's own number item rather than a hand-rolled `%{}`, so
-- 'number' and 'relativenumber' are relocated and not reimplemented: the
-- cursor line keeps its absolute number, wrapped rows draw no number, and
-- mini.diff's overlay virtual lines draw none either. Those are the three
-- places a hand-written version gets it wrong.
vim.opt.statuscolumn = "%C%l%s"

-- The whitespace worth seeing: tabs, trailing spaces, and the non-breaking
-- space that looks like a space and is not. Ordinary spaces stay invisible,
-- since a dot on every one of them is noise. `:set listchars+=space:·` is the
-- full-noise version, should I ever want it.
vim.opt.list = true
vim.opt.listchars = { tab = "» ", trail = "·", nbsp = "␣" }

-- Long lines run off the right edge instead of wrapping, so a line is one
-- screen row and the width markers (lua/mivn/margins.lua) tell me when it is
-- too long; <Space>w brings wrapping back per window. 'linebreak' only
-- matters while wrapping is on: break between words, not mid-word.
vim.opt.wrap = false
vim.opt.linebreak = true

vim.opt.ignorecase = true
vim.opt.smartcase = true -- ...unless the search itself contains a capital

-- No search count on the command line: the status line shows it as "F: x/x"
-- instead (lua/mivn/statusline.lua), so the count sits with the rest of the
-- always-on state rather than floating alone at the bottom right.
vim.opt.shortmess:append("S")

-- No running commentary from the completion menu either. Without "c" every
-- keystroke while the menu is up prints "match 5 of 141", and with the menu
-- opening as I type (lua/mivn/complete.lua) that is a message per character,
-- stacked three deep in the corner. The menu already shows which match is
-- selected and how many there are; the sentence is the same fact, spoken.
--
-- "C" is already in the default and is the other half: quiet while it is
-- still scanning for matches, rather than quiet about what it found.
vim.opt.shortmess:append("c")

-- ui2, Neovim's experimental rewrite of the message and command-line layer
-- (:h ui2). What it changes here: a message longer than 'cmdheight' no
-- longer blocks on "Press ENTER"; it is cut short behind a `[+x]` marker,
-- and Enter right after, or `g<` any time, shows the whole thing. :messages
-- opens in a real window I can search and yank from. Defaults otherwise:
-- messages stay on the command line, no floats.
--
-- Guarded, because the module is private and already changed names once
-- this cycle (vim._extui before 0.12). When an upgrade moves it again, the
-- editor must come up on the stock message UI with a warning, not die on
-- line one; everything below that leans on ui2 sits behind this flag.
--- Where a message is drawn, by what produced it.
---
--- Everything is a toast by default: a box above the status line, right
--- aligned, gone on its own after a few seconds. It draws over the buffer
--- rather than pushing it, so nothing moves when one arrives. Measured on a
--- 100x35 terminal: the last screen row is the status line at rest, while a
--- message shows, and while a toast shows.
---
--- The two exceptions are the ones I want to read rather than notice, and
--- both go to the pager, a real window with the text in a buffer I can
--- search and yank from. `:ls`, `:registers` and `:map` are list_cmd; `:!cmd`
--- output is shell_out.
---
--- Deliberately not there: errors. The pager is entered, not just shown, so
--- routing emsg would throw me into a window I have to leave again every time
--- I mistype a command. An error is short and worth noticing, which is what a
--- toast is for. `undo` is the same argument, and it routes too, which is how
--- I know to keep it out: "1 line less; before #1" is not worth a window.
---
--- Both kinds measured rather than taken from the docs; `verbose` looked like
--- a third candidate and turned out not to route at all.
local MESSAGES = {
  msg = {
    target = "msg",
    targets = {
      list_cmd = "pager",
      shell_out = "pager",
    },
  },
}

local ui2 = pcall(function()
  require("vim._core.ui2").enable(MESSAGES)
end)

if ui2 then
  -- No command line until something needs one.
  --
  -- ui2 draws the cmdline in a window of its own, and at 'cmdheight' 0 it
  -- hides that window outright, unhiding it when I open a command line and
  -- hiding it again when I leave. So the status line is the last row of the
  -- screen at rest, and `:` borrows a row over it rather than a row being
  -- kept empty all day waiting to be borrowed.
  --
  -- WARN: this belongs inside the guard and nowhere else. On stock Neovim
  -- 'cmdheight' 0 turns a message with no line to print on into a modal
  -- "Press ENTER" prompt, which is the whole reason it was not set before.
  -- ui2 is what removes that prompt, so an upgrade that moves the module has
  -- to leave the height alone as well as the messages.
  --
  -- What the two settings below already did for this: the mode and the
  -- pending count both live on the status line, and 'shortmess' S puts the
  -- search count there too. Nothing is left that only had the command line
  -- to be drawn on.
  vim.opt.cmdheight = 0

  -- Keep files out of the pager's window.
  --
  -- The pager is a window I land in, so a `:view` or a `gf` typed while I am
  -- still in it opens the file *inside the float*. ui2 then repairs its own
  -- window on the next thing that disturbs it and the file is left loaded and
  -- shown nowhere. That repair is `nvim_win_set_buf`, which is illegal while
  -- the command-line window is open, and 'cmdheight' 0 above is what makes it
  -- run often enough to collide: ui2 sets the option on every command line,
  -- and every set fires this OptionSet.
  --
  -- So the file is moved out rather than refused: 'winfixbuf' would refuse
  -- ui2's own rebuild too, which is why the obvious guard is not this one.
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

      -- Put ui2's own buffer back before leaving, so it never sees a window
      -- of its own holding someone else's buffer.
      vim.schedule(function()
        if vim.api.nvim_win_is_valid(win) and vim.api.nvim_buf_is_valid(ui.bufs.pager) then
          vim.api.nvim_win_set_buf(win, ui.bufs.pager)
        end
        vim.api.nvim_win_close(win, false)
        vim.cmd.buffer(ev.buf)
      end)
    end,
  })

  -- ui2's message pager (`g<`, :messages) is a window I land in, and ui2
  -- only maps q to close it. Esc closes it too, the way it closes the hover
  -- float (lua/mivn/languages/): one reflex for every transient view. The
  -- mapping is buffer-local and the buffer outlives the window, so FileType
  -- fires once and covers every visit.
  vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("mivn.ui2", { clear = true }),
    pattern = "pager",
    desc = "Close the message pager with Esc as well as q",
    callback = function(ev)
      vim.keymap.set("n", "<Esc>", "<C-w>c", { buffer = ev.buf, desc = "Close the message pager" })
    end,
  })
else
  -- Scheduled so the warning lands after startup instead of scrolling by
  -- unseen while the UI is still attaching.
  vim.schedule(function()
    vim.notify(
      "ui2 failed to load; messages fall back to stock Neovim. "
        .. "This Neovim probably moved the module: check :h ui2 and init.lua.",
      vim.log.levels.WARN
    )
  end)
end

-- The two settings below came out of the 'cmdheight' work above and stay on
-- their own merits: each one moves something off the command line that I
-- would rather read in one fixed place.

-- "-- INSERT --" stays off the command line; the mode lives on the status
-- line instead, with a color per mode. See lua/mivn/statusline.lua.
vim.opt.showmode = false

-- Moves 'showcmd', the count or pending operator I am halfway through, onto
-- the status line, rendered there through `%S`.
--
-- Measured limit: which-key claims some prefixes as mappings of its own,
-- `Ctrl+W` and `"` among them, and a key that completes a mapping leaves
-- nothing pending to report. Those answer with which-key's panel instead.
vim.opt.showcmdloc = "statusline"

-- One status line across the editor rather than one per window, so it lines up
-- with the tab bar instead of drawing a strip under the file tree as well.
vim.opt.laststatus = 3

-- Every float Neovim opens on its own gets a frame: hover documentation,
-- signature help, the diagnostic float. Stock is no border at all, which
-- leaves their text flush against the buffer underneath with nothing marking
-- where one ends. mivn's own floats already ask for this border by name, so
-- this is the rest of them catching up rather than a new look.
vim.opt.winborder = "rounded"

-- Command-line completion as a popup menu that opens by itself as I type.
-- `wildtrigger()` is Vim's own function for that, new in 0.12, so this is an
-- option and an autocmd rather than a plugin.
--
-- 'wildmode' lists what each successive Tab does. `noselect:lastused` is what
-- the automatic trigger gets: menu up with nothing inserted, so Enter runs
-- what I typed and not a suggestion, and `:b` is ordered by recency. Then
-- `longest:full` on the first Tab and `full` after it. `noselect` has to be
-- first: with `longest` there, the trigger would insert the common prefix of
-- the matches while I was still typing.
--
-- `:` only, and not `/` or `?`: over a search, a popup covers the match
-- 'incsearch' is already showing me. `:h cmdline-autocompletion` has the
-- fuller setup this one is trimmed from.
vim.opt.wildoptions = "pum"
vim.opt.wildmode = "noselect:lastused,longest:full,full"

vim.api.nvim_create_autocmd("CmdlineChanged", {
  group = vim.api.nvim_create_augroup("mivn.cmdline", { clear = true }),
  pattern = ":",
  desc = "Open the completion menu as the command line is typed",
  callback = function()
    vim.fn.wildtrigger()
  end,
})

-- The four keys that walk that menu are in lua/mivn/keymaps.lua, with every
-- other mapping.

-- No history across sessions. shada holds :oldfiles, per-file marks and the
-- jumplist, all keyed by path, so it is the thing that goes stale and starts
-- pointing at directories renamed out from under it.
--
-- 'undofile' is kept: per-file undo history is only ever consulted for a file
-- I have already chosen to open, so it cannot send me anywhere.
vim.opt.shadafile = "NONE"
vim.opt.undofile = true -- undo survives closing the file

vim.opt.splitbelow = true
vim.opt.splitright = true

-- An arrow at the end of a line carries on to the next one, and at column
-- zero back to the end of the one above. Vim keeps every key inside the line
-- unless 'whichwrap' names it, and the default names only Backspace and
-- Space. Word motions never needed naming, which is why Ctrl+arrow already
-- spanned lines here while a plain arrow stopped dead.
--
-- "<" and ">" are the arrows in Normal and Visual, "[" and "]" the ones in
-- Insert. `h` and `l` are left out on purpose: the arrows are the CUA layer
-- and may behave like every other editor, while the letters keep Vim's
-- line-at-a-time meaning.
vim.opt.whichwrap:append("<,>,[,]")

-- Shift and an arrow selects, the one habit from Emacs and Zed worth carrying
-- over. No mapping is involved: Vim already binds the shifted arrows to
-- motions, and these three options decide that pressing one starts a selection
-- the motion then extends. Note the shifted keys change meaning rather than
-- only gaining a selection: Shift+Up and Shift+Down are page motions in stock
-- Neovim, one line here.
--
-- 'keymodel' is what makes a shifted key start a selection and an unshifted
-- one end it. What the selection lands in is Visual, Vim's own answer to "I
-- have picked some text out": `y` copies it, `d` and `x` cut it, `c`
-- replaces it, and a motion adjusts it. A mouse drag lands there too.
--
-- 'selectmode' would land it in Select instead, where the letters I type
-- replace the selection rather than running as commands, and it is not set
-- here. That one habit cost `y` and `d`, which replaced the selection with a
-- letter, so copying what I had just picked out was <C-o> y. Select mode is
-- still the mode the floating prompt and the tree's rename preselect in
-- (lua/mivn/prompt.lua), and `gh` and <C-g> still reach it, which is why the
-- status line goes on telling the two apart.
--
-- 'selection' is exclusive so that three presses of Shift+Right select three
-- characters rather than four. prompt.lua's preselection counts on it too.
--
-- Two costs. "stopsel" means an unshifted arrow ends a selection instead of
-- extending it, so hjkl is how I adjust one. And exclusive takes one
-- character off a character-wise Visual yank: on "amm", `vlly` yanks "am".
-- Text objects and operators are unaffected.
-- "stopsel" only. "startsel" is what used to open a selection when a shifted
-- special key was pressed, and it is gone because that path does not repaint:
-- the selection started, the screen kept the old mode, the old highlight and
-- the old cursor until the next key arrived. Every shifted key that behaved
-- turned out to be one lua/mivn/keymaps.lua binds by hand, so now they all
-- are, and nothing is left for "startsel" to do.
vim.opt.keymodel = "stopsel"
vim.opt.selection = "exclusive"

-- The cursor may sit one past the last character of a line.
--
-- Exclusive selection above makes the cursor a boundary between characters
-- rather than a character: a selection runs up to it and does not include
-- what it is on. The word keys lean on that, landing after the last letter of
-- a word so that selecting back to its start holds the word and nothing else
-- (lua/mivn/words.lua). Without this the last word of a line would have no
-- boundary to land on, Normal mode refusing the column.
--
-- lua/mivn/prompt.lua already set this on its own window for the same reason;
-- this is that, everywhere.
vim.opt.virtualedit = "onemore"

-- Leaving Insert leaves the caret where it was.
--
-- Vim steps it one place left on the way out, because in Vim the cursor sits
-- on a character and there is no character past the last one to sit on. Here
-- it sits between two, so the place I was typing at and the place the bar
-- stands after are one place, and the step lands the next key a character
-- earlier than where I stopped. It is the same trade as the two options
-- above, from the far side.
--
-- InsertLeavePre runs before the step and InsertLeave after it, which is why
-- there are two: one takes the position, the other puts it back. Only a step
-- leftwards is undone. At the start of a line there is nothing to step over
-- and nothing to put back, and CTRL-O, which raises both of these without
-- moving anything, comes out the same on both sides and is left alone.
local caret = nil
local caret_group = vim.api.nvim_create_augroup("mivn.caret", { clear = true })

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

-- A bar in Normal mode, not a block.
--
-- The shape is only a shape: Neovim's cursor is a buffer position either way,
-- and every key that acts on "the character under the cursor" acts on the one
-- to the right of the bar. That reading is the true one here. `x` deletes it,
-- `i` opens before it, an operator runs forward from it and a selection stops
-- at it, so what is drawn now says what the keys have meant since 'selection'
-- went exclusive.
--
-- Neovim already agreed one mode over: `ve`, Visual with exclusive selection,
-- is a bar in the stock value for exactly this reason. This is that reasoning
-- carried into Normal.
--
-- WARN: the two keys that lose by it are `r` and `~`, which act on the
-- character to the right of the bar and no longer show which one that is.
--
-- The color says which mode I am in, in the status line block's own hues:
-- blue Normal, green Insert, magenta Visual, red Replace, yellow Command,
-- cyan for the rest. The block sits in a corner and the caret is where I am
-- already looking, so the mode is said twice on purpose. Only the background
-- of those groups reaches a terminal: 'guicursor' hands the color over as
-- OSC 12 and the foreground is ignored there.
--
-- `ve` had to come out of the Insert part to say any of it. Visual with
-- exclusive selection matches `ve` and not `v`, so it was riding on Insert's
-- entry all along and would have taken Insert's color, which is the one thing
-- the color is there to prevent. Every shape is what it was.
vim.opt.guicursor = "n:ver25-Cursor,v:block-vCursor,ve:ver25-vCursor,c-sm:block-cCursor,"
  .. "i-ci:ver25-iCursor,r-cr:hor20-rCursor,o:hor20-oCursor,"
  .. "t:block-blinkon500-blinkoff500-TermCursor"

-- 'clipboard' is deliberately left empty. It can only make the unnamed
-- register *be* the clipboard, which puts every delete on the clipboard along
-- with the copies; `y` and `p` reach it through mappings instead, and Vim's
-- registers stay as they ship. lua/mivn/keymaps.lua has the whole account.
-- `:checkhealth provider` names the provider Neovim picked either way.

-- Greek layout. 'langmap' translates each Greek letter to the Latin one on the
-- same physical key, but only in Normal, Visual, Select and Operator-pending
-- mode: Insert mode and searches are untouched, so Greek prose still types as
-- Greek.
--
-- Letters only, and that is a hard limit. 'langmap' is a global character
-- table with no idea which layout is live, and it is safe for letters purely
-- because Greek and Latin letters are disjoint. Punctuation is not: mapping ;
-- to q would rebind ; on the US layout too. `:h langmap` stops at letters for
-- the same reason, and DEFAULTS.md has the full account.
--
-- One edge in the letters themselves: ς and σ both uppercase to Σ, so Σ is
-- given to S and Shift+W has no Greek twin. 'langremap' is off by default,
-- which is what keeps this from being applied twice once there are mappings.
vim.opt.langmap = table.concat({
  "ςερτυθιοπασδφγηξκλζχψωβνμ;wertyuiopasdfghjklzxcvbnm",
  "ΣΕΡΤΥΘΙΟΠΑΔΦΓΗΞΚΛΖΧΨΩΒΝΜ;SERTYUIOPADFGHJKLZXCVBNM",
}, ",")

-- mivn's default theme; lives in colors/ next to this file.
vim.cmd.colorscheme("basalt")

require("mivn.swap") -- answers the prompt about a swap file no editor is using
require("mivn.plugins") -- vim.pack; every module below is one of its consumers
require("mivn.treesitter") -- grammars, highlighting, injections
require("mivn.lsp") -- language servers, diagnostics, format on save; one file per language
require("mivn.hints") -- the LSP inlay hints, and which languages start without them
require("mivn.complete") -- the Insert-mode completion menu
require("mivn.pairs") -- auto-closing pairs; complete.lua's Enter calls into it
require("mivn.diff") -- git changes in the gutter
require("mivn.page") -- PageUp and PageDown, over the file and over the menu
require("mivn.restart") -- :restart, refused when the window is remote
require("mivn.terminal") -- the terminal panel and its toggle
require("mivn.margins") -- the 80/100/120 width markers
require("mivn.occurrences") -- the other copies of what is selected
require("mivn.zoom") -- Ctrl and =, - or 0, under Neovide alone
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
