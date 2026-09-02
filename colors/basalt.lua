-- basalt: my dark theme, named for what magma becomes when it cools. It began
-- as Modest Dark, a Zed theme by Tim Cole (https://github.com/timcole/modest-
-- dark, MIT), and is now its own palette, in its own repository, which my
-- terminal and my shell prompt read as well.
--
-- The split is worth knowing before changing anything here. basalt owns the
-- values: it decides what orange is and how far a wash sits from the page.
-- This file owns the roles: it decides that a git branch is orange and that a
-- selection is a magenta wash. So a colour that is the wrong shade is a
-- question for basalt, and a colour on the wrong thing is a question for the
-- table below.
--
-- Written out rather than pulled from a plugin, and copied rather than
-- generated. A colorscheme is a table of highlight groups, so a dependency
-- here would buy nothing, and a generator would buy less: the values move
-- rarely and the reasons live in this file, where a generator cannot carry
-- them.
--
-- This file owns every highlight group mivn sets, the plugins' and my own
-- included. No module under lua/mivn/ defines one, and no module names a color:
-- the palette below is the only place a hex lives. That costs the plugin
-- sections here being written for plugins this file cannot check are installed,
-- which is free: a highlight group nothing draws with is a few bytes in a
-- table. What it buys is one place to look when a color is wrong, and one pass
-- that leaves everything colored, so `:colorscheme basalt` on a running editor
-- restores the whole screen instead of the half of it a colorscheme used to
-- own.

vim.cmd.highlight("clear")
vim.g.colors_name = "basalt"
vim.o.termguicolors = true
vim.o.background = "dark"

-- The palette, in basalt's own names and under its one rule: a dot means an
-- accent, no dot means a surface. Every value is copied from basalt.json in
-- the basalt repository and nothing here invents one, so a colour that looks
-- wrong is either the wrong entry picked below or a question for basalt.
--
-- The surfaces are a scale, deepest to lightest, and the order is the whole
-- idea: what sits beside or behind the file goes under the page, what is
-- drawn on top of the file goes over it. The depth step is what separates two
-- surfaces, which is why the tree needs no visible separator.
--
-- Each accent carries four renditions. `text` is the accent as writing.
-- `deep` is a saturated fill. `container` is a dimmed ground with ordinary
-- text on it, and `wash` is a fainter ground meant to sit under text that is
-- already coloured, which is what every tint in this file wants.
local c = {
  sunk = "#08090C", -- behind the page: the tree, the tab strip, inactive tabs
  page = "#0F1217", -- the page: the buffer and its number and sign columns
  inlay = "#13161D", -- in the window but not in the file: folds, inlay hints,
  -- diagnostic virtual text, the old text the diff overlay shows
  row = "#171B23", -- the line the caret is on
  raised = "#1E242F", -- over the page: floats, popups, the status line, the
  -- active tab, separators, indent guides
  lifted = "#272E3C", -- over the raised: a control on a chip, the code-lens
  -- separator
  guide = "#434E65", -- the scrollbar thumb, listchars
  faint = "#58647D", -- line numbers, inactive tab text
  muted = "#717D94", -- comments, untracked files
  dim = "#8D96AA", -- secondary text that still has to be read
  body = "#AEB4C0", -- ordinary text
  bright = "#D2D4D9", -- text being emphasised, and text on a deep fill

  red = { -- errors, deletions, danger
    text = "#EA696E",
    deep = "#8F1F2C",
    wash = "#470810",
    container = "#572728",
  },

  orange = { -- warnings, constants, destructive controls
    text = "#F68C36",
    deep = "#754017",
    wash = "#3B1A00",
    container = "#542C0D",
  },

  yellow = { -- types, and what is changed but unsaved
    text = "#EABF39",
    deep = "#604E18",
    wash = "#302400",
    container = "#463600",
  },

  green = { -- strings, additions, what has gone right
    text = "#7FD36D",
    deep = "#265E18",
    wash = "#072D00",
    container = "#22411B",
  },

  cyan = { -- escapes, links, macros: what points outside the code
    text = "#37C0C7",
    deep = "#1B5A5D",
    wash = "#003336",
    container = "#004144",
  },

  blue = { -- functions, focus, what is being acted on
    text = "#6AB0F7",
    deep = "#195286",
    wash = "#00294D",
    container = "#173A5C",
  },

  magenta = { -- keywords, and the selection
    text = "#D986E6",
    deep = "#742B7F",
    wash = "#37103E",
    container = "#492A4E",
  },

  -- The two steps between red and its container that the dashboard's fire
  -- gradient needs and the scale above has no name for. Nothing else may use
  -- them; they are named here only so every hex stays in this table.
  fire4 = "#BC4D58",
  fire5 = "#893B45",
}

local function hl(groups)
  for name, spec in pairs(groups) do
    vim.api.nvim_set_hl(0, name, spec)
  end
end

--- Editor chrome ------------------------------------------------------------

hl({
  Normal = { fg = c.body, bg = c.page },
  NormalNC = { fg = c.body, bg = c.page },
  NormalFloat = { fg = c.body, bg = c.raised },
  FloatBorder = { fg = c.muted, bg = c.raised },
  FloatTitle = { fg = c.blue.text, bg = c.raised, bold = true },

  -- The caret carries the mode, in the same hues the status line's mode block
  -- uses, and lua/mivn/init.lua's 'guicursor' names which group goes with
  -- which mode. `sunk` for the text under a block, because that is the color
  -- foot draws it in and this is what makes Neovide agree with it. In a
  -- terminal the foreground is ignored and only the background travels, as
  -- OSC 12.
  Cursor = { fg = c.sunk, bg = c.blue.text },
  lCursor = { link = "Cursor" },
  iCursor = { fg = c.sunk, bg = c.green.text },
  vCursor = { fg = c.sunk, bg = c.magenta.text },
  rCursor = { fg = c.sunk, bg = c.red.text },
  cCursor = { fg = c.sunk, bg = c.yellow.text },
  oCursor = { fg = c.sunk, bg = c.cyan.text },
  TermCursor = { fg = c.sunk, bg = c.cyan.text },

  -- Select's caret, orange the way its mode block and its selection are.
  -- 'guicursor' has no Select mode to name it in, so lua/mivn/select.lua
  -- hangs it on every mode for as long as Select lasts.
  MivnCursorSelect = { fg = c.sunk, bg = c.orange.text },
  CursorLine = { bg = c.row },
  CursorColumn = { bg = c.row },
  ColorColumn = { bg = c.raised },

  LineNr = { fg = c.faint, bg = c.page },
  CursorLineNr = { fg = c.body, bg = c.row, bold = true },
  SignColumn = { bg = c.page },
  FoldColumn = { fg = c.faint, bg = c.page },
  Folded = { fg = c.muted, bg = c.inlay },

  -- A tint rather than another grey, in Visual's own hue, so that the mode
  -- block, the caret and the selection all say magenta at once. The wash is
  -- the rendition made for this: a ground meant to sit under text that is
  -- already coloured, where a flat fill would bury the code I still have to
  -- read.
  --
  -- Over the page and not the active row: 'cursorline' is documented as not
  -- used while Visual is active, so the row under a selection is the page.
  Visual = { bg = c.magenta.wash },
  VisualNOS = { bg = c.magenta.wash },

  -- Select mode's own tint, orange the way the status line's Select block is.
  -- Every wash but two sits at one lightness, so which mode I am in changes
  -- the hue of what is picked out and not how well I can read it.
  -- Neovim paints Visual and Select with the one `Visual` group, so the
  -- window in Select points that group here for as long as it is in it;
  -- lua/mivn/select.lua is what does the pointing.
  MivnSelect = { bg = c.orange.wash },

  -- The other copies of what is selected (lua/mivn/occurrences.lua). Cyan is
  -- one of the two washes that sit above the common lightness, and this mark
  -- is why: sRGB has no dark teal with the chroma to separate from the row
  -- the caret is on, which is the row a selection is always on, so the wash
  -- buys the separation with lightness instead. Measured on screen, against
  -- five candidates.
  --
  -- It started as Visual's own magenta at a weaker strength, on the argument
  -- that the same hue would say "the same text"; on screen it only said
  -- "another selection", and the one place the caret actually was took a
  -- second to find. So the copies get a hue of their own, and the only
  -- magenta in the window is the selection. Not Search's yellow either,
  -- which answers a different question.
  MivnOccurrence = { bg = c.cyan.wash },

  Search = { fg = c.page, bg = c.yellow.text },
  IncSearch = { fg = c.page, bg = c.orange.text },
  CurSearch = { fg = c.page, bg = c.orange.text },
  MatchParen = { fg = c.cyan.text, bold = true },

  -- The indent guide color doubles as every window-splitting line, which is
  -- what keeps splits from drawing a bright seam across the screen.
  WinSeparator = { fg = c.raised, bg = c.page },
  VertSplit = { link = "WinSeparator" },

  Pmenu = { fg = c.body, bg = c.raised },
  PmenuSel = { fg = c.bright, bg = c.guide, bold = true },
  PmenuKind = { fg = c.blue.text, bg = c.raised },
  PmenuKindSel = { fg = c.blue.text, bg = c.guide },
  PmenuExtra = { fg = c.muted, bg = c.raised },
  PmenuExtraSel = { fg = c.body, bg = c.guide },
  PmenuSbar = { bg = c.raised },
  PmenuThumb = { bg = c.guide },
  PmenuBorder = { link = "FloatBorder" },
  PmenuShadow = { bg = c.sunk },
  PmenuShadowThrough = { bg = c.sunk },

  -- The letters of a match that the query hit, in the picker's own yellow
  -- so the two menus read the same way; `fuzzy` in 'completeopt' is what
  -- makes them worth marking, since they are then rarely a prefix.
  PmenuMatch = { fg = c.yellow.text, bg = c.raised, bold = true },
  PmenuMatchSel = { fg = c.yellow.text, bg = c.guide, bold = true },

  -- What a match would insert, drawn in the line as the menu is walked.
  -- The same ground the inlay hints and the diff overlay take: in the
  -- window but not in the file.
  ComplMatchIns = { fg = c.dim, bg = c.inlay },
  WildMenu = { link = "PmenuSel" },

  StatusLine = { fg = c.body, bg = c.raised },
  StatusLineNC = { fg = c.faint, bg = c.inlay },
  WinBar = { fg = c.body, bg = c.page },
  WinBarNC = { fg = c.faint, bg = c.page },

  TabLine = { fg = c.faint, bg = c.page },
  TabLineSel = { fg = c.body, bg = c.raised },
  TabLineFill = { bg = c.sunk },

  Directory = { fg = c.blue.text },
  Title = { fg = c.blue.text, bold = true },
  Conceal = { fg = c.faint },
  NonText = { fg = c.raised },
  Whitespace = { fg = c.guide },
  SpecialKey = { fg = c.guide },
  EndOfBuffer = { fg = c.page },
  QuickFixLine = { bg = c.raised, bold = true },

  ErrorMsg = { fg = c.red.text },
  WarningMsg = { fg = c.yellow.text },
  MoreMsg = { fg = c.green.text },
  Question = { fg = c.blue.text },
  ModeMsg = { fg = c.body, bold = true },
  MsgArea = { fg = c.body, bg = c.page },

  -- The three kinds ui2 tells apart in what a shell command prints and in a
  -- message that says something went right: stock links them to the message
  -- groups above, said outright so this file stays the whole list.
  OkMsg = { link = "MoreMsg" },
  StderrMsg = { link = "ErrorMsg" },
  StdoutMsg = { fg = c.body },

  -- The placeholder a snippet is on, while Tab steps through them. The
  -- selection is Select's orange already; this is the faint ring the other
  -- placeholders get, so the next stop can be seen before it is reached.
  SnippetTabstop = { bg = c.inlay },
  SnippetTabstopActive = { bg = c.orange.wash },
})

--- Syntax, the classic groups ------------------------------------------------

-- These still drive any language without a tree-sitter grammar, and the
-- @-captures below link into them where the meaning is the same.
hl({
  Comment = { fg = c.muted, italic = true },

  Constant = { fg = c.orange.text },
  String = { fg = c.green.text },
  Character = { fg = c.green.text },
  Number = { fg = c.orange.text },
  Boolean = { fg = c.orange.text },
  Float = { fg = c.orange.text },

  Identifier = { fg = c.body },
  Function = { fg = c.blue.text },

  Statement = { fg = c.magenta.text, bold = true },
  Conditional = { fg = c.magenta.text, bold = true },
  Repeat = { fg = c.magenta.text, bold = true },
  Label = { fg = c.magenta.text },
  Operator = { fg = c.body },
  Keyword = { fg = c.magenta.text, bold = true },
  Exception = { fg = c.magenta.text, bold = true },

  PreProc = { fg = c.magenta.text },
  Include = { fg = c.magenta.text, bold = true },
  Define = { fg = c.magenta.text },
  Macro = { fg = c.magenta.text },
  PreCondit = { fg = c.magenta.text },

  Type = { fg = c.yellow.text },
  StorageClass = { fg = c.magenta.text, bold = true },
  Structure = { fg = c.yellow.text },
  Typedef = { fg = c.yellow.text },

  Special = { fg = c.cyan.text },
  SpecialChar = { fg = c.cyan.text },
  Tag = { fg = c.red.text },
  Delimiter = { fg = c.body },
  SpecialComment = { fg = c.muted, italic = true, bold = true },
  Debug = { fg = c.red.text },

  Underlined = { underline = true },
  Ignore = { fg = c.guide },
  Error = { fg = c.red.text },
  Todo = { fg = c.page, bg = c.yellow.text, bold = true },
})

--- Tree-sitter captures -----------------------------------------------------

hl({
  ["@variable"] = { fg = c.body },
  ["@variable.builtin"] = { fg = c.yellow.text },
  ["@variable.parameter"] = { fg = c.body },
  ["@variable.member"] = { fg = c.red.text },

  ["@constant"] = { fg = c.orange.text },
  ["@constant.builtin"] = { fg = c.orange.text },
  ["@constant.macro"] = { fg = c.magenta.text },

  ["@module"] = { fg = c.yellow.text },
  ["@label"] = { fg = c.magenta.text },

  ["@string"] = { fg = c.green.text },
  ["@string.documentation"] = { fg = c.green.text },
  ["@string.regexp"] = { fg = c.cyan.text },
  ["@string.escape"] = { fg = c.cyan.text, bold = true },
  ["@string.special"] = { fg = c.cyan.text },
  ["@string.special.url"] = { fg = c.cyan.text, underline = true },
  ["@character"] = { fg = c.green.text },
  ["@character.special"] = { fg = c.cyan.text },

  ["@boolean"] = { fg = c.orange.text },
  ["@number"] = { fg = c.orange.text },
  ["@number.float"] = { fg = c.orange.text },

  ["@type"] = { fg = c.yellow.text },
  ["@type.builtin"] = { fg = c.yellow.text },
  ["@type.definition"] = { fg = c.yellow.text },
  ["@attribute"] = { fg = c.magenta.text },
  ["@property"] = { fg = c.red.text },

  ["@function"] = { fg = c.blue.text },
  ["@function.builtin"] = { fg = c.blue.text },
  ["@function.call"] = { fg = c.blue.text },
  ["@function.macro"] = { fg = c.magenta.text },
  ["@function.method"] = { fg = c.blue.text },
  ["@function.method.call"] = { fg = c.blue.text },
  ["@constructor"] = { fg = c.yellow.text },

  ["@operator"] = { fg = c.body },

  ["@keyword"] = { fg = c.magenta.text, bold = true },
  ["@keyword.function"] = { fg = c.magenta.text, bold = true },
  ["@keyword.operator"] = { fg = c.magenta.text, bold = true },
  ["@keyword.import"] = { fg = c.magenta.text, bold = true },
  ["@keyword.type"] = { fg = c.magenta.text, bold = true },
  ["@keyword.modifier"] = { fg = c.magenta.text, bold = true },
  ["@keyword.repeat"] = { fg = c.magenta.text, bold = true },
  ["@keyword.return"] = { fg = c.magenta.text, bold = true },
  ["@keyword.debug"] = { fg = c.red.text },
  ["@keyword.exception"] = { fg = c.magenta.text, bold = true },
  ["@keyword.conditional"] = { fg = c.magenta.text, bold = true },
  ["@keyword.directive"] = { fg = c.magenta.text },

  ["@punctuation.delimiter"] = { fg = c.body },
  ["@punctuation.bracket"] = { fg = c.body },
  ["@punctuation.special"] = { fg = c.cyan.text },

  ["@comment"] = { fg = c.muted, italic = true },
  ["@comment.documentation"] = { fg = c.muted, italic = true },
  ["@comment.error"] = { fg = c.page, bg = c.red.text, bold = true },
  ["@comment.warning"] = { fg = c.page, bg = c.yellow.text, bold = true },
  ["@comment.todo"] = { fg = c.page, bg = c.blue.text, bold = true },
  ["@comment.note"] = { fg = c.page, bg = c.cyan.text, bold = true },

  ["@tag"] = { fg = c.red.text },
  ["@tag.builtin"] = { fg = c.red.text },
  ["@tag.attribute"] = { fg = c.orange.text },
  ["@tag.delimiter"] = { fg = c.body },

  ["@markup.strong"] = { bold = true },
  ["@markup.italic"] = { italic = true },
  ["@markup.strikethrough"] = { strikethrough = true },
  ["@markup.underline"] = { underline = true },
  ["@markup.heading"] = { fg = c.blue.text, bold = true },
  ["@markup.quote"] = { fg = c.muted, italic = true },
  ["@markup.math"] = { fg = c.cyan.text },
  ["@markup.link"] = { fg = c.cyan.text },
  ["@markup.link.label"] = { fg = c.blue.text },
  ["@markup.link.url"] = { fg = c.cyan.text, underline = true },
  ["@markup.raw"] = { fg = c.green.text },
  ["@markup.list"] = { fg = c.magenta.text },
  ["@markup.list.checked"] = { fg = c.green.text },
  ["@markup.list.unchecked"] = { fg = c.muted },

  ["@diff.plus"] = { fg = c.green.text },
  ["@diff.minus"] = { fg = c.red.text },
  ["@diff.delta"] = { fg = c.yellow.text },
})

--- Language server ----------------------------------------------------------

hl({
  -- Semantic tokens sit on top of tree-sitter and should agree with it, so
  -- these link rather than restate.
  ["@lsp.type.class"] = { link = "@type" },
  ["@lsp.type.comment"] = {},
  ["@lsp.type.enum"] = { link = "@type" },
  ["@lsp.type.enumMember"] = { link = "@constant" },
  ["@lsp.type.function"] = { link = "@function" },
  ["@lsp.type.interface"] = { link = "@type" },
  ["@lsp.type.keyword"] = { link = "@keyword" },
  ["@lsp.type.method"] = { link = "@function.method" },
  ["@lsp.type.namespace"] = { link = "@module" },
  ["@lsp.type.parameter"] = { link = "@variable.parameter" },
  ["@lsp.type.property"] = { link = "@property" },

  -- WARN: cleared, like the comment token above, and for a sharper reason. A
  -- semantic token is drawn at priority 125 and tree-sitter at 100, so a
  -- server marking a whole string literal as a string paints over whatever is
  -- injected inside it. In Go that is the SQL in queries/go/injections.scm:
  -- the fragment parsed, the keywords were captured, and every one of them
  -- still came out the green of the string around it (measured 2026-08-27,
  -- gopls). Cleared, the token paints nothing and the injection shows through.
  ["@lsp.type.string"] = {},

  ["@lsp.type.struct"] = { link = "@type" },
  ["@lsp.type.type"] = { link = "@type" },
  ["@lsp.type.typeParameter"] = { link = "@type" },
  ["@lsp.type.variable"] = { link = "@variable" },

  LspReferenceText = { bg = c.raised },
  LspReferenceRead = { bg = c.raised },
  LspReferenceWrite = { bg = c.raised, underline = true },
  LspInlayHint = { fg = c.faint, bg = c.inlay, italic = true },
  LspSignatureActiveParameter = { fg = c.orange.text, bold = true },
  LspCodeLens = { fg = c.faint, italic = true },
  LspCodeLensSeparator = { fg = c.lifted, italic = true },

  DiagnosticError = { fg = c.red.text },
  DiagnosticWarn = { fg = c.yellow.text },
  DiagnosticInfo = { fg = c.blue.text },
  DiagnosticHint = { fg = c.body },
  DiagnosticOk = { fg = c.green.text },

  DiagnosticVirtualTextError = { fg = c.red.text, bg = c.inlay },
  DiagnosticVirtualTextWarn = { fg = c.yellow.text, bg = c.inlay },
  DiagnosticVirtualTextInfo = { fg = c.blue.text, bg = c.inlay },
  DiagnosticVirtualTextHint = { fg = c.muted, bg = c.inlay },

  DiagnosticUnderlineError = { undercurl = true, sp = c.red.text },
  DiagnosticUnderlineWarn = { undercurl = true, sp = c.yellow.text },
  DiagnosticUnderlineInfo = { undercurl = true, sp = c.blue.text },
  DiagnosticUnderlineHint = { undercurl = true, sp = c.muted },

  -- Dimmed rather than colored: unused code is a hint, not a problem.
  DiagnosticUnnecessary = { fg = c.faint },
  DiagnosticDeprecated = { fg = c.faint, strikethrough = true },
})

--- Diffs and version control -------------------------------------------------

hl({
  DiffAdd = { bg = c.green.container },
  DiffDelete = { fg = c.red.text, bg = c.red.container },
  DiffChange = { bg = c.raised },
  DiffText = { bg = c.green.container },
  -- The words added within a changed line, since 'diffopt' draws inline
  -- changes by default now; the same ground as a changed word, one step
  -- brighter is not a step this palette has.
  DiffTextAdd = { bg = c.green.container },

  -- The file-status colors the tree and the gutter share.
  Added = { fg = c.green.text },
  Removed = { fg = c.red.text },
  Changed = { fg = c.yellow.text },
})

--- Terminal ------------------------------------------------------------------

-- :terminal buffers, so a shell inside Neovim matches foot outside it. The
-- sixteen slots are foot's, entry for entry, with one deliberate difference:
-- slot 0 is `sunk` here and `row` there. foot draws its window on `sunk`, so a
-- slot 0 that matched it would render black text invisible; a :terminal buffer
-- draws on the page, which `sunk` already sits under. Measured, the two
-- choices are 1.06:1 and 1.09:1 against the page, so nothing turns on it.
--
-- WARN: the bright half repeats the regular half for slots 9 to 14. basalt has
-- one text weight per accent and no lifted rendition, and inventing one here
-- would put a colour on screen that is in no palette. So a program drawing
-- bright red beside red gets one red, and bold carries the difference, which
-- is the signal those programs pair with the bright slot anyway. foot's
-- config says the same thing on its own side.
vim.g.terminal_color_0 = c.sunk
vim.g.terminal_color_1 = c.red.text
vim.g.terminal_color_2 = c.green.text
vim.g.terminal_color_3 = c.yellow.text
vim.g.terminal_color_4 = c.blue.text
vim.g.terminal_color_5 = c.magenta.text
vim.g.terminal_color_6 = c.cyan.text
vim.g.terminal_color_7 = c.body
vim.g.terminal_color_8 = c.faint
vim.g.terminal_color_9 = c.red.text
vim.g.terminal_color_10 = c.green.text
vim.g.terminal_color_11 = c.yellow.text
vim.g.terminal_color_12 = c.blue.text
vim.g.terminal_color_13 = c.magenta.text
vim.g.terminal_color_14 = c.cyan.text
vim.g.terminal_color_15 = c.bright

--- The status line -----------------------------------------------------------

-- The mode block: the accent as a background, the darkest background as text.
-- Each mode gets the color the theme already uses for the thing that mode is
-- about, so the association is one I am learning anyway from the syntax
-- highlighting.
hl({
  MiniStatuslineModeNormal = { fg = c.sunk, bg = c.blue.text, bold = true }, -- functions
  MiniStatuslineModeInsert = { fg = c.sunk, bg = c.green.text, bold = true }, -- strings
  MiniStatuslineModeVisual = { fg = c.sunk, bg = c.magenta.text, bold = true }, -- keywords

  -- Orange is constants, the one accent left free; red is errors, and Replace
  -- overwrites.
  MiniStatuslineModeSelect = { fg = c.sunk, bg = c.orange.text, bold = true },
  MiniStatuslineModeReplace = { fg = c.sunk, bg = c.red.text, bold = true },

  MiniStatuslineModeCommand = { fg = c.sunk, bg = c.yellow.text, bold = true }, -- types
  MiniStatuslineModeOther = { fg = c.sunk, bg = c.cyan.text, bold = true }, -- terminal, rest

  -- The branch in orange, for what orange means here: a fixed label naming
  -- where I am, which is the company constants and numbers keep. The dirty
  -- dot rides along: it is one token with the name, and yellow already means
  -- "modified" elsewhere.
  --
  -- Yellow was the other candidate and it lost on that same test. Yellow is
  -- this palette's attention color, warnings and Todo and Search, and it is
  -- "modified" in the tree, the tabline and the gutter as well. A branch name
  -- is on screen every second and asks for none of that.
  --
  -- WARN: this used to say the color came from my shell prompt, and that is
  -- the one reason it must not give. The prompt asks for ANSI slot 3, which
  -- is yellow here (terminal_color_3 above) and yellow in foot as well now,
  -- so the two stopped agreeing inside a :terminal without a line here
  -- changing. The prompt lives in my dotfiles repository and names basalt's
  -- orange outright rather than borrowing a slot, so the two agree again;
  -- that is welcome and it is still not the reason. Either way, do not
  -- repaint this one to chase the other.
  MivnStatuslineGit = { fg = c.orange.text, bg = c.raised },

  -- Who wrote the line the cursor is on takes the file name's own colors: it
  -- is the same kind of thing, something the file says about itself rather
  -- than something I watch. The low background is what parts it from the
  -- filetype beside it, which on the raised one ran together with it into a
  -- single block. It still loses to everything around it, which is the point,
  -- and sinking the surface leaves it a little easier to read than the grey it
  -- had.
  MivnStatuslineBlame = { fg = c.muted, bg = c.inlay },

  -- `%=` fills with whatever color is in force, which is the file name's, so
  -- the low background runs from the name through the empty middle and comes
  -- out again under the blame. The line reads as a raised block at each end
  -- with a trough between them: what I watch sits on the raised part, what is
  -- only context sits in the trough.
  MiniStatuslineDevinfo = { fg = c.body, bg = c.raised },
  MiniStatuslineFileinfo = { fg = c.body, bg = c.raised },
  MiniStatuslineFilename = { fg = c.muted, bg = c.inlay },
  MiniStatuslineInactive = { fg = c.faint, bg = c.inlay },
})

--- The tab bar ---------------------------------------------------------------

hl({
  -- The active tab lifts to the panel background, the rest sit back on the
  -- editor background.
  MiniTablineCurrent = { fg = c.body, bg = c.raised, bold = true },
  MiniTablineVisible = { fg = c.muted, bg = c.sunk },
  MiniTablineHidden = { fg = c.faint, bg = c.sunk },

  -- Unsaved changes are the one thing worth coloring, so an unwritten buffer is
  -- obvious without reading the name.
  MiniTablineModifiedCurrent = { fg = c.yellow.text, bg = c.raised, bold = true },
  MiniTablineModifiedVisible = { fg = c.yellow.text, bg = c.sunk },
  MiniTablineModifiedHidden = { fg = c.orange.text, bg = c.sunk },

  MiniTablineFill = { bg = c.sunk },
  MiniTablineTabpagesection = { fg = c.page, bg = c.magenta.text, bold = true },

  -- The strip that stands in for the tree above it, so the gap reads as the
  -- panel continuing upward rather than as an empty tab.
  MivnTablineTreeFill = { link = "NvimTreeNormal" },
})

--- The file tree -------------------------------------------------------------

hl({
  -- Git state, the same four colors the gutter and the tab bar use.
  NvimTreeGitFileNewHL = { fg = c.muted }, -- untracked
  NvimTreeGitFileDirtyHL = { fg = c.yellow.text }, -- modified
  NvimTreeGitFileStagedHL = { fg = c.green.text }, -- added
  NvimTreeGitFileDeletedHL = { fg = c.red.text },
  NvimTreeGitFileMergeHL = { fg = c.red.text },
  NvimTreeGitFileRenamedHL = { fg = c.blue.text },

  NvimTreeGitFolderNewHL = { fg = c.muted },
  NvimTreeGitFolderDirtyHL = { fg = c.yellow.text },
  NvimTreeGitFolderStagedHL = { fg = c.green.text },

  -- Panel chrome: a shade off the editor background so the split reads as a
  -- panel without needing a bright separator.
  NvimTreeNormal = { fg = c.body, bg = c.sunk },
  NvimTreeNormalNC = { fg = c.body, bg = c.sunk },
  NvimTreeWinSeparator = { fg = c.sunk, bg = c.sunk },
  NvimTreeRootFolder = { fg = c.magenta.text, bold = true },
  NvimTreeFolderName = { fg = c.blue.text },
  NvimTreeOpenedFolderName = { fg = c.blue.text, bold = true },
  NvimTreeEmptyFolderName = { fg = c.faint },
  NvimTreeIndentMarker = { fg = c.raised },
  NvimTreeCursorLine = { bg = c.row },
  -- WARN: the decorators are additive, and only the attributes a group sets
  -- clobber a lower one's. That is what lets four states share the file name
  -- without fighting: git owns the foreground, an open buffer adds bold, a
  -- diagnostic adds an undercurl, and cut and copied take the two attributes
  -- left. Set a foreground in any of these and it wipes the git colour, which
  -- is the one state every file has.
  NvimTreeOpenedHL = { bold = true },

  -- Stock puts these two on the undercurl, which diagnostics need and which
  -- they outrank, and in colours from outside this palette. Strikethrough is
  -- what cut already means everywhere else.
  NvimTreeCutHL = { strikethrough = true },
  NvimTreeCopiedHL = { italic = true },

  -- Out of the colour system rather than given a colour of their own. All
  -- three resolved to the folder blue, so an extensionless executable like
  -- .github/scripts/repin read as a directory and README.md read as an open
  -- one. That the panel says nothing about these is the point: it is there
  -- for the layout.
  NvimTreeExecFile = { link = "NvimTreeNormal" },
  NvimTreeImageFile = { link = "NvimTreeNormal" },
  NvimTreeSpecialFile = { link = "NvimTreeNormal" },

  -- The panel is below the page, so the stock "invisible against the page"
  -- is one step lighter than this surface and the tildes show faintly.
  NvimTreeEndOfBuffer = { fg = c.sunk },
  NvimTreeLineNr = { fg = c.faint, bg = c.sunk },

  -- Both carried hexes from outside the palette, and the picker is live:
  -- opening from the tree with more than one candidate window flashed a blue
  -- that is nowhere else in the theme. Shaped like the status line's mode
  -- block, which is the other place a letter is stamped on an accent.
  NvimTreeFolderIcon = { fg = c.muted },
  NvimTreeWindowPicker = { fg = c.sunk, bg = c.blue.text, bold = true },

  -- Metadata about the panel rather than content in it, so it takes the
  -- line-number grey and not the comment grey; comment grey is what an
  -- untracked file is drawn in, two rows up.
  NvimTreeHiddenDisplay = { fg = c.faint },

  -- Not yet written, as against the name's yellow for changed on disk: the
  -- same statement at two stages.
  NvimTreeModifiedIcon = { fg = c.yellow.text },
})

--- The git gutter ------------------------------------------------------------

hl({
  MiniDiffSignAdd = { fg = c.green.text },
  MiniDiffSignChange = { fg = c.yellow.text },
  MiniDiffSignDelete = { fg = c.red.text },

  -- The inline overlay, <Space>tr. Two planes, and the colour says which one
  -- you are on: red is the old text, green is yours. So an added line and a
  -- changed one are told apart by *where* the colour is, not by two shades of
  -- green: an added line is washed edge to edge, a changed one is green only
  -- on the words that changed, with a red-marked reference line beside it.
  --
  -- These were falling through to Neovim's stock Diff groups, and stock links
  -- the changed-words group to DiffText, which is green's container here. So
  -- the words being taken away were drawn in the colour of addition.
  MiniDiffOverAdd = { bg = c.green.container },
  MiniDiffOverChangeBuf = { bg = c.green.container },

  -- WARN: no background, deliberately. mini.diff draws this across the whole
  -- of the line you are editing, to the end of the line, so a background here
  -- kills CursorLine on every changed line in the file.
  MiniDiffOverContextBuf = {},

  -- The reference line needs a ground of its own: a virtual line takes none
  -- by default, so without this the old text is drawn exactly like the file
  -- and reads as code. Faint on purpose, since the empty number column beside
  -- a virtual line already says what it is and the red words are the reading.
  MiniDiffOverContext = { fg = c.body, bg = c.inlay },
  MiniDiffOverChange = { fg = c.bright, bg = c.red.container },
  MiniDiffOverDelete = { link = "MiniDiffOverChange" },
})

--- The picker ----------------------------------------------------------------

-- Picker windows should read like the rest of the theme rather than bring their
-- own palette, so most of this is the float chrome above.
hl({
  MiniPickNormal = { link = "NormalFloat" },
  MiniPickBorder = { link = "FloatBorder" },
  MiniPickBorderText = { link = "FloatTitle" },

  -- The busy border needs its own bg: mini.pick's default link lands on a
  -- group with none, so the border also flashed transparent while a live
  -- grep was searching.
  MiniPickBorderBusy = { fg = c.yellow.text, bg = c.raised },
  MiniPickPrompt = { fg = c.blue.text, bold = true },
  MiniPickMatchCurrent = { bg = c.guide, bold = true },
  MiniPickMatchRanges = { fg = c.yellow.text, bold = true },
  MiniPickIconDirectory = { fg = c.blue.text },
})

--- The key hints -------------------------------------------------------------

hl({
  WhichKey = { fg = c.blue.text, bold = true }, -- the key itself
  WhichKeyGroup = { fg = c.magenta.text }, -- a prefix with more behind it
  WhichKeyDesc = { fg = c.body },
  WhichKeySeparator = { fg = c.faint },
  WhichKeyNormal = { link = "NormalFloat" },
  WhichKeyBorder = { link = "FloatBorder" },
  WhichKeyTitle = { link = "FloatTitle" },
  WhichKeyValue = { fg = c.muted },
})

--- The width markers ---------------------------------------------------------

-- One column each, past 80, 100 and 120, escalating. Colored as a background
-- because a single character has to be seen out of the corner of an eye.
hl({
  MivnMargin80 = { fg = c.page, bg = c.green.text, bold = true },
  MivnMargin100 = { fg = c.page, bg = c.orange.text, bold = true },
  MivnMargin120 = { fg = c.page, bg = c.red.text, bold = true },
})

--- The landing buffer --------------------------------------------------------

-- A fire gradient: it starts on the yellow, orange and red above and falls to
-- the diff-removed background through the two fire steps named in the
-- palette, so it borrows no colors from outside the theme. One group per row
-- of the block letters, top to bottom.
hl({
  MivnDashboardFire1 = { fg = c.yellow.text },
  MivnDashboardFire2 = { fg = c.orange.text },
  MivnDashboardFire3 = { fg = c.red.text },
  MivnDashboardFire4 = { fg = c.fire4 },
  MivnDashboardFire5 = { fg = c.fire5 },
  MivnDashboardFire6 = { fg = c.red.container },

  -- The muted grey the theme uses for comments, so the supporting text sits
  -- back.
  MivnDashboardTagline = { fg = c.muted },
  MivnDashboardByline = { fg = c.muted },
  MivnDashboardName = { fg = c.orange.text, bold = true },

  -- The release, one step back from the byline it sits on: the theme's
  -- structural grey, the one line numbers use, so the row reads as metadata
  -- first and identity second, with the name the only accent on it.
  MivnDashboardVersion = { fg = c.faint },

  -- The count of commits past that release, in the color this theme already
  -- gives modified files, which is what a checkout past a release is. The +
  -- itself stays grey: the number is what the eye is being sent to. It only
  -- ever appears where I develop, so it is allowed to be the brightest thing
  -- on the row.
  MivnDashboardVersionAhead = { fg = c.yellow.text },

  -- The update notice, cool against a warm block so it reads as information
  -- rather than another piece of the art, and dim enough that a screen with
  -- nothing to say still looks the same as it always did.
  MivnDashboardUpdate = { fg = c.dim },
})

--- The hidden cursor ---------------------------------------------------------

-- Blended out to nothing, which is what lets the panels park a cursor where
-- there is nothing to edit. See lua/mivn/panel.lua, which points 'guicursor' at
-- this group and owns when.
hl({
  MivnCursorHidden = { blend = 100 },
})
