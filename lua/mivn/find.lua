-- Finding things: files, text, buffers, commands, keys. These are the
-- operations Vim has no default key for, so this is the short list of
-- additions, and the command palette is what keeps it short: anything rare
-- goes through it instead of earning a key.
--
-- The keys that open these are lua/mivn/keymaps.lua's, which is also what
-- <Space>? lists.

local M = {}

local pick = require("mini.pick")
local extra = require("mini.extra")

require("mini.icons").setup()
extra.setup()

-- nvim-tree looks for nvim-web-devicons by name; mini.icons stands in for it,
-- which saves a second icon plugin doing the same job.
require("mini.icons").mock_nvim_web_devicons()

--- One key standing in for another inside the picker: a custom mapping's
--- func runs in the picker's own key loop, so feeding the target key through
--- nvim_input is the supported way to alias it.
local function alias(char, target)
  return {
    char = char,
    func = function()
      vim.api.nvim_input(target)
    end,
  }
end

--- The centered float every picker draws. `rows` caps how tall it may get,
--- for lists short enough that the standard height would be mostly empty air;
--- the width never varies, so every float keeps the same left and right edge.
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

    -- Every arrow walks the list (all four read as "move along it" to my
    -- hands), and PageUp/PageDown page it; Ctrl+P/N and Ctrl+B/F, the keys
    -- underneath, stay too. The caret still moves, one pair over: Shift with
    -- Left or Right, freed up by the arrows' new job.
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
    -- The list grows down from the top, the way every other list here reads,
    -- and a query already answered is not run again.
    content_from_bottom = false,
    use_cache = true,
  },
  window = {
    config = function()
      return float_config(math.huge)
    end,
  },
})

-- mini.pick's setup() has already pointed vim.ui.select at itself, which is
-- what sends <leader>aa code actions and every other "pick one of these" through
-- the picker. This wrapper only sizes the float to the list: three code
-- actions in a full-height window is mostly empty air.
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

--- The command that lists the project's files, or nil if neither tool is here.
---
--- What it shows is lua/mivn/filters.lua's answer, the one the tree draws, so
--- the two views of a directory agree. Both tools apply .gitignore themselves,
--- which is the ignored half of it; `.git/` is excluded by hand whatever the
--- answer, because it is neither ignored nor worth seeing.
---
--- Spelled out here rather than left to the ripgrep configuration that module
--- writes, because `fd` reads no configuration file at all and this is the
--- only place its flags can come from.
---
--- Not mini.extra's git_files picker: that lists what git *tracks*, which is
--- nothing in a repository with no commits yet, so the finder would open empty
--- on the day a project starts.
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

  -- Neither tool present: mini.pick's own walk, which has no ignore rules but
  -- at least lists something.
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
-- Stock puts more than one answer in the quickfix list and opens a quickfix
-- window with `botright copen`, which is a window arriving in a layout that
-- did not ask for one: measured, it can leave the screen holding the tree and
-- a quickfix and no file at all. Every other "pick one of these" in this
-- config is the same float, so these are too.

--- Go to `item`, the way Neovim goes to a lone answer.
---
--- The jumplist takes the position being left and the tag stack takes an
--- entry, so Ctrl+O and Ctrl+T both walk back out; `zv` opens the folds over
--- wherever it lands. Reproduced here rather than left to Neovim because
--- `on_list` is checked before its own single-answer path, so asking for the
--- list at all gives up the jump.
local function jump(item, tagname, from)
  vim.cmd("normal! m'")
  vim.fn.settagstack(vim.api.nvim_get_current_win(), { items = { { tagname = tagname, from = from } } }, "t")

  local buf = item.bufnr or vim.fn.bufadd(item.filename)
  vim.bo[buf].buflisted = true

  vim.api.nvim_win_set_buf(0, buf)
  vim.api.nvim_win_set_cursor(0, { item.lnum, item.col - 1 })
  vim.cmd("normal! zv")
end

--- Run `request` and show what comes back: one answer is a jump, several are
--- a picker.
---
--- `request` takes the options table every vim.lsp.buf list request takes,
--- so a request needing an argument of its own is a one-line function that
--- passes it along.
function M.list(request)
  return function()
    -- Both are what the tag stack wants and neither survives the jump, so
    -- they are read before the request goes out.
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

--- Every mapping there is, searchable.
---
--- The list mivn adds is short and lua/mivn/keymaps.lua is the whole of it,
--- but that file cannot answer "is this key taken", which is the question this
--- one is for: Vim's own grammar, the plugins' keys and the buffer-local ones
--- the current buffer carries are all in here, each with the description its
--- mapping was given. Picking one runs it.
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

--- The everyday built-in commands, described by hand.
---
--- Built-in commands carry no description anywhere Neovim exposes: `desc` is a
--- user-command field only. So the short list a day of editing reaches is
--- described here. The two split entries read from this config rather than
--- stock Vim, since 'splitbelow' and 'splitright' are set.
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

--- Every command, with a description where one exists.
---
--- Not mini.extra's commands picker: it lists bare names, and with 600-odd
--- commands that only helps when I already know what a thing is called.
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
        -- Run it outright only when it takes no arguments; anything else goes
        -- onto the command line unexecuted, to be completed and read first.
        local keys = (":%s%s"):format(item.name, item.nargs == "0" and "\r" or " ")
        vim.schedule(function()
          vim.fn.feedkeys(keys)
        end)
      end,
    },
  })
end

return M
