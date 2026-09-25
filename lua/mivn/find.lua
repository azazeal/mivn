-- Finding things: files, text, buffers, commands, keys. These are the
-- operations Vim has no default key for, and the command palette keeps the list
-- short: anything rare goes through it instead of earning a key.

local M = {}

local pick = require("mini.pick")
local extra = require("mini.extra")

require("mini.icons").setup()
extra.setup()

-- nvim-tree looks for nvim-web-devicons by name; mini.icons stands in for it.
require("mini.icons").mock_nvim_web_devicons()

--- One key standing in for another inside the picker. A custom mapping's func
--- runs in the picker's own key loop, so feeding the target key through
--- nvim_input is how to alias it.
local function alias(char, target)
  return {
    char = char,
    func = function()
      vim.api.nvim_input(target)
    end,
  }
end

--- The centered float every picker draws. `rows` caps how tall it may get, for
--- short lists; the width never varies, so every float keeps the same left and
--- right edge.
local function float_config(rows)
  local height = math.max(1, math.min(rows, math.floor(vim.o.lines * 0.6)))
  local width = math.floor(vim.o.columns * 0.7)

  return {
    border = "rounded",
    anchor = "NW",
    height = height,
    width = width,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
  }
end

pick.setup({
  mappings = {
    -- Esc closes; the rest of the picker's keys are its own defaults.
    stop = "<Esc>",

    -- Every arrow walks the list and PageUp/PageDown page it; Ctrl+P/N and
    -- Ctrl+B/F stay too. The caret moves with Shift+Left and Shift+Right.
    caret_left = "<S-Left>",
    caret_right = "<S-Right>",
    move_down_arrow = alias("<Down>", "<C-n>"),
    move_up_arrow = alias("<Up>", "<C-p>"),
    move_left_arrow = alias("<Left>", "<C-p>"),
    move_right_arrow = alias("<Right>", "<C-n>"),
    page_up_arrow = alias("<PageUp>", "<C-b>"),
    page_down_arrow = alias("<PageDown>", "<C-f>"),
  },
  options = {
    -- The list grows down from the top; a query already answered is not rerun.
    content_from_bottom = false,
    use_cache = true,
  },
  window = {
    config = function()
      return float_config(math.huge)
    end,
  },
})

-- mini.pick's setup() already points vim.ui.select at the picker; this only
-- sizes the float to the list.
---@diagnostic disable-next-line: duplicate-set-field it is the point
vim.ui.select = function(items, opts, on_choice)
  pick.ui_select(items, opts, on_choice, {
    window = {
      config = function()
        return float_config(#items)
      end,
    },
  })
end

--- The pickers ----------------------------------------------------------------

--- The command that lists the project's files, or nil if neither rg nor fd is
--- here. It shows lua/mivn/filters.lua's answer, the one the tree draws; both
--- tools apply .gitignore themselves, and `.git/` is left out by hand.
---
--- The flags are spelled out rather than left to the ripgrep config that module
--- writes, because `fd` reads no config file at all. Not mini.extra's
--- git_files: that lists what git tracks, which is nothing in a repository with
--- no commits yet.
local function files_command()
  local shown = require("mivn.filters")

  if vim.fn.executable("rg") == 1 then
    local command = { "rg", "--files", "--glob", "!.git/", "--color=never" }

    if shown.dotfiles() then
      table.insert(command, "--hidden")
    end

    if shown.ignored() then
      table.insert(command, "--no-ignore")
    end

    return command
  end

  if vim.fn.executable("fd") == 1 then
    local command = { "fd", "--type=f", "--exclude", ".git", "--color=never" }

    if shown.dotfiles() then
      table.insert(command, "--hidden")
    end

    if shown.ignored() then
      table.insert(command, "--no-ignore")
    end

    return command
  end

  return nil
end

function M.files()
  local command = files_command()

  -- neither tool: mini.pick's own walk, which has no ignore rules
  if not command then
    return pick.builtin.files()
  end

  pick.builtin.cli({ command = command }, {
    source = {
      name = "Files",
      show = function(buf_id, items, query)
        pick.default_show(buf_id, items, query, { show_icons = true })
      end,
    },
  })
end

function M.grep()
  pick.builtin.grep_live()
end

function M.buffers()
  pick.builtin.buffers()
end

--- Where a language server says a thing is -----------------------------------
--
-- Stock puts more than one answer in the quickfix list and opens it with
-- `botright copen`, a window arriving in a layout that did not ask for one; it
-- can leave the screen holding the tree, a quickfix and no file. So these go
-- through the picker, like every other "pick one of these".

--- Go to `item` the way Neovim goes to a lone answer: Ctrl+O and Ctrl+T both
--- walk back out, and the folds over it open.
---
--- NOTE: done here because Neovim checks `on_list` before its own single-answer
--- path, so asking for the list at all gives up its jump.
local function jump(item, tagname, from)
  vim.cmd("normal! m'")
  vim.fn.settagstack(vim.api.nvim_get_current_win(), { items = { { tagname = tagname, from = from } } }, "t")

  local buf = item.bufnr or vim.fn.bufadd(item.filename)
  vim.bo[buf].buflisted = true

  vim.api.nvim_win_set_buf(0, buf)
  vim.api.nvim_win_set_cursor(0, { item.lnum, item.col - 1 })
  vim.cmd("normal! zv")
end

--- Run `request` and show what comes back: one answer is a jump, several are a
--- picker. `request` takes the options table every vim.lsp.buf list request
--- takes; one that needs an argument of its own is wrapped in a function.
function M.list(request)
  return function()
    -- for the tag stack, read before the jump moves them
    local from = vim.fn.getpos(".")
    from[1] = vim.api.nvim_get_current_buf()
    local tagname = vim.fn.expand("<cword>")

    request({
      on_list = function(list)
        local items = list.items or {}

        if #items == 1 then
          return jump(items[1], tagname, from)
        end

        pick.start({
          source = {
            name = list.title or "Locations",
            items = vim.tbl_map(function(item)
              return {
                text = ("%s:%d: %s"):format(
                  vim.fn.fnamemodify(item.filename, ":."),
                  item.lnum,
                  vim.trim(item.text or "")
                ),
                path = item.filename,
                lnum = item.lnum,
                col = item.col,
              }
            end, items),
          },
        })
      end,
    })
  end
end

function M.help()
  pick.builtin.help()
end

--- Everything the servers have said about the whole workspace.
function M.diagnostics()
  extra.pickers.diagnostic({ scope = "all" })
end

--- The same, narrowed to the file I am in.
function M.buffer_diagnostics()
  extra.pickers.diagnostic({ scope = "current" })
end

--- Every mapping there is, searchable, with its description: Vim's own, the
--- plugins' and the current buffer's, so it answers "is this key taken".
--- Picking one runs it.
function M.keymaps()
  extra.pickers.keymaps()
end

--- Does this command's `definition` read as prose or as an implementation?
---
--- Commands defined from Lua carry their `desc` here, worth showing; ones
--- defined in Vimscript carry their body, which is noise.
local function is_description(definition)
  if definition == nil or definition == "" then
    return false
  end
  return not (
    definition:find("^%s*:")
    or definition:find("<[qf]?%-?args>")
    or definition:find("^%s*call%s")
    or definition:find("^%s*exe")
    or definition:find("^%s*lua%s")
    or definition:find("[%w_]%(")
  )
end

--- The everyday built-in commands, described by hand, since `desc` is a
--- user-command field only. The two split entries describe this config, where
--- 'splitbelow' and 'splitright' are set.
local BUILTINS = {
  bdelete = "Close a buffer: it leaves the tab bar, the file stays on disk",
  bnext = "The next buffer in the tab bar",
  bprevious = "The previous buffer in the tab bar",
  buffer = "Switch to a buffer, by number or name",
  buffers = "List the open buffers",
  checkhealth = "Diagnose the setup",
  edit = "Open a file; :e! reloads the current one, dropping unsaved changes",
  help = "Open help for a topic",
  messages = "Messages that have scrolled away",
  nohlsearch = "Stop highlighting the last search",
  only = "Close every window but this one",
  quit = "Close the window; closing the last one quits",
  quitall = "Quit; refuses if something is unsaved (:qa! discards and quits)",
  split = "Split the window, new one below",
  substitute = "Search and replace: :%s/old/new/g does the whole file",
  terminal = "A terminal in a buffer",
  vsplit = "Split the window, new one to the right",
  wall = "Save every changed file",
  wq = "Save, then close the window",
  write = "Save the file",
  xit = "Save if changed, then close the window",
}

--- Every command, with a description where one exists. Not mini.extra's
--- commands picker: it lists bare names, which only helps when I already know
--- what a thing is called.
function M.palette()
  local meta = vim.tbl_deep_extend("force", vim.api.nvim_get_commands({}), vim.api.nvim_buf_get_commands(0, {}))

  local names = vim.fn.getcompletion("", "command")
  local width = 0
  for _, name in ipairs(names) do
    width = math.max(width, #name)
  end

  local items = {}
  for _, name in ipairs(names) do
    local data = meta[name]

    local desc = BUILTINS[name]
    if data and is_description(data.definition) then
      desc = data.definition
    end

    local text = name
    if desc then
      text = ("%-" .. width .. "s  %s"):format(name, desc)
    end
    items[#items + 1] = { text = text, name = name, nargs = data and data.nargs }
  end

  pick.start({
    source = {
      name = "Commands",
      items = items,
      choose = function(item)
        -- only one with no arguments runs; the rest wait on the command line
        local keys = (":%s%s"):format(item.name, item.nargs == "0" and "\r" or " ")
        vim.schedule(function()
          vim.fn.feedkeys(keys)
        end)
      end,
    },
  })
end

return M
