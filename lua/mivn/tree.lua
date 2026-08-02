-- The file tree.
--
-- Kept for orientation rather than navigation: it answers "how is this laid
-- out" at a glance, which a fuzzy finder cannot. Files are opened with
-- <leader>f, not from here.
--
-- It gets exactly one key, <leader>t, which toggles whether it is on screen.
-- Focus stays where I am, since the toggle is about the width and not about
-- going there. Moving in and out is <C-w>h and <C-w>l, and the keys inside are
-- nvim-tree's own (`g?` lists them), minus what `on_attach` removes.

-- A list of rows to point at, not text with columns, so no cursor is drawn in
-- it. See lua/mivn/panel.lua, which owns this because 'guicursor' is global.
require("mivn.panel").hide_cursor_in("NvimTree")

vim.keymap.set("n", "<leader>t", function()
  require("nvim-tree.api").tree.toggle({ focus = false })
end, { desc = "Show or hide the file tree", silent = true })

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
end

--- The right-click menu --------------------------------------------------------
--
-- 'mousemodel' is popup_setpos (the default), so a right click first moves the
-- cursor to the clicked row and then opens the PopUp menu; these entries act
-- on the row I clicked. Menus are global with no buffer-local form, so the
-- MenuPopup event decides per click which half is usable: the file actions
-- inside the tree, Neovim's own text items everywhere else. Disabled entries
-- stay visible, grayed.

--- The F2 rename: a one-line float holding the full name, with the stem (the
--- name minus its last extension) preselected in Select mode. Typing replaces
--- the stem, an arrow drops the selection and edits anything, extension
--- included. Enter accepts, Esc cancels. nvim-tree's own rename does the
--- actual work (buffer renames and tree refresh included), fed the new name
--- through a one-shot vim.ui.input override. A plain prompt cannot do this:
--- cmdline input can prefill text but has no selection.
local function rename()
  local api = require("nvim-tree.api")
  local node = api.tree.get_node_under_cursor()
  if not node or not node.parent then
    return
  end

  local name = node.name
  local stem = name:match("^(.+)%.[^.]+$") or name

  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "wipe"
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { name })

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "cursor",
    row = 1,
    col = 0,
    width = math.max(#name + 8, 24),
    height = 1,
    style = "minimal",
    border = "rounded",
    title = " Rename ",
    title_pos = "center",
  })

  local function close()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end

  local function accept()
    local typed = vim.trim(vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] or "")
    close()
    if typed == "" or typed == name then
      return
    end

    local saved = vim.ui.input
    vim.ui.input = function(_, on_confirm)
      vim.ui.input = saved
      on_confirm(typed)
    end
    api.fs.rename(node)
  end

  vim.keymap.set({ "n", "i", "s" }, "<CR>", accept, { buffer = buf })
  vim.keymap.set({ "n", "i", "s" }, "<Esc>", close, { buffer = buf })

  -- Charwise Select over the stem alone. 'selection' is exclusive (init.lua),
  -- so the endpoint is the character after the stem: the dot, or one past the
  -- end for a name with no extension, which 'virtualedit' makes reachable.
  vim.wo[win].virtualedit = "onemore"
  vim.api.nvim_win_set_cursor(win, { 1, 0 })
  vim.cmd("normal! v")
  vim.api.nvim_win_set_cursor(win, { 1, #stem })
  vim.cmd("normal! " .. vim.keycode("<C-g>"))
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
  for _, item in ipairs(TREE_MENU) do
    pcall(vim.cmd, ("nmenu %s PopUp.%s"):format(in_tree and "enable" or "disable", item.name))
  end
  for _, name in ipairs(STOCK_MENU) do
    pcall(vim.cmd, ("nmenu %s PopUp.%s"):format(in_tree and "disable" or "enable", name))
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
    width = 32,
    signcolumn = "no",
  },

  renderer = {
    group_empty = true, -- collapse a/b/c when each holds only the next
    root_folder_label = false,
    highlight_git = "name", -- color the file name, as Zed does
    indent_markers = { enable = true },
    icons = {
      show = { file = true, folder = true, folder_arrow = true, git = false },
    },
  },

  -- The tree is rooted at the working directory and stays there. `update_root`
  -- off is what keeps it from climbing out of the project when a jump to a
  -- definition lands in the module cache.
  update_focused_file = {
    enable = true, -- highlight the file I am editing
    update_root = false,
  },

  git = { enable = true },

  -- Dotfiles shown, gitignored hidden: a dotfile is usually project
  -- configuration I want to see, an ignored directory is build output.
  --
  -- .git/ is the exception both rules miss, since it is a dotfile and git does
  -- not ignore its own directory, so it is named here. `U` toggles it back on,
  -- the way `H` and `I` toggle the other two.
  filters = {
    dotfiles = false,
    git_ignored = true,
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
  vim.notify("The tree is not a file. <Space>t hides it; Ctrl+W l goes back to the code.")
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

--- The layout invariant -------------------------------------------------------
--
-- The tree is never the only window. A window holding it cannot show a file,
-- since nvim-tree takes its buffer back, so a layout that is nothing but the
-- tree is one I cannot type my way out of, and `:q` on the last file window is
-- enough to land there.
--
-- A `:q` that leaves the tree alone meant quit, though: with the tree as the
-- only survivor there is nothing left to be in, so the session ends, the
-- same answer stock Vim gives `:q` on its last window. But quit intent has
-- to be read from the command, not the layout: plugins close windows too
-- (nvim-tree deleting an open file takes that file's window with it), and
-- those closes must land on the heal, not on a quit. QuitPre is the tell; it
-- fires for the quit family and nothing else. When there is no quit behind
-- the close, or Vim refuses the quit (unsaved work somewhere), the layout
-- heals instead: an editing window comes back beside the tree, unsaved work
-- first so it has somewhere to be seen.

local TREE_WIDTH = 32

--- The buffer to put back in front of me, or nil for the landing buffer.
---
--- Unsaved first: this only runs after a quit was refused over unsaved work,
--- so that work is what the window is for. Most recently used breaks the tie.
local function last_real_buffer()
  local best, best_key = nil, -1

  for _, info in ipairs(vim.fn.getbufinfo({ buflisted = 1 })) do
    local modified = vim.bo[info.bufnr].modified
    local ok = vim.api.nvim_buf_is_valid(info.bufnr)
      and vim.bo[info.bufnr].buftype == ""
      and (info.name ~= "" or modified)

    local key = info.lastused + (modified and 2 ^ 40 or 0)
    if ok and key > best_key then
      best, best_key = info.bufnr, key
    end
  end

  return best
end

-- When the last quit command started, in nanoseconds. heal() reads it on the
-- tick after WinClosed, so the window is generous; a stale stamp (a quit Vim
-- refused, which fires QuitPre but closes nothing) expires on its own.
local quit_at = 0

vim.api.nvim_create_autocmd("QuitPre", {
  group = vim.api.nvim_create_augroup("mivn.tree.quit", { clear = true }),
  desc = "Remember that a window close came from a quit command",
  callback = function()
    quit_at = vim.uv.hrtime()
  end,
})

local function heal()
  if vim.v.exiting ~= vim.NIL then
    return
  end

  -- Floating windows do not count: a picker or a hover comes and goes.
  local windows = vim.tbl_filter(function(win)
    return vim.api.nvim_win_get_config(win).relative == ""
  end, vim.api.nvim_list_wins())

  if #windows ~= 1 then
    return
  end

  local tree = windows[1]
  if vim.bo[vim.api.nvim_win_get_buf(tree)].filetype ~= "NvimTree" then
    return
  end

  -- Quit only a quit: the stamp says this close came from the `:q` family
  -- moments ago. No bang on the quitall: unsaved work anywhere makes it
  -- throw, and the rescue below runs instead. On success nothing after this
  -- line happens.
  local quitting = vim.uv.hrtime() - quit_at < 500e6
  quit_at = 0

  if quitting and pcall(vim.cmd.quitall) then
    return
  end

  vim.cmd("rightbelow vsplit")
  local win = vim.api.nvim_get_current_win()

  local buf = last_real_buffer()
  if buf then
    vim.api.nvim_win_set_buf(win, buf)
  else
    require("mivn.dashboard").open()
  end

  -- The split halved it. Panels keep their width.
  if vim.api.nvim_win_is_valid(tree) then
    vim.api.nvim_win_set_width(tree, TREE_WIDTH)
  end
end

vim.api.nvim_create_autocmd("WinClosed", {
  group = vim.api.nvim_create_augroup("mivn.tree.layout", { clear = true }),
  -- Deferred because the window being closed is still in the list while this
  -- fires; the count is only true afterwards.
  callback = function()
    vim.schedule(heal)
  end,
})

-- Open at startup beside the landing buffer, without taking focus, so I land
-- on the banner. Registered after the dashboard's own VimEnter so it goes into
-- the window the dashboard has already claimed.
vim.api.nvim_create_autocmd("VimEnter", {
  group = vim.api.nvim_create_augroup("mivn.tree", { clear = true }),
  callback = function()
    if vim.fn.argc() > 1 then
      return
    end
    -- argv() returns a list and argv(n) a string, under one annotation, so the
    -- cast says which call this is.
    local arg = vim.fn.argv(0) --[[@as string]]
    if vim.fn.argc() == 1 and vim.fn.isdirectory(arg) == 0 then
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

-- Only for the menu's Rename entry, which reaches it by module name.
return { rename = rename }
