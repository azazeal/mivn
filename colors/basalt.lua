-- basalt: my dark theme, named for what magma becomes when it cools. The
-- palette is ported from Modest Dark, a Zed theme by Tim Cole
-- (https://github.com/timcole/modest-dark, MIT), and is the same palette my
-- other editors and terminal use.
--
-- Written out rather than pulled from a plugin. A colorscheme is a table of
-- highlight groups, so a dependency here would buy nothing and drift from the
-- other editors.
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

-- The base scale, darkest to lightest, then the accents.
local c = {
  -- The backgrounds are levels, and the rule is about the page: what sits
  -- beside or behind the file goes under it, what is drawn on top of the file
  -- goes over it. The depth step is what separates two surfaces; that is why
  -- the tree needs no visible separator.
  bg0 = "#0A0C10", -- under the page: the tree, the tab strip, inactive tabs
  bg = "#0F1219", -- the page: the buffer and its number and sign columns
  bg1 = "#12161D", -- in the window but not in the file: folds, inlay hints,
  -- diagnostic virtual text, the old text the diff overlay shows
  bg2 = "#171B24", -- the active row, below the page
  bg3 = "#1E242E", -- over the page: floats, popups, the status line, the
  -- active tab, separators, indent guides
  bg4 = "#2C313A", -- spare. Was the selection until that became a tint, and
  -- only the code-lens separator reads it now
  bg5 = "#3E4452", -- scrollbar thumb, listchars
  bg6 = "#495162", -- line numbers, inactive tab text
  bg7 = "#546178", -- comments, untracked files
  fg = "#ABB2BF",
  fg1 = "#D7DAE0",

  red = "#EF5F6B",
  red1 = "#FF616E", -- errors, deleted files
  orange = "#D99A5E", -- constants
  green = "#97CA72", -- strings
  green1 = "#A5E075", -- added files
  yellow = "#EBC275", -- types, warnings
  yellow1 = "#E5C07B", -- builtin variables, modified files
  blue = "#5AB0F6", -- functions
  blue1 = "#528BFF", -- cursor
  blue2 = "#3F7FB8",
  magenta = "#CA72E4", -- keywords
  violet = "#C162DE",
  cyan = "#4DBDCB",
  teal = "#56B6C2",

  diff_add = "#3B5135",
  diff_del = "#572A32",

  -- The two steps between red and diff_del that the dashboard's fire
  -- gradient needs and the scale above has no name for. Nothing else may
  -- use them; they are named here only so every hex stays in this table.
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
  Normal = { fg = c.fg, bg = c.bg },
  NormalNC = { fg = c.fg, bg = c.bg },
  NormalFloat = { fg = c.fg, bg = c.bg3 },
  FloatBorder = { fg = c.bg5, bg = c.bg3 },
  FloatTitle = { fg = c.blue, bg = c.bg3, bold = true },

  Cursor = { fg = c.bg, bg = c.blue1 },
  lCursor = { link = "Cursor" },
  CursorLine = { bg = c.bg2 },
  CursorColumn = { bg = c.bg2 },
  ColorColumn = { bg = c.bg3 },

  LineNr = { fg = c.bg6, bg = c.bg },
  CursorLineNr = { fg = c.fg, bg = c.bg2, bold = true },
  SignColumn = { bg = c.bg },
  FoldColumn = { fg = c.bg6, bg = c.bg },
  Folded = { fg = c.bg7, bg = c.bg1 },

  -- A tint rather than another grey. The selection sits on the cursor's own
  -- line most of the time, so what it has to beat is CursorLine and not the
  -- editor background, and bg4 against bg2 was a step of about 8%: measured,
  -- and invisible on a short selection. This is blue2 laid over bg2 at 30%,
  -- which reads as a selection rather than as slightly lighter text.
  Visual = { bg = "#233950" },
  VisualNOS = { bg = "#233950" },
  Search = { fg = c.bg, bg = c.yellow },
  IncSearch = { fg = c.bg, bg = c.orange },
  CurSearch = { fg = c.bg, bg = c.orange },
  MatchParen = { fg = c.cyan, bold = true },

  -- The indent guide color doubles as every window-splitting line, which is
  -- what keeps splits from drawing a bright seam across the screen.
  WinSeparator = { fg = c.bg3, bg = c.bg },
  VertSplit = { link = "WinSeparator" },

  Pmenu = { fg = c.fg, bg = c.bg3 },
  PmenuSel = { fg = c.fg1, bg = c.bg5, bold = true },
  PmenuKind = { fg = c.blue, bg = c.bg3 },
  PmenuKindSel = { fg = c.blue, bg = c.bg5 },
  PmenuExtra = { fg = c.bg7, bg = c.bg3 },
  PmenuExtraSel = { fg = c.fg, bg = c.bg5 },
  PmenuSbar = { bg = c.bg3 },
  PmenuThumb = { bg = c.bg5 },
  WildMenu = { link = "PmenuSel" },

  StatusLine = { fg = c.fg, bg = c.bg3 },
  StatusLineNC = { fg = c.bg6, bg = c.bg1 },
  WinBar = { fg = c.fg, bg = c.bg },
  WinBarNC = { fg = c.bg6, bg = c.bg },

  TabLine = { fg = c.bg6, bg = c.bg },
  TabLineSel = { fg = c.fg, bg = c.bg3 },
  TabLineFill = { bg = c.bg0 },

  Directory = { fg = c.blue },
  Title = { fg = c.blue, bold = true },
  Conceal = { fg = c.bg6 },
  NonText = { fg = c.bg3 },
  Whitespace = { fg = c.bg5 },
  SpecialKey = { fg = c.bg5 },
  EndOfBuffer = { fg = c.bg },
  QuickFixLine = { bg = c.bg3, bold = true },

  ErrorMsg = { fg = c.red1 },
  WarningMsg = { fg = c.yellow },
  MoreMsg = { fg = c.green },
  Question = { fg = c.blue },
  ModeMsg = { fg = c.fg, bold = true },
  MsgArea = { fg = c.fg, bg = c.bg },
})

--- Syntax, the classic groups ------------------------------------------------

-- These still drive any language without a tree-sitter grammar, and the
-- @-captures below link into them where the meaning is the same.
hl({
  Comment = { fg = c.bg7, italic = true },

  Constant = { fg = c.orange },
  String = { fg = c.green },
  Character = { fg = c.green },
  Number = { fg = c.orange },
  Boolean = { fg = c.orange },
  Float = { fg = c.orange },

  Identifier = { fg = c.fg },
  Function = { fg = c.blue },

  Statement = { fg = c.magenta, bold = true },
  Conditional = { fg = c.magenta, bold = true },
  Repeat = { fg = c.magenta, bold = true },
  Label = { fg = c.magenta },
  Operator = { fg = c.fg },
  Keyword = { fg = c.magenta, bold = true },
  Exception = { fg = c.magenta, bold = true },

  PreProc = { fg = c.violet },
  Include = { fg = c.magenta, bold = true },
  Define = { fg = c.violet },
  Macro = { fg = c.violet },
  PreCondit = { fg = c.violet },

  Type = { fg = c.yellow },
  StorageClass = { fg = c.magenta, bold = true },
  Structure = { fg = c.yellow },
  Typedef = { fg = c.yellow },

  Special = { fg = c.cyan },
  SpecialChar = { fg = c.cyan },
  Tag = { fg = c.red },
  Delimiter = { fg = c.fg },
  SpecialComment = { fg = c.bg7, italic = true, bold = true },
  Debug = { fg = c.red },

  Underlined = { underline = true },
  Ignore = { fg = c.bg5 },
  Error = { fg = c.red1 },
  Todo = { fg = c.bg, bg = c.yellow, bold = true },
})

--- Tree-sitter captures -----------------------------------------------------

hl({
  ["@variable"] = { fg = c.fg },
  ["@variable.builtin"] = { fg = c.yellow1 },
  ["@variable.parameter"] = { fg = c.fg },
  ["@variable.member"] = { fg = c.red },

  ["@constant"] = { fg = c.orange },
  ["@constant.builtin"] = { fg = c.orange },
  ["@constant.macro"] = { fg = c.violet },

  ["@module"] = { fg = c.yellow },
  ["@label"] = { fg = c.magenta },

  ["@string"] = { fg = c.green },
  ["@string.documentation"] = { fg = c.green },
  ["@string.regexp"] = { fg = c.cyan },
  ["@string.escape"] = { fg = c.cyan, bold = true },
  ["@string.special"] = { fg = c.cyan },
  ["@string.special.url"] = { fg = c.cyan, underline = true },
  ["@character"] = { fg = c.green },
  ["@character.special"] = { fg = c.cyan },

  ["@boolean"] = { fg = c.orange },
  ["@number"] = { fg = c.orange },
  ["@number.float"] = { fg = c.orange },

  ["@type"] = { fg = c.yellow },
  ["@type.builtin"] = { fg = c.yellow },
  ["@type.definition"] = { fg = c.yellow },
  ["@attribute"] = { fg = c.violet },
  ["@property"] = { fg = c.red },

  ["@function"] = { fg = c.blue },
  ["@function.builtin"] = { fg = c.blue },
  ["@function.call"] = { fg = c.blue },
  ["@function.macro"] = { fg = c.violet },
  ["@function.method"] = { fg = c.blue },
  ["@function.method.call"] = { fg = c.blue },
  ["@constructor"] = { fg = c.yellow },

  ["@operator"] = { fg = c.fg },

  ["@keyword"] = { fg = c.magenta, bold = true },
  ["@keyword.function"] = { fg = c.magenta, bold = true },
  ["@keyword.operator"] = { fg = c.magenta, bold = true },
  ["@keyword.import"] = { fg = c.magenta, bold = true },
  ["@keyword.type"] = { fg = c.magenta, bold = true },
  ["@keyword.modifier"] = { fg = c.magenta, bold = true },
  ["@keyword.repeat"] = { fg = c.magenta, bold = true },
  ["@keyword.return"] = { fg = c.magenta, bold = true },
  ["@keyword.debug"] = { fg = c.red },
  ["@keyword.exception"] = { fg = c.magenta, bold = true },
  ["@keyword.conditional"] = { fg = c.magenta, bold = true },
  ["@keyword.directive"] = { fg = c.violet },

  ["@punctuation.delimiter"] = { fg = c.fg },
  ["@punctuation.bracket"] = { fg = c.fg },
  ["@punctuation.special"] = { fg = c.cyan },

  ["@comment"] = { fg = c.bg7, italic = true },
  ["@comment.documentation"] = { fg = c.bg7, italic = true },
  ["@comment.error"] = { fg = c.bg, bg = c.red1, bold = true },
  ["@comment.warning"] = { fg = c.bg, bg = c.yellow, bold = true },
  ["@comment.todo"] = { fg = c.bg, bg = c.blue, bold = true },
  ["@comment.note"] = { fg = c.bg, bg = c.teal, bold = true },

  ["@tag"] = { fg = c.red },
  ["@tag.builtin"] = { fg = c.red },
  ["@tag.attribute"] = { fg = c.orange },
  ["@tag.delimiter"] = { fg = c.fg },

  ["@markup.strong"] = { bold = true },
  ["@markup.italic"] = { italic = true },
  ["@markup.strikethrough"] = { strikethrough = true },
  ["@markup.underline"] = { underline = true },
  ["@markup.heading"] = { fg = c.blue, bold = true },
  ["@markup.quote"] = { fg = c.bg7, italic = true },
  ["@markup.math"] = { fg = c.cyan },
  ["@markup.link"] = { fg = c.cyan },
  ["@markup.link.label"] = { fg = c.blue },
  ["@markup.link.url"] = { fg = c.cyan, underline = true },
  ["@markup.raw"] = { fg = c.green },
  ["@markup.list"] = { fg = c.magenta },
  ["@markup.list.checked"] = { fg = c.green },
  ["@markup.list.unchecked"] = { fg = c.bg7 },

  ["@diff.plus"] = { fg = c.green1 },
  ["@diff.minus"] = { fg = c.red1 },
  ["@diff.delta"] = { fg = c.yellow1 },
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
  ["@lsp.type.struct"] = { link = "@type" },
  ["@lsp.type.type"] = { link = "@type" },
  ["@lsp.type.typeParameter"] = { link = "@type" },
  ["@lsp.type.variable"] = { link = "@variable" },

  LspReferenceText = { bg = c.bg3 },
  LspReferenceRead = { bg = c.bg3 },
  LspReferenceWrite = { bg = c.bg3, underline = true },
  LspInlayHint = { fg = c.bg6, bg = c.bg1, italic = true },
  LspSignatureActiveParameter = { fg = c.orange, bold = true },
  LspCodeLens = { fg = c.bg6, italic = true },
  LspCodeLensSeparator = { fg = c.bg4, italic = true },

  DiagnosticError = { fg = c.red1 },
  DiagnosticWarn = { fg = c.yellow },
  DiagnosticInfo = { fg = c.blue },
  DiagnosticHint = { fg = c.fg },
  DiagnosticOk = { fg = c.green },

  DiagnosticVirtualTextError = { fg = c.red1, bg = c.bg1 },
  DiagnosticVirtualTextWarn = { fg = c.yellow, bg = c.bg1 },
  DiagnosticVirtualTextInfo = { fg = c.blue, bg = c.bg1 },
  DiagnosticVirtualTextHint = { fg = c.bg7, bg = c.bg1 },

  DiagnosticUnderlineError = { undercurl = true, sp = c.red1 },
  DiagnosticUnderlineWarn = { undercurl = true, sp = c.yellow },
  DiagnosticUnderlineInfo = { undercurl = true, sp = c.blue },
  DiagnosticUnderlineHint = { undercurl = true, sp = c.bg7 },

  -- Dimmed rather than colored: unused code is a hint, not a problem.
  DiagnosticUnnecessary = { fg = c.bg6 },
  DiagnosticDeprecated = { fg = c.bg6, strikethrough = true },
})

--- Diffs and version control -------------------------------------------------

hl({
  DiffAdd = { bg = c.diff_add },
  DiffDelete = { fg = c.red1, bg = c.diff_del },
  DiffChange = { bg = c.bg3 },
  DiffText = { bg = c.diff_add },

  -- The file-status colors the tree and the gutter share.
  Added = { fg = c.green1 },
  Removed = { fg = c.red1 },
  Changed = { fg = c.yellow1 },
})

--- Terminal ------------------------------------------------------------------

-- :terminal buffers, so a shell inside Neovim matches foot outside it.
vim.g.terminal_color_0 = c.bg0
vim.g.terminal_color_1 = c.red
vim.g.terminal_color_2 = c.green
vim.g.terminal_color_3 = c.yellow
vim.g.terminal_color_4 = c.blue
vim.g.terminal_color_5 = c.magenta
vim.g.terminal_color_6 = c.cyan
vim.g.terminal_color_7 = c.fg
vim.g.terminal_color_8 = c.bg6
vim.g.terminal_color_9 = c.red1
vim.g.terminal_color_10 = c.green1
vim.g.terminal_color_11 = c.yellow1
vim.g.terminal_color_12 = c.blue1
vim.g.terminal_color_13 = c.violet
vim.g.terminal_color_14 = c.teal
vim.g.terminal_color_15 = c.fg1

--- The status line -----------------------------------------------------------

-- The mode block: the accent as a background, the darkest background as text.
-- Each mode gets the color the theme already uses for the thing that mode is
-- about, so the association is one I am learning anyway from the syntax
-- highlighting.
hl({
  MiniStatuslineModeNormal = { fg = c.bg0, bg = c.blue, bold = true }, -- functions
  MiniStatuslineModeInsert = { fg = c.bg0, bg = c.green, bold = true }, -- strings
  MiniStatuslineModeVisual = { fg = c.bg0, bg = c.magenta, bold = true }, -- keywords

  -- Orange is constants, the one accent left free; red is errors, and Replace
  -- overwrites.
  MiniStatuslineModeSelect = { fg = c.bg0, bg = c.orange, bold = true },
  MiniStatuslineModeReplace = { fg = c.bg0, bg = c.red, bold = true },

  MiniStatuslineModeCommand = { fg = c.bg0, bg = c.yellow, bold = true }, -- types
  MiniStatuslineModeOther = { fg = c.bg0, bg = c.cyan, bold = true }, -- terminal, rest

  -- The branch in orange, the color my shell prompt already gives branch
  -- names, so the statusline and the prompt say it in the same voice. The
  -- dirty dot rides along: it is one token with the name, and yellow1 already
  -- means "modified" elsewhere.
  MivnStatuslineGit = { fg = c.orange, bg = c.bg3 },

  -- Two shades either side of the file name, so the line reads as three bands
  -- rather than one strip with text in it.
  MiniStatuslineDevinfo = { fg = c.fg, bg = c.bg3 },
  MiniStatuslineFileinfo = { fg = c.fg, bg = c.bg3 },
  MiniStatuslineFilename = { fg = c.bg7, bg = c.bg1 },
  MiniStatuslineInactive = { fg = c.bg6, bg = c.bg1 },
})

--- The tab bar ---------------------------------------------------------------

hl({
  -- The active tab lifts to the panel background, the rest sit back on the
  -- editor background.
  MiniTablineCurrent = { fg = c.fg, bg = c.bg3, bold = true },
  MiniTablineVisible = { fg = c.bg7, bg = c.bg0 },
  MiniTablineHidden = { fg = c.bg6, bg = c.bg0 },

  -- Unsaved changes are the one thing worth coloring, so an unwritten buffer is
  -- obvious without reading the name.
  MiniTablineModifiedCurrent = { fg = c.yellow, bg = c.bg3, bold = true },
  MiniTablineModifiedVisible = { fg = c.yellow1, bg = c.bg0 },
  MiniTablineModifiedHidden = { fg = c.orange, bg = c.bg0 },

  MiniTablineFill = { bg = c.bg0 },
  MiniTablineTabpagesection = { fg = c.bg, bg = c.magenta, bold = true },

  -- The strip that stands in for the tree above it, so the gap reads as the
  -- panel continuing upward rather than as an empty tab.
  MivnTablineTreeFill = { link = "NvimTreeNormal" },
})

--- The file tree -------------------------------------------------------------

hl({
  -- Git state, the same four colors the gutter and the tab bar use.
  NvimTreeGitFileNewHL = { fg = c.bg7 }, -- untracked
  NvimTreeGitFileDirtyHL = { fg = c.yellow1 }, -- modified
  NvimTreeGitFileStagedHL = { fg = c.green1 }, -- added
  NvimTreeGitFileDeletedHL = { fg = c.red1 },
  NvimTreeGitFileMergeHL = { fg = c.red },
  NvimTreeGitFileRenamedHL = { fg = c.blue },

  NvimTreeGitFolderNewHL = { fg = c.bg7 },
  NvimTreeGitFolderDirtyHL = { fg = c.yellow1 },
  NvimTreeGitFolderStagedHL = { fg = c.green1 },

  -- Panel chrome: a shade off the editor background so the split reads as a
  -- panel without needing a bright separator.
  NvimTreeNormal = { fg = c.fg, bg = c.bg0 },
  NvimTreeNormalNC = { fg = c.fg, bg = c.bg0 },
  NvimTreeWinSeparator = { fg = c.bg0, bg = c.bg0 },
  NvimTreeRootFolder = { fg = c.magenta, bold = true },
  NvimTreeFolderName = { fg = c.blue },
  NvimTreeOpenedFolderName = { fg = c.blue, bold = true },
  NvimTreeEmptyFolderName = { fg = c.bg6 },
  NvimTreeIndentMarker = { fg = c.bg3 },
  NvimTreeCursorLine = { bg = c.bg2 },
  NvimTreeOpenedHL = { fg = c.fg1, bold = true },
})

--- The git gutter ------------------------------------------------------------

hl({
  MiniDiffSignAdd = { fg = c.green1 },
  MiniDiffSignChange = { fg = c.yellow1 },
  MiniDiffSignDelete = { fg = c.red1 },

  -- The inline overlay, <Space>tr. Two planes, and the colour says which one
  -- you are on: red is the old text, green is yours. So an added line and a
  -- changed one are told apart by *where* the colour is, not by two shades of
  -- green: an added line is washed edge to edge, a changed one is green only
  -- on the words that changed, with a red-marked reference line beside it.
  --
  -- These were falling through to Neovim's stock Diff groups, and stock links
  -- the changed-words group to DiffText, which is diff_add here. So the words
  -- being taken away were drawn in the colour of addition.
  MiniDiffOverAdd = { bg = c.diff_add },
  MiniDiffOverChangeBuf = { bg = c.diff_add },

  -- WARN: no background, deliberately. mini.diff draws this across the whole
  -- of the line you are editing, to the end of the line, so a background here
  -- kills CursorLine on every changed line in the file.
  MiniDiffOverContextBuf = {},

  -- The reference line needs a ground of its own: a virtual line takes none
  -- by default, so without this the old text is drawn exactly like the file
  -- and reads as code. Faint on purpose, since the empty number column beside
  -- a virtual line already says what it is and the red words are the reading.
  MiniDiffOverContext = { fg = c.fg, bg = c.bg1 },
  MiniDiffOverChange = { fg = c.fg1, bg = c.diff_del },
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
  MiniPickBorderBusy = { fg = c.yellow, bg = c.bg3 },
  MiniPickPrompt = { fg = c.blue, bold = true },
  MiniPickMatchCurrent = { bg = c.bg5, bold = true },
  MiniPickMatchRanges = { fg = c.yellow, bold = true },
  MiniPickIconDirectory = { fg = c.blue },
})

--- The key hints -------------------------------------------------------------

hl({
  WhichKey = { fg = c.blue, bold = true }, -- the key itself
  WhichKeyGroup = { fg = c.magenta }, -- a prefix with more behind it
  WhichKeyDesc = { fg = c.fg },
  WhichKeySeparator = { fg = c.bg6 },
  WhichKeyNormal = { link = "NormalFloat" },
  WhichKeyBorder = { link = "FloatBorder" },
  WhichKeyTitle = { link = "FloatTitle" },
  WhichKeyValue = { fg = c.bg7 },
})

--- The width markers ---------------------------------------------------------

-- One column each, past 80, 100 and 120, escalating. Colored as a background
-- because a single character has to be seen out of the corner of an eye.
hl({
  MivnMargin80 = { fg = c.bg, bg = c.green, bold = true },
  MivnMargin100 = { fg = c.bg, bg = c.orange, bold = true },
  MivnMargin120 = { fg = c.bg, bg = c.red, bold = true },
})

--- The landing buffer --------------------------------------------------------

-- A fire gradient: it starts on the yellow, orange and red above and falls to
-- the diff-removed background through the two fire steps named in the
-- palette, so it borrows no colors from outside the theme. One group per row
-- of the block letters, top to bottom.
hl({
  MivnDashboardFire1 = { fg = c.yellow },
  MivnDashboardFire2 = { fg = c.orange },
  MivnDashboardFire3 = { fg = c.red },
  MivnDashboardFire4 = { fg = c.fire4 },
  MivnDashboardFire5 = { fg = c.fire5 },
  MivnDashboardFire6 = { fg = c.diff_del },

  -- The muted grey the theme uses for comments, so the supporting text sits
  -- back.
  MivnDashboardTagline = { fg = c.bg7 },
  MivnDashboardByline = { fg = c.bg7 },
  MivnDashboardName = { fg = c.orange, bold = true },

  -- The release, one step back from the byline it sits on: the theme's
  -- structural grey, the one line numbers use, so the row reads as metadata
  -- first and identity second, with the name the only accent on it.
  MivnDashboardVersion = { fg = c.bg6 },

  -- The count of commits past that release, in the color this theme already
  -- gives modified files, which is what a checkout past a release is. The +
  -- itself stays grey: the number is what the eye is being sent to. It only
  -- ever appears where I develop, so it is allowed to be the brightest thing
  -- on the row.
  MivnDashboardVersionAhead = { fg = c.yellow1 },

  -- The update notice, cool against a warm block so it reads as information
  -- rather than another piece of the art, and dim enough that a screen with
  -- nothing to say still looks the same as it always did.
  MivnDashboardUpdate = { fg = c.blue2 },
})

--- The hidden cursor ---------------------------------------------------------

-- Blended out to nothing, which is what lets the panels park a cursor where
-- there is nothing to edit. See lua/mivn/panel.lua, which points 'guicursor' at
-- this group and owns when.
hl({
  MivnCursorHidden = { blend = 100 },
})
