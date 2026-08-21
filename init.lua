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
local ui2 = pcall(function()
  require("vim._core.ui2").enable({})
end)

if ui2 then
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

-- 'cmdheight' keeps its default 1. At 0, a message with no line to print on
-- turns into a modal "Press ENTER" prompt; ui2 above removes that prompt, so
-- the experiment is worth rerunning once ui2 has earned trust. The two
-- settings below came out of that experiment and stay on their own merits.

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
vim.opt.keymodel = "startsel,stopsel"
vim.opt.selection = "exclusive"

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

require("mivn.plugins") -- vim.pack; every module below is one of its consumers
require("mivn.treesitter") -- grammars, highlighting, injections
require("mivn.lsp") -- language servers, diagnostics, format on save; one file per language
require("mivn.complete") -- the Insert-mode completion menu
require("mivn.pairs") -- auto-closing pairs; complete.lua's Enter calls into it
require("mivn.diff") -- git changes in the gutter
require("mivn.page") -- PageUp and PageDown, over the file and over the menu
require("mivn.restart") -- :restart, refused when the window is remote
require("mivn.terminal") -- the terminal panel and its toggle
require("mivn.margins") -- the 80/100/120 width markers
require("mivn.zoom") -- Ctrl and =, - or 0, under Neovide alone
require("mivn.find") -- fuzzy finding, and the few keys Vim has no default for
require("mivn.external") -- PDFs and their kin offered to the system opener
require("mivn.prompt") -- vim.ui.input as a float instead of the bottom bar
require("mivn.whichkey") -- shows what can follow a key I started typing
require("mivn.session") -- what happens when buffers and windows run out
require("mivn.dashboard") -- the landing buffer
require("mivn.update") -- whether a newer mivn is out, said once on the banner
require("mivn.tree") -- the file tree, loaded after the dashboard claims a window
require("mivn.tabline") -- the buffer tab bar
require("mivn.statusline") -- the status line, and where the mode is shown
require("mivn.keymaps") -- every key mivn takes; last, so it can call into them
