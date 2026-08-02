-- mivn: the whole configuration, for now. Almost all of it is options; the
-- only mappings are the four command-line keys below, and they come out of
-- `:h cmdline-autocompletion`.

-- Leader is Space, and it has to be set before anything maps against it.
-- Nothing is lost: Space in Normal mode repeats `l`.
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- On by default since 0.9, set explicitly because it is the source of truth
-- for indentation: a project's .editorconfig wins over the fallbacks below.
vim.g.editorconfig = true

-- A project can carry its own editor config: a .nvim.lua in the project or
-- any directory above it runs after this file, so vim.lsp.config() calls
-- there merge over lua/mivn/lsp.lua's defaults. Guarded by Neovim's trust
-- prompt on first load; :trust manages the answers. Personal, machine-side
-- knobs live in lua/mivn/local.lua instead.
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
vim.opt.scrolloff = 4
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

-- 'cmdheight' keeps its default 1. At 0, a message with no line to print on
-- turns into a modal "Press ENTER" prompt. The two settings below came out of
-- that experiment and stay on their own merits.

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

-- The four keys, and the only mappings in this file. `:h
-- cmdline-autocompletion` gives this exact recipe with the two arms the other
-- way round; the menu is open most of the time here, and a menu I cannot walk
-- with the arrows is a menu I have to learn a key for.
--
-- Measured, in file completion: `Down` does nothing at all and `Up` moves the
-- completion out into the parent directory, silently turning `:e lua/mivn/tr`
-- into `:e lua/`. Shift+Up and Shift+Down are not reliably history either,
-- since an open file menu takes them too, so they get `Ctrl+E` first: the key
-- that ends completion and puts back what I typed.
--
-- Note the two kinds of history key differ. `Up` and `Down` recall only the
-- commands starting with what is on the line; Shift and the arrows walk the
-- whole history unfiltered. PageUp and PageDown are left alone, because while
-- the menu is open they page it.
local function cmdline_key(in_menu, plain)
  return function()
    return vim.fn.wildmenumode() == 1 and in_menu or plain
  end
end

vim.keymap.set("c", "<Down>", cmdline_key("<C-n>", "<Down>"), {
  expr = true,
  desc = "Next match while the menu is open, newer history otherwise",
})

vim.keymap.set("c", "<Up>", cmdline_key("<C-p>", "<Up>"), {
  expr = true,
  desc = "Previous match while the menu is open, older history otherwise",
})

vim.keymap.set("c", "<S-Down>", cmdline_key("<C-e><S-Down>", "<S-Down>"), {
  expr = true,
  desc = "Newer command-line history, menu or no menu",
})

vim.keymap.set("c", "<S-Up>", cmdline_key("<C-e><S-Up>", "<S-Up>"), {
  expr = true,
  desc = "Older command-line history, menu or no menu",
})

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

-- Shift and an arrow selects, the one habit from Emacs and Zed worth carrying
-- over. No mapping is involved: Vim already binds the shifted arrows to
-- motions, and these three options decide that pressing one starts a selection
-- the motion then extends. Note the shifted keys change meaning rather than
-- only gaining a selection: Shift+Up and Shift+Down are page motions in stock
-- Neovim, one line here.
--
-- All three are needed. 'keymodel' is what makes a shifted key start a
-- selection and an unshifted one end it. 'selectmode' makes that selection
-- Select rather than Visual, where the letters I type would run as commands
-- instead of replacing it. 'selection' has to be exclusive because the
-- inclusive default counts the character under the cursor, so typing over a
-- selection replaces one too many. "mouse" is there so a drag lands in Select
-- mode too; <C-g> switches between Select and Visual.
--
-- Two costs. "stopsel" means an unshifted arrow ends a Visual selection
-- instead of extending it, so hjkl is how I adjust one. And exclusive takes
-- one character off a character-wise Visual yank: on "amm", `vlly` yanks "am".
-- Text objects and operators are unaffected.
vim.opt.keymodel = "startsel,stopsel"
vim.opt.selectmode = "key,mouse"
vim.opt.selection = "exclusive"

-- The unnamed register and the system clipboard become one register, so `y`
-- copies out of the editor and `p` pastes what any other window put on the
-- clipboard. `:checkhealth provider` names the provider Neovim picked.
--
-- The cost: `d`, `c` and `x` write to a register too, so each of them now
-- overwrites the clipboard. `"_d` is the black hole register and avoids it,
-- and `"0p` still pastes the last *yank*, past any delete since.
vim.opt.clipboard = "unnamedplus"

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

require("mivn.plugins") -- vim.pack, and it must come first
require("mivn.treesitter") -- grammars, highlighting, injections
require("mivn.lsp") -- language servers, diagnostics, format on save
require("mivn.lsp.managed") -- the server store's wiring, dialog, and :MivnLsp
require("mivn.complete") -- the Insert-mode completion menu
require("mivn.pairs") -- auto-closing pairs; complete.lua's Enter calls into it
require("mivn.diff") -- git changes in the gutter
require("mivn.page") -- PageUp and PageDown, over the file and over the menu
require("mivn.cua") -- the CUA edit keys that are mappings rather than options
require("mivn.restart") -- :restart, refused when the window is remote
require("mivn.terminal") -- the terminal panel and its toggle
require("mivn.margins") -- the 80/100/120 width markers
require("mivn.find") -- fuzzy finding, and the few keys Vim has no default for
require("mivn.prompt") -- vim.ui.input as a float instead of the bottom bar
require("mivn.whichkey") -- shows what can follow a key I started typing
require("mivn.dashboard") -- the landing buffer
require("mivn.tree") -- the file tree, loaded after the dashboard claims a window
require("mivn.tabline") -- the buffer tab bar
require("mivn.statusline") -- the status line, and where the mode is shown
