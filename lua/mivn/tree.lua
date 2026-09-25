-- The file tree, kept for orientation rather than navigation: it answers "how
-- is this laid out" at a glance, which a fuzzy finder cannot. Toggling it
-- leaves focus where I am, and the keys inside are nvim-tree's own (`g?` lists
-- them) minus what on_attach changes. What it lists is lua/mivn/filters.lua's
-- answer, shared with the finders.

-- A list of rows to point at, not text, so no cursor is drawn in it.
require("mivn.panel").hide_cursor_in("NvimTree")

-- One width, for the setup below and for the heal that puts it back after a
-- layout collapse.
local TREE_WIDTH = 32

--- Show or hide the tree, leaving focus where it is.
local function toggle()
  require("nvim-tree.api").tree.toggle({ focus = false })
end

--- The tree's window in this tab, or nil when it is not on screen. Read off the
--- filetype, since nvim-tree's own answer lives in nvim-tree.view, which is not
--- part of its api.
local function window()
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "NvimTree" then
      return win
    end
  end

  return nil
end

--- Whether the tree is on screen.
local function is_open()
  return window() ~= nil
end

--- The keys inside the tree ---------------------------------------------------
--
-- nvim-tree's defaults, minus the two that re-root it (`-` to the parent,
-- `Ctrl+]` into the directory under the cursor): the project is the root and
-- stays the root.
local function on_attach(bufnr)
  local api = require("nvim-tree.api")

  api.config.mappings.default_on_attach(bufnr)

  -- pcall, so an nvim-tree that stops binding these cannot break attach
  pcall(vim.keymap.del, "n", "-", { buffer = bufnr })
  pcall(vim.keymap.del, "n", "<C-]>", { buffer = bufnr })

  local function map(lhs, rhs, desc)
    vim.keymap.set("n", lhs, rhs, { buffer = bufnr, desc = desc, nowait = true })
  end

  -- `e` was nvim-tree's basename rename; now it opens the menu's dialog
  map("e", function()
    require("mivn.tree").rename()
  end, "Rename, with the stem preselected")

  -- NOTE: not api.node.open.edit alone. It toggles, which would make an expand
  -- key close an open directory, so both halves check the node first. Left on a
  -- row that cannot collapse closes the directory the cursor is in.
  local function expand()
    local node = api.tree.get_node_under_cursor()
    if node and node.nodes and not node.open then
      api.node.open.edit()
    end
  end

  local function collapse()
    local node = api.tree.get_node_under_cursor()
    if node and node.nodes and node.open then
      api.node.open.edit()
    else
      api.node.navigate.parent_close()
    end
  end

  map("=", expand, "Expand the directory")
  map("<Right>", expand, "Expand the directory")
  map("-", collapse, "Collapse the directory")
  map("<Left>", collapse, "Collapse the directory")

  -- nvim-tree's own two, pointed at the shared answer so the finders follow
  local filters = require("mivn.filters")

  map("H", filters.toggle_dotfiles, "Show or hide dotfiles, here and in the finders")
  map("I", filters.toggle_ignored, "Show or hide ignored files, here and in the finders")

  -- NOTE: the keys that would change text only say why nothing happens, and
  -- only where nvim-tree binds nothing: its mappings are read first, so a key
  -- it starts binding later stays its own. <Insert> is taken in Visual too,
  -- since it opens Insert from a selection; the letters are not, since there
  -- `i` picks out a text object and `A` appends to a block.
  local bound = {}
  for _, mapping in ipairs(vim.api.nvim_buf_get_keymap(bufnr, "n")) do
    bound[mapping.lhs] = true
  end

  local function not_editable()
    vim.notify("The tree is not editable.")
  end

  for _, lhs in ipairs({ "i", "A", "X", "<Insert>" }) do
    if not bound[lhs] then
      map(lhs, not_editable, "The tree is not editable")
    end
  end

  vim.keymap.set("x", "<Insert>", not_editable, {
    buffer = bufnr,
    desc = "The tree is not editable",
    nowait = true,
  })
end

--- The right-click menu -------------------------------------------------------
--
-- 'mousemodel' is popup_setpos (the default), so a right click moves the cursor
-- to the clicked row first, and these entries act on it. Menus are global with
-- no buffer-local form, so MenuPopup decides per click which half is usable:
-- the file actions inside the tree, Neovim's own text items everywhere else.

--- The rename on `e`: the floating prompt holding the full name, with the stem
--- (the name minus its last extension) preselected, so typing replaces it and
--- an arrow edits anything. nvim-tree's own rename does the work, fed the new
--- name through a one-shot vim.ui.input override.
local function rename()
  local api = require("nvim-tree.api")
  local node = api.tree.get_node_under_cursor()
  if not node or not node.parent then
    return
  end

  local name = node.name
  local stem = name:match("^(.+)%.[^.]+$") or name

  require("mivn.prompt").input({
    prompt = "Rename",
    default = name,
    scope = "cursor",
    select = { 0, #stem },
  }, function(typed)
    typed = vim.trim(typed or "")
    if typed == "" or typed == name then
      return
    end

    -- NOTE: restored after the call, not by the override itself. If the rename
    -- returns before asking (node gone, an error inside nvim-tree), a
    -- self-restore never runs and every later vim.ui.input gets this name.
    local saved = vim.ui.input
    ---@diagnostic disable-next-line: duplicate-set-field it is the point
    vim.ui.input = function(_, on_confirm)
      on_confirm(typed)
    end

    local ok, err = pcall(api.fs.rename, node)
    vim.ui.input = saved

    if not ok then
      error(err, 0)
    end
  end)
end

-- NOTE: the names differ from the stock Cut, Copy, Paste and Delete on purpose,
-- since a shared name would replace the stock entry. Low priorities put these
-- above the stock block. The key in parentheses is nvim-tree's own for the same
-- action, written into the name because Neovim's popup does not draw a menu's
-- <Tab> text.
local TREE_MENU = {
  { name = "New\\ file\\ (a)", rhs = "require('nvim-tree.api').fs.create()" },
  { name = "Rename\\ (e)", rhs = "require('mivn.tree').rename()" },
  { name = "Delete\\ file\\ (d)", rhs = "require('nvim-tree.api').fs.remove()" },
  { name = "Cut\\ file\\ (x)", rhs = "require('nvim-tree.api').fs.cut()" },
  { name = "Copy\\ file\\ (c)", rhs = "require('nvim-tree.api').fs.copy.node()" },
  { name = "Paste\\ here\\ (p)", rhs = "require('nvim-tree.api').fs.paste()" },

  -- The one entry that reaches the system clipboard. Cut, Copy and Paste above
  -- move files around and never leave the editor.
  { name = "Copy\\ path\\ (gy)", rhs = "require('nvim-tree.api').fs.copy.absolute_path()" },
}

local STOCK_MENU = { "Cut", "Copy", "Paste", "Delete", "Select\\ All" }

for i, item in ipairs(TREE_MENU) do
  vim.cmd(("nnoremenu %d PopUp.%s <Cmd>lua %s<CR>"):format(i * 10, item.name, item.rhs))
end

local function set_popup(in_tree)
  -- nvim_command: vim.cmd is a callable table, which the language server flags
  for _, item in ipairs(TREE_MENU) do
    pcall(vim.api.nvim_command, ("nmenu %s PopUp.%s"):format(in_tree and "enable" or "disable", item.name))
  end
  for _, name in ipairs(STOCK_MENU) do
    pcall(vim.api.nvim_command, ("nmenu %s PopUp.%s"):format(in_tree and "disable" or "enable", name))
  end
end

set_popup(false) -- the tree entries stay grayed until a click lands in one

vim.api.nvim_create_autocmd("MenuPopup", {
  group = vim.api.nvim_create_augroup("mivn.tree.menu", { clear = true }),
  desc = "Enable the tree's file actions only inside the tree",
  callback = function()
    set_popup(vim.bo.filetype == "NvimTree")
  end,
})

--- The count under a filtered directory ---------------------------------------
--
-- A directory whose contents are all filtered out would read as empty.
-- nvim-tree's "simple" count does not say which key brings the rows back, and
-- "all" uses its internal names and runs to about 30 columns, which wraps in a
-- panel this wide. So the reasons get the words the keys use, in the order
-- nvim-tree checks them.
--
-- Two at once is the most in normal use: `.git/` is all the custom filter hides
-- and it is a dotfile, so `custom` and `dotfile` are never both above zero.
-- Only the live filter makes three, and then the line is cut at the panel's
-- edge.

--- The filters that hide a row: nvim-tree's name for it, then the word to count
--- in, singular and plural. `buf` and `no_bookmark` are off here; they and
--- anything nvim-tree adds later count as plain "hidden" below, so the total
--- stays right.
local HIDDEN_REASONS = {
  { "git", "ignored", "ignored" },
  { "dotfile", "dotfile", "dotfiles" },
  { "custom", "filtered", "filtered" }, -- .git/, and only it
  { "live_filter", "unmatched", "unmatched" },
}

local function hidden_display(stats)
  local total = 0
  for _, count in pairs(stats) do
    total = total + count
  end

  if total == 0 then
    return nil
  end

  local parts, named = {}, 0

  for _, reason in ipairs(HIDDEN_REASONS) do
    local count = stats[reason[1]] or 0
    if count > 0 then
      named = named + count
      parts[#parts + 1] = ("%d %s"):format(count, count == 1 and reason[2] or reason[3])
    end
  end

  if total > named then
    parts[#parts + 1] = ("%d hidden"):format(total - named)
  end

  return ("(%s)"):format(table.concat(parts, ", "))
end

require("nvim-tree").setup({
  on_attach = on_attach,

  -- The dashboard handles being started on a directory, and hijacking would
  -- have the tree fight it for the window.
  hijack_directories = { enable = false },
  hijack_netrw = false,

  -- Keeps the undrawn cursor at the start of the file name, where the tree's
  -- own keys expect to find it.
  hijack_cursor = true,

  view = {
    width = TREE_WIDTH,
    signcolumn = "no",
  },

  -- Four states share a file's row without colliding: git colours the name, an
  -- open buffer bolds it, a diagnostic underlines it, and an unsaved edit puts
  -- a dot after it. Each adds only its own attribute (colors/basalt.lua).
  renderer = {
    group_empty = true, -- collapse a/b/c when each holds only the next
    root_folder_label = false,
    highlight_git = "name", -- color the file name
    highlight_opened_files = "name", -- bold, so the buffer I am in is findable
    highlight_diagnostics = "name", -- the undercurl, not a colour
    highlight_modified = "none", -- the dot says it; a colour would hide git's

    hidden_display = hidden_display,

    -- Nothing is special. The stock list draws README.md and Cargo.toml in the
    -- colour an open directory uses.
    special_files = {},

    indent_markers = { enable = true },
    icons = {
      show = {
        file = true,
        folder = true,
        folder_arrow = true,
        git = false,
        diagnostics = false,
      },
    },
  },

  -- Which files are broken, without opening them, warnings and up: a hint's
  -- underline is the comment grey anyway. No icon, since there is no sign
  -- column to put one in. `show_on_dirs` is the point, since a collapsed folder
  -- is the one case the buffer's own gutter cannot cover.
  diagnostics = {
    enable = true,
    show_on_dirs = true,
    severity = { min = vim.diagnostic.severity.WARN },
  },

  -- The tab bar already marks an unsaved buffer, so this is here for the folder
  -- that is collapsed over one.
  modified = { enable = true },

  -- The tree follows `:cd` and nothing else. `update_root` sounds alike and is
  -- not: it re-roots on whatever file I jump to, so a jump to a definition in
  -- the module cache would take the tree out of the project.
  sync_root_with_cwd = true,

  update_focused_file = {
    enable = true, -- highlight the file I am editing
    update_root = false,
  },

  git = { enable = true },

  -- The starting point is lua/mivn/filters.lua's, inverted: nvim-tree names
  -- what it hides, that module what it shows. `.git/` is named here, since it
  -- is a dotfile git does not ignore; `U` shows it, and only in the tree.
  filters = {
    dotfiles = not require("mivn.filters").dotfiles(),
    git_ignored = not require("mivn.filters").ignored(),
    custom = { "^\\.git$" },
  },

  actions = {
    open_file = {
      resize_window = false,

      -- NOTE: the stock list also excludes nofile windows, and the banner is
      -- one, so opening a file with only the banner up would split beside it.
      -- With nofile left out, the file lands in the banner's window.
      window_picker = {
        exclude = {
          filetype = { "notify", "qf", "diff" },
          buftype = { "terminal", "help", "prompt" },
        },
      },
    },
  },
})

--- The :bd guard --------------------------------------------------------------
--
-- `:bd` typed in the tree would delete the tree's own buffer and take the split
-- with it, so it becomes a command that says so. Narrow on purpose: a count
-- (`:2bd`) names a real buffer and runs untouched.

vim.api.nvim_create_user_command("MivnTreeBd", function()
  vim.notify("The tree is not a file. <Space>tt hides it; Ctrl+W l goes back to the code.")
end, {
  bang = true,
  desc = "What :bd becomes inside the tree",
})

local cmdline = require("mivn.cmdline")

cmdline.rewrite(function(line)
  if vim.bo.filetype ~= "NvimTree" then
    return nil
  end

  return cmdline.spells(line:match("^(%l+)!?$"), "bdelete", 2) and "MivnTreeBd" or nil
end)

-- Open at startup beside the banner, leaving me on the banner. Registered after
-- the dashboard's own VimEnter, so the dashboard has claimed its window first.
vim.api.nvim_create_autocmd("VimEnter", {
  group = vim.api.nvim_create_augroup("mivn.tree", { clear = true }),
  callback = function()
    if not require("mivn.session").empty_start() then
      return
    end

    vim.schedule(function()
      -- `focus = false` is not reliably honoured here, so it is done by hand
      local win = vim.api.nvim_get_current_win()
      require("nvim-tree.api").tree.open({ focus = false })
      if vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_set_current_win(win)
      end
    end)
  end,
})

return { toggle = toggle, window = window, is_open = is_open, rename = rename, WIDTH = TREE_WIDTH }
