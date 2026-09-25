-- basalt, my dark theme. Its palette lives in a repository of its own, which
-- my terminal and my shell prompt read as well. It started from Tim Cole's
-- Modest Dark for Zed (https://github.com/timcole/modest-dark, MIT).
--
-- basalt owns the values and this file owns the roles. So a colour in the
-- wrong shade is a question for basalt, and a colour on the wrong thing is a
-- question for the tables below.
--
-- Every highlight group mivn sets lives here, the plugins' and my own
-- included, and the palette below is the only place a hex lives. So
-- `:colorscheme basalt` on a running editor colours the whole screen again.

vim.cmd.highlight("clear")
vim.g.colors_name = "basalt"
vim.o.termguicolors = true
vim.o.background = "dark"

-- The palette, in basalt's own names, every value copied from basalt.json in
-- the basalt repository. Nothing here invents one.
--
-- The surfaces run deepest to lightest: what sits beside or behind the file
-- goes under the page, what is drawn on top of it goes over. The step between
-- two surfaces is what parts them.
--
-- Each accent has four renditions: `text` for writing, `deep` for a strong
-- fill, `container` for a dim ground under plain text, and `wash` for a fainter
-- ground under text that already has a colour.
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

  -- Two steps between red and its container, for the dashboard's fire
  -- gradient and nothing else. Named only so that every hex stays here.
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

  -- The caret takes the mode block's hue; 'guicursor' in init.lua picks the
  -- group for each mode. The text under a block is `sunk`, the colour foot
  -- draws it in, and a terminal only ever gets the background, as OSC 12.
  Cursor = { fg = c.sunk, bg = c.blue.text },
  lCursor = { link = "Cursor" },
  iCursor = { fg = c.sunk, bg = c.green.text },
  vCursor = { fg = c.sunk, bg = c.magenta.text },
  rCursor = { fg = c.sunk, bg = c.red.text },
  cCursor = { fg = c.sunk, bg = c.yellow.text },
  oCursor = { fg = c.sunk, bg = c.cyan.text },
  TermCursor = { fg = c.sunk, bg = c.cyan.text },

  -- Select's caret. 'guicursor' has no Select mode, so this goes on every
  -- mode for as long as Select lasts.
  MivnCursorSelect = { fg = c.sunk, bg = c.orange.text },
  CursorLine = { bg = c.row },
  CursorColumn = { bg = c.row },
  ColorColumn = { bg = c.raised },

  LineNr = { fg = c.faint, bg = c.page },
  CursorLineNr = { fg = c.body, bg = c.row, bold = true },
  SignColumn = { bg = c.page },
  FoldColumn = { fg = c.faint, bg = c.page },
  Folded = { fg = c.muted, bg = c.inlay },

  -- Visual's magenta as a wash, so the code under a selection keeps its own
  -- colours. It sits on the page, since 'cursorline' is off during Visual.
  Visual = { bg = c.magenta.wash },
  VisualNOS = { bg = c.magenta.wash },

  -- Select's selection. Neovim draws Visual and Select with the one `Visual`
  -- group, so a window in Select points `Visual` here for as long as it lasts.
  MivnSelect = { bg = c.orange.wash },

  -- The other copies of what is selected, in a hue of their own so that the
  -- selection is the only magenta in the window. Cyan's wash is lighter than
  -- most, since no darker teal stands out on the row the caret is on.
  MivnOccurrence = { bg = c.cyan.wash },

  -- The flash over a fresh yank, in green: nothing is wrong, and it is the
  -- one wash no other mark uses.
  MivnYank = { bg = c.green.wash },

  Search = { fg = c.page, bg = c.yellow.text },
  IncSearch = { fg = c.page, bg = c.orange.text },
  CurSearch = { fg = c.page, bg = c.orange.text },
  MatchParen = { fg = c.cyan.text, bold = true },

  -- The indent guides' colour, so a split draws no bright seam on the screen.
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

  -- The letters the query hit, in the picker's yellow so both menus read
  -- alike.
  PmenuMatch = { fg = c.yellow.text, bg = c.raised, bold = true },
  PmenuMatchSel = { fg = c.yellow.text, bg = c.guide, bold = true },

  -- What a match would insert, shown in the line: in the window but not yet
  -- in the file, like an inlay hint.
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

  -- ui2's groups for good news and for what a shell command prints.
  OkMsg = { link = "MoreMsg" },
  StderrMsg = { link = "ErrorMsg" },
  StdoutMsg = { fg = c.body },

  -- A snippet's placeholders: the current one in Select's orange, the rest on
  -- a faint ground so the next stop shows before I reach it.
  SnippetTabstop = { bg = c.inlay },
  SnippetTabstopActive = { bg = c.orange.wash },
})

--- Syntax, the classic groups ------------------------------------------------

-- These still drive any language without a tree-sitter grammar. Only the ones
-- that differ from what Neovim links them to are listed: `Keyword` links to
-- `Statement` by default and says the same thing here, so it is not.
hl({
  Comment = { fg = c.muted, italic = true },

  Constant = { fg = c.orange.text },
  String = { fg = c.green.text },
  Character = { fg = c.green.text },

  Identifier = { fg = c.body },
  Function = { fg = c.blue.text },

  Statement = { fg = c.magenta.text, bold = true },
  Label = { fg = c.magenta.text },
  Operator = { fg = c.body },

  PreProc = { fg = c.magenta.text },
  Include = { fg = c.magenta.text, bold = true },

  Type = { fg = c.yellow.text },
  StorageClass = { fg = c.magenta.text, bold = true },

  Special = { fg = c.cyan.text },
  Tag = { fg = c.red.text },
  Delimiter = { fg = c.body },
  SpecialComment = { fg = c.muted, italic = true, bold = true },
  Debug = { fg = c.red.text },

  Ignore = { fg = c.guide },
  Error = { fg = c.red.text },
  Todo = { fg = c.page, bg = c.yellow.text, bold = true },
})

--- Tree-sitter captures -----------------------------------------------------

-- Only the captures that read differently from where they would land anyway.
-- A capture with no group of its own falls back to its parent
-- (`@keyword.return` to `@keyword`), and Neovim links the parents to the
-- classic groups above (`@keyword` to `Keyword`), so most need no line here.
hl({
  ["@variable"] = { fg = c.body },

  -- `self` and `this`: a value the language bound rather than one I named,
  -- which is what orange says for `nil` and `true`.
  ["@variable.builtin"] = { fg = c.orange.text },

  ["@variable.member"] = { fg = c.red.text },

  ["@constant.builtin"] = { fg = c.orange.text },
  ["@constant.macro"] = { fg = c.magenta.text },

  -- Where a name lives (`context` in `context.Context`), dim so the type name
  -- reads first and `time.Now()` stands apart from `t.Now()`.
  ["@module"] = { fg = c.dim },

  ["@string.escape"] = { fg = c.cyan.text, bold = true },
  ["@string.special.url"] = { fg = c.cyan.text, underline = true },

  ["@type.builtin"] = { fg = c.yellow.text },
  ["@property"] = { fg = c.red.text },

  ["@function.builtin"] = { fg = c.blue.text },
  ["@function.macro"] = { fg = c.magenta.text },
  ["@constructor"] = { fg = c.yellow.text },

  ["@keyword.debug"] = { fg = c.red.text },
  ["@keyword.directive"] = { fg = c.magenta.text },

  ["@comment.error"] = { fg = c.page, bg = c.red.text, bold = true },
  ["@comment.warning"] = { fg = c.page, bg = c.yellow.text, bold = true },
  ["@comment.todo"] = { fg = c.page, bg = c.blue.text, bold = true },
  ["@comment.note"] = { fg = c.page, bg = c.cyan.text, bold = true },

  ["@tag.builtin"] = { fg = c.red.text },
  ["@tag.attribute"] = { fg = c.orange.text },
  ["@tag.delimiter"] = { fg = c.body },

  ["@markup.quote"] = { fg = c.muted, italic = true },
  ["@markup.link"] = { fg = c.cyan.text },
  ["@markup.link.label"] = { fg = c.blue.text },
  ["@markup.link.url"] = { fg = c.cyan.text, underline = true },
  ["@markup.raw"] = { fg = c.green.text },
  ["@markup.list"] = { fg = c.magenta.text },
  ["@markup.list.checked"] = { fg = c.green.text },
  ["@markup.list.unchecked"] = { fg = c.muted },
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

  -- NOTE: cleared, like the comment token above. A semantic token draws at
  -- priority 125 and tree-sitter at 100, so a server that marks a whole string
  -- literal paints over whatever is injected in it, such as the SQL that
  -- queries/go/injections.scm finds in Go strings. Cleared, the token paints
  -- nothing and the injection shows through.
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

  -- No background: these lines wrap, and a ground would paint their ragged
  -- right edge rather than the words.
  DiagnosticVirtualLinesError = { fg = c.red.text },
  DiagnosticVirtualLinesWarn = { fg = c.yellow.text },
  DiagnosticVirtualLinesInfo = { fg = c.blue.text },
  DiagnosticVirtualLinesHint = { fg = c.muted },

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
  -- The words added inside a changed line, on the changed word's ground: the
  -- palette has no brighter step.
  DiffTextAdd = { bg = c.green.container },

  -- The file-status colors the tree and the gutter share.
  Added = { fg = c.green.text },
  Removed = { fg = c.red.text },
  Changed = { fg = c.yellow.text },
})

--- Terminal ------------------------------------------------------------------

-- The sixteen colours of a :terminal buffer, slot for slot foot's but for
-- slot 0: foot draws on `sunk` and so puts `row` there, while a :terminal
-- draws on the page, which `sunk` already sits under.
--
-- Slots 9 to 14 repeat 1 to 6, since basalt has one text colour per accent;
-- bold carries the difference, as those programs pair it with the bright slot
-- anyway.
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

-- The mode block: each mode in the hue the syntax gives what that mode is
-- about, so the pairing is one I learn from the code anyway.
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

  -- The branch, and its dirty dot with it, in orange: a fixed label like a
  -- constant, where yellow would ask for attention all the time.
  MivnStatuslineGit = { fg = c.orange.text, bg = c.raised },

  -- The blame takes the file name's colours: it is something the file says
  -- about itself, not something I watch.
  MivnStatuslineBlame = { fg = c.muted, bg = c.inlay },

  -- `%=` fills with the file name's colours, so the line is a raised block at
  -- each end with a low trough between: what I watch sits raised, what is
  -- only context sits low.
  MiniStatuslineDevinfo = { fg = c.body, bg = c.raised },
  MiniStatuslineFileinfo = { fg = c.body, bg = c.raised },
  MiniStatuslineFilename = { fg = c.muted, bg = c.inlay },
  MiniStatuslineInactive = { fg = c.faint, bg = c.inlay },
})

--- The tab bar ---------------------------------------------------------------

hl({
  MiniTablineCurrent = { fg = c.body, bg = c.raised, bold = true },
  MiniTablineVisible = { fg = c.muted, bg = c.sunk },
  MiniTablineHidden = { fg = c.faint, bg = c.sunk },

  -- Unsaved changes are the one thing worth colouring, so an unwritten buffer
  -- shows without reading its name.
  MiniTablineModifiedCurrent = { fg = c.yellow.text, bg = c.raised, bold = true },
  MiniTablineModifiedVisible = { fg = c.yellow.text, bg = c.sunk },
  MiniTablineModifiedHidden = { fg = c.orange.text, bg = c.sunk },

  MiniTablineFill = { bg = c.sunk },
  MiniTablineTabpagesection = { fg = c.page, bg = c.magenta.text, bold = true },

  -- The tree's columns in the bar, drawn as the tree so the panel reads as
  -- running up to the top rather than as an empty tab.
  MivnTablineTreeFill = { link = "NvimTreeNormal" },

  -- The project's name over the tree: blue like the tree's folder names, and
  -- not bold, so it does not read as a tab.
  MivnTablineProject = { fg = c.blue.text, bg = c.sunk },
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

  -- The panel sits below the page, so the split needs no separator line.
  NvimTreeNormal = { fg = c.body, bg = c.sunk },
  NvimTreeNormalNC = { fg = c.body, bg = c.sunk },
  NvimTreeWinSeparator = { fg = c.sunk, bg = c.sunk },
  NvimTreeRootFolder = { fg = c.magenta.text, bold = true },
  NvimTreeFolderName = { fg = c.blue.text },
  NvimTreeOpenedFolderName = { fg = c.blue.text, bold = true },
  NvimTreeEmptyFolderName = { fg = c.faint },
  NvimTreeIndentMarker = { fg = c.raised },
  NvimTreeCursorLine = { bg = c.row },
  -- NOTE: the decorators stack, and each one overrides only the attributes it
  -- sets. Git owns the foreground, an open buffer adds bold, a diagnostic an
  -- undercurl, and cut and copied take the two attributes left. A foreground
  -- in any of these would wipe the git colour, which every file has.
  NvimTreeOpenedHL = { bold = true },

  -- Off the undercurl that stock gives them, which diagnostics need, and
  -- strikethrough for cut, which is what it means everywhere else.
  NvimTreeCutHL = { strikethrough = true },
  NvimTreeCopiedHL = { italic = true },

  -- Plain, since stock draws all three in the folder blue and a script then
  -- reads as a directory.
  NvimTreeExecFile = { link = "NvimTreeNormal" },
  NvimTreeImageFile = { link = "NvimTreeNormal" },
  NvimTreeSpecialFile = { link = "NvimTreeNormal" },

  -- The tildes in the panel's own colour, since the page's shows up on it.
  NvimTreeEndOfBuffer = { fg = c.sunk },
  NvimTreeLineNr = { fg = c.faint, bg = c.sunk },

  -- Stock gives both colours from outside the palette. The window picker is
  -- a letter on an accent, like the mode block.
  NvimTreeFolderIcon = { fg = c.muted },
  NvimTreeWindowPicker = { fg = c.sunk, bg = c.blue.text, bold = true },

  -- About the panel rather than in it, so the line-number grey; the comment
  -- grey is an untracked file's.
  NvimTreeHiddenDisplay = { fg = c.faint },

  -- Unsaved, in the yellow the name takes for changed on disk: one statement
  -- at two stages.
  NvimTreeModifiedIcon = { fg = c.yellow.text },
})

--- The git gutter ------------------------------------------------------------

hl({
  MiniDiffSignAdd = { fg = c.green.text },
  MiniDiffSignChange = { fg = c.yellow.text },
  MiniDiffSignDelete = { fg = c.red.text },

  -- The inline overlay: red is the old text and green is mine, so an added
  -- line is green edge to edge and a changed one only on the words that
  -- changed.
  MiniDiffOverAdd = { bg = c.green.container },
  MiniDiffOverChangeBuf = { bg = c.green.container },

  -- NOTE: no background. mini.diff draws this over the whole of a changed
  -- line, to its end, so a background here would hide CursorLine on every
  -- changed line in the file.
  MiniDiffOverContextBuf = {},

  -- The old text's line needs a ground of its own, or it reads as code in the
  -- file.
  MiniDiffOverContext = { fg = c.body, bg = c.inlay },
  MiniDiffOverChange = { fg = c.bright, bg = c.red.container },
  MiniDiffOverDelete = { link = "MiniDiffOverChange" },
})

--- The picker ----------------------------------------------------------------

hl({
  MiniPickNormal = { link = "NormalFloat" },
  MiniPickBorder = { link = "FloatBorder" },
  MiniPickBorderText = { link = "FloatTitle" },

  -- Its own background, since mini.pick's default has none and the border
  -- would go see-through while a grep runs.
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

-- One column each, past 80, 100 and 120, as a background so a single cell is
-- seen out of the corner of an eye.
hl({
  MivnMargin80 = { fg = c.page, bg = c.green.text, bold = true },
  MivnMargin100 = { fg = c.page, bg = c.orange.text, bold = true },
  MivnMargin120 = { fg = c.page, bg = c.red.text, bold = true },
})

--- The landing buffer --------------------------------------------------------

-- A fire gradient, one group per row of the block letters, top to bottom:
-- yellow, orange and red, then down to red's container through the two fire
-- steps.
hl({
  MivnDashboardFire1 = { fg = c.yellow.text },
  MivnDashboardFire2 = { fg = c.orange.text },
  MivnDashboardFire3 = { fg = c.red.text },
  MivnDashboardFire4 = { fg = c.fire4 },
  MivnDashboardFire5 = { fg = c.fire5 },
  MivnDashboardFire6 = { fg = c.red.container },

  MivnDashboardTagline = { fg = c.muted },
  MivnDashboardByline = { fg = c.muted },
  MivnDashboardName = { fg = c.orange.text, bold = true },

  -- The release, a step back from the byline in the line-number grey.
  MivnDashboardVersion = { fg = c.faint },

  -- The commits past that release, in the yellow of a modified file, which is
  -- what a checkout past a release is.
  MivnDashboardVersionAhead = { fg = c.yellow.text },

  -- The update notice, cool against the warm block so it reads as news
  -- rather than as part of the art.
  MivnDashboardUpdate = { fg = c.dim },
})

--- The hidden cursor ---------------------------------------------------------

-- Blended out to nothing, so a panel can hide the caret where there is
-- nothing to edit.
hl({
  MivnCursorHidden = { blend = 100 },
})
