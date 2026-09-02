-- The file tree.
--
-- Kept for orientation rather than navigation: it answers "how is this laid
-- out" at a glance, which a fuzzy finder cannot. Files are opened with
-- <leader>f, not from here.
--
-- It gets one key of its own, <leader>tt, which toggles whether it is on
-- screen. Focus stays where I am, since the toggle is about the width and not
-- about going there. Moving in and out is <C-w>h and <C-w>l, and the keys
-- inside are nvim-tree's own (`g?` lists them), minus what `on_attach`
-- removes and the two it re-points at lua/mivn/filters.lua.
--
-- What it lists is not its own business: dotfiles and ignored files are one
-- answer shared with the finders, and that module holds it.

-- A list of rows to point at, not text with columns, so no cursor is drawn in
-- it. See lua/mivn/panel.lua, which owns this because 'guicursor' is global.
require("mivn.panel").hide_cursor_in("NvimTree")

-- One width, used by the setup below and by the heal that restores it after
-- a layout collapse; the two drifting apart makes the heal resize the tree.
local TREE_WIDTH = 32

--- Show or hide the tree, leaving focus where it is; <leader>tt in
--- lua/mivn/keymaps.lua.
local function toggle()
  require("nvim-tree.api").tree.toggle({ focus = false })
end

--- Whether the tree has a window in this tab.
---
--- Asked by lua/mivn/restart.lua, which has to know what to put back. Read
--- off the filetype the way lua/mivn/session.lua does, rather than through
--- nvim-tree: the answer it has lives in nvim-tree.view, which is not part of
--- the api module and not mine to reach into.
local function is_open()
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "NvimTree" then
      return true
    end
  end

  return false
end

--- The keys inside the tree ---------------------------------------------------
--
-- nvim-tree's defaults, minus two keys: `-` (re-root to the parent) and
-- `Ctrl+]` (re-root into the directory under the cursor). The project is the
-- root and stays the root.
local function on_attach(bufnr)
  local api = require("nvim-tree.api")

  api.config.mappings.default_on_attach(bufnr)

  -- pcall so an nvim-tree release that stops binding these cannot break
  -- attach.
  pcall(vim.keymap.del, "n", "-", { buffer = bufnr })
  pcall(vim.keymap.del, "n", "<C-]>", { buffer = bufnr })

  local function map(lhs, rhs, desc)
    vim.keymap.set("n", lhs, rhs, { buffer = bufnr, desc = desc, nowait = true })
  end

  -- `e` was already Rename: Basename; this re-points it at the same dialog
  -- the right-click menu opens, full name shown, stem preselected.
  map("e", function()
    require("mivn.tree").rename()
  end, "Rename, with the stem preselected")

  -- Expand and collapse on the keys a CUA tree teaches. Node-level only: the
  -- root never moves. Not api.node.open.edit alone, because that toggles,
  -- and a toggle would make an "expand" key close an open directory; both
  -- halves check the node's state first. Left on a row that cannot collapse
  -- closes the directory the cursor is in, the Backspace behavior.
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

  -- nvim-tree's own two, re-pointed at the shared answer so that flipping
  -- one here flips it for the finders as well. Same keys, same meaning, one
  -- more place they reach.
  local filters = require("mivn.filters")

  map("H", filters.toggle_dotfiles, "Show or hide dotfiles, here and in the finders")
  map("I", filters.toggle_ignored, "Show or hide ignored files, here and in the finders")

  -- The keys that change text, on a buffer that is 'nomodifiable'. Most of
  -- them are nvim-tree's own here and do real work (`a` creates, `r` renames,
  -- `d` deletes), so only what it leaves alone is taken, and only to say why
  -- nothing happens. Reading its mappings first rather than naming the
  -- leftovers keeps a key it starts binding later as its own.
  --
  -- `<Insert>` is spelled out because it is a name and not a character, and it
  -- is the one taken in Visual as well, since lua/mivn/keymaps.lua opens
  -- Insert with it from a selection too. The letters are not: there `i` picks
  -- out a text object and `A` appends to a block.
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

--- The right-click menu --------------------------------------------------------
--
-- 'mousemodel' is popup_setpos (the default), so a right click first moves the
-- cursor to the clicked row and then opens the PopUp menu; these entries act
-- on the row I clicked. Menus are global with no buffer-local form, so the
-- MenuPopup event decides per click which half is usable: the file actions
-- inside the tree, Neovim's own text items everywhere else. Disabled entries
-- stay visible, grayed.

--- The rename on `e`: the floating prompt (lua/mivn/prompt.lua) holding the
--- full name, with the stem (the name minus its last extension) preselected in
--- Select mode. Typing replaces the stem, an arrow drops the selection and
--- edits anything, extension included. nvim-tree's own rename does the
--- actual work (buffer renames and tree refresh included), fed the new name
--- through a one-shot vim.ui.input override; the save/restore keeps the
--- prompt module's global intact.
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

    -- Restored after the call, not inside the override: if the rename bails
    -- before prompting (node gone, an error inside nvim-tree), a self-restore
    -- never runs and the override would sit there feeding this name to the
    -- next vim.ui.input caller anywhere in the session.
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

-- Distinct names on purpose: the stock menu already has Cut, Copy, Paste and
-- Delete, and a shared name would replace the stock entry instead of
-- coexisting with it. Low priorities put these above the stock block. The
-- key in parentheses is nvim-tree's own default for the same action, written
-- into the name because Neovim's builtin popup does not render a menu's
-- <Tab> accelerator text (measured; gvim would).
local TREE_MENU = {
  { name = "New\\ file\\ (a)", rhs = "require('nvim-tree.api').fs.create()" },
  { name = "Rename\\ (e)", rhs = "require('mivn.tree').rename()" },
  { name = "Delete\\ file\\ (d)", rhs = "require('nvim-tree.api').fs.remove()" },
  { name = "Cut\\ file\\ (x)", rhs = "require('nvim-tree.api').fs.cut()" },
  { name = "Copy\\ file\\ (c)", rhs = "require('nvim-tree.api').fs.copy.node()" },
  { name = "Paste\\ here\\ (p)", rhs = "require('nvim-tree.api').fs.paste()" },

  -- The one entry that talks to the system clipboard. Cut/Copy/Paste above
  -- are nvim-tree's own file operations (move or duplicate on paste) and
  -- never leave the editor; this one puts the absolute path on the clipboard
  -- for any other program.
  { name = "Copy\\ path\\ (gy)", rhs = "require('nvim-tree.api').fs.copy.absolute_path()" },
}

local STOCK_MENU = { "Cut", "Copy", "Paste", "Delete", "Select\\ All" }

for i, item in ipairs(TREE_MENU) do
  vim.cmd(("nnoremenu %d PopUp.%s <Cmd>lua %s<CR>"):format(i * 10, item.name, item.rhs))
end

local function set_popup(in_tree)
  -- nvim_command, not vim.cmd: pcall wants a function, and vim.cmd is a
  -- callable table the language server rightly flags as one.
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

--- The count under a filtered directory -----------------------------------------
--
-- A directory whose contents are all filtered out reads as empty otherwise,
-- which is the lie lua/mivn/filters.lua exists to avoid, told inside the tree
-- instead of between the tree and the finders.
--
-- nvim-tree's own two answers are both wrong here: "simple" says "(3 hidden)"
-- without saying which key brings the rows back, and "all" spells the reason
-- out with nvim-tree's internal names and runs to about 30 columns, which
-- wraps in a panel this wide. So the reasons get the words the keys use, in
-- the order nvim-tree checks them.
--
-- Two of them at once is the ceiling in normal use, which fits: `.git/` is
-- the only thing the custom filter hides and it counts as a dotfile whenever
-- dotfiles are hidden, so `custom` and `dotfile` are never both above zero.
-- Only the live filter can make it three, and there the line is cut off at
-- the panel's edge.

--- The filters that hide a row: nvim-tree's name for it, then the word to
--- count in, singular and plural. `buf` and `no_bookmark` are off here, so
--- they are not named; they and anything nvim-tree adds later fall into the
--- plain "hidden" below rather than going missing from the total.
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

  -- The dashboard already handles being started on a directory, and hijacking
  -- would have the tree fight it for the window.
  hijack_directories = { enable = false },
  hijack_netrw = false,

  -- The cursor snaps to the start of the file name on every move. With nothing
  -- drawn there, this is what keeps the invisible cursor somewhere the tree's
  -- own keys expect to find it.
  hijack_cursor = true,

  view = {
    width = TREE_WIDTH,
    signcolumn = "no",
  },

  -- Four states share a file's row, on four planes that cannot collide: git
  -- colours the name, an open buffer bolds it, a diagnostic underlines it,
  -- and an unsaved edit puts a dot after it. The decorators are additive, so
  -- each adds only its own attribute; colors/basalt.lua carries the WARN
  -- about what happens if one of them sets a foreground.
  renderer = {
    group_empty = true, -- collapse a/b/c when each holds only the next
    root_folder_label = false,
    highlight_git = "name", -- color the file name, as Zed does
    highlight_opened_files = "name", -- bold, so the buffer I am in is findable
    highlight_diagnostics = "name", -- the undercurl, not a colour
    highlight_modified = "none", -- the dot says it; a colour would hide git's

    hidden_display = hidden_display, -- see above

    -- Nothing is special. The stock list draws README.md and Cargo.toml in
    -- the colour an open directory uses.
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

  -- Which files are broken, without opening them. Capped at warnings: a hint
  -- is what a linter puts in a list, not what a layout panel says at a
  -- glance, and its underline colour is the comment grey anyway.
  --
  -- No icon: there is no sign column here (`view.signcolumn` above), which is
  -- where nvim-tree would put one, so asking for it would draw nothing.
  -- `show_on_dirs` is the whole value, since a collapsed folder is the one
  -- case the buffer's own gutter cannot cover.
  diagnostics = {
    enable = true,
    show_on_dirs = true,
    severity = { min = vim.diagnostic.severity.WARN },
  },

  -- The tab bar already marks an unsaved buffer, so this is here for the
  -- folder that is collapsed over one.
  modified = { enable = true },

  -- The tree follows `:cd` and nothing else.
  --
  -- Two settings that sound alike and are not. `sync_root_with_cwd` re-roots
  -- on DirChanged, which is me saying where I am working now, and the tree
  -- being left behind on the old project after that was the one place a `:cd`
  -- did not land. `update_root` would re-root on whatever file I jumped to,
  -- which is not me saying anything: a jump to a definition in the module
  -- cache would climb the tree straight out of the project.
  sync_root_with_cwd = true,

  update_focused_file = {
    enable = true, -- highlight the file I am editing
    update_root = false,
  },

  git = { enable = true },

  -- The starting point is lua/mivn/filters.lua's, which the finders read too,
  -- and these two flags are its opposite: nvim-tree names what it filters out
  -- where that module names what is shown.
  --
  -- .git/ is the exception both rules miss, since it is a dotfile and git does
  -- not ignore its own directory, so it is named here. `U` toggles it back on,
  -- and it is the one filter that is the tree's alone.
  filters = {
    dotfiles = not require("mivn.filters").dotfiles(),
    git_ignored = not require("mivn.filters").ignored(),
    custom = { "^\\.git$" },
  },

  actions = {
    open_file = {
      resize_window = false,

      -- The default picker refuses nofile windows, and the banner is one:
      -- opening from the tree (Enter or double click) with only the banner up
      -- used to split a new window beside it instead of replacing it. With
      -- nofile allowed, the banner window is an ordinary target, the file
      -- lands in it, and the banner buffer wipes itself.
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
-- `:bd` typed with the cursor parked in the tree used to delete the tree's own
-- buffer and take the split with it. Vim has no cancellable pre-delete event,
-- so the deletion itself cannot be vetoed; what can be changed is the command
-- line, on CmdlineLeavePre, the moment before it runs. Any spelling of bdelete
-- typed alone from the tree window is rewritten to a command that explains.
--
-- Narrow on purpose: a count (`:2bd`) names a real buffer and runs untouched,
-- and so does anything scripted through nvim_cmd or <Cmd>, which the event
-- does not fire for. Those land on the old annoying-but-recoverable
-- behavior, and the layout invariant below keeps the aftermath survivable.
--
-- Not a command-line abbreviation, the classic tool here: measured, its bang
-- trigger was flaky, with `:bd!` right after an expanded `:bd` sailing through
-- unexpanded. This event fires exactly once per executed command line.

vim.api.nvim_create_user_command("MivnTreeBd", function()
  vim.notify("The tree is not a file. <Space>tt hides it; Ctrl+W l goes back to the code.")
end, {
  bang = true,
  desc = "What :bd becomes inside the tree",
})

vim.api.nvim_create_autocmd("CmdlineLeavePre", {
  group = vim.api.nvim_create_augroup("mivn.tree.bd", { clear = true }),
  desc = "Rewrite :bd typed inside the tree",
  callback = function()
    if vim.bo.filetype ~= "NvimTree" or vim.fn.getcmdtype() ~= ":" then
      return
    end

    -- Any prefix of "bdelete" at least two letters long, i.e. the spellings
    -- that actually run it.
    local word = vim.fn.getcmdline():match("^(%l+)!?$")
    if word and #word >= 2 and ("bdelete"):find(word, 1, true) == 1 then
      vim.fn.setcmdline("MivnTreeBd")
    end
  end,
})

-- The layout invariant, "the tree is never the only window", lives in
-- lua/mivn/session.lua with the rest of the endgame rules; it reads the
-- width exported below when it heals a collapsed layout.

-- Open at startup beside the landing buffer, without taking focus, so I land
-- on the banner. Registered after the dashboard's own VimEnter so it goes into
-- the window the dashboard has already claimed.
vim.api.nvim_create_autocmd("VimEnter", {
  group = vim.api.nvim_create_augroup("mivn.tree", { clear = true }),
  callback = function()
    if not require("mivn.session").empty_start() then
      return
    end

    vim.schedule(function()
      -- `focus = false` is not reliably honoured here, so the window is put
      -- back by hand.
      local win = vim.api.nvim_get_current_win()
      require("nvim-tree.api").tree.open({ focus = false })
      if vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_set_current_win(win)
      end
    end)
  end,
})

-- toggle is <leader>tt's, in lua/mivn/keymaps.lua; rename is only for the
-- menu's Rename entry, which reaches it by module name; is_open is
-- restart.lua's; WIDTH is for session.lua's heal.
return { toggle = toggle, is_open = is_open, rename = rename, WIDTH = TREE_WIDTH }
