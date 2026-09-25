local H = dofile(debug.getinfo(1, "S").source:match("^@(.*/)") .. "harness.lua")

local M = H.new()
M.seen = {}

--- Enough buffers for the tabs alone to be wider than the screen.
local function fill()
  for i = 1, 14 do
    local buf = vim.api.nvim_create_buf(true, false)

    vim.api.nvim_buf_set_name(buf, ("%s/file_number_%02d.txt"):format(vim.fn.getcwd(), i))
  end
end

--- The column the buffers start at, read off the tree itself rather than
--- taken from the config, so a resized tree is still measured right.
local function tree_columns()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "NvimTree" then
      return vim.api.nvim_win_get_width(win) + 1
    end
  end

  return 0
end

--- The tab bar as Neovim would draw it: the text, its width, and where each
--- highlight begins.
local function drawn()
  return vim.api.nvim_eval_statusline(require("mivn.tabline").render(), {
    use_tabline = true,
    maxwidth = vim.o.columns,
    highlights = true,
  })
end

--- Whatever the nameplate is showing, without the padding around it.
local function nameplate()
  return vim.trim(drawn().str:sub(1, tree_columns()))
end

--- What has to hold of the strip whenever the tree is beside the buffers:
--- the project's name at the left end, and the buffers starting on the far
--- side of the tree however many of them there are.
local function strip()
  local wrong = {}
  local out = drawn()

  if out.width > vim.o.columns then
    wrong[#wrong + 1] = ("width: %d columns of screen, %d drawn"):format(vim.o.columns, out.width)
  end

  local first = out.highlights[1]
  if not first or first.group ~= "MivnTablineProject" or first.start ~= 0 then
    wrong[#wrong + 1] = ("starts with: expected MivnTablineProject at 0, got %s at %s"):format(
      first and first.group or "nothing",
      first and first.start or "nowhere"
    )
  end

  local tabs
  for _, hl in ipairs(out.highlights) do
    if hl.group:find("^MiniTabline") then
      tabs = hl.start
      break
    end
  end

  if tabs ~= tree_columns() then
    wrong[#wrong + 1] = ("tabs start at: expected %d, got %s"):format(tree_columns(), vim.inspect(tabs))
  end

  return wrong
end

--- A case: what is on screen before anything is pressed, where it is
--- clicked, and what has to hold once it settles.
---
--- `tree` opens the file tree, `buffers` puts more of them in the bar than it
--- has room for. `clicks` are screen columns, one call each, and a negative
--- one is counted from where the buffers start. `check` returns everything
--- that came out wrong, as lines, and an empty list is a pass.
local function case(c)
  M.cases[#M.cases + 1] = c
end

case({
  name = "nameplate",
  tree = true,
  check = function()
    local wrong = strip()

    if nameplate() ~= "mivn" then
      wrong[#wrong + 1] = ("name: expected mivn, got %s"):format(nameplate())
    end

    return wrong
  end,
})

case({
  name = "overflow",
  tree = true,
  buffers = true,
  check = strip,
})

case({
  name = "clicks",
  tree = true,
  buffers = true,
  clicks = { 2, -8 },
  check = function()
    local wrong = {}

    if M.seen[1] ~= M.seen[0] then
      wrong[#wrong + 1] = "a click over the tree switched buffers"
    end

    if M.seen[2] == M.seen[0] then
      wrong[#wrong + 1] = "a click on a tab did nothing"
    end

    return wrong
  end,
})

case({
  name = "hidden",
  buffers = true,
  check = function()
    local wrong = {}

    for _, hl in ipairs(drawn().highlights) do
      if hl.group:find("^MivnTabline") then
        wrong[#wrong + 1] = ("%s is drawn with no tree beside the buffers"):format(hl.group)
      end
    end

    return wrong
  end,
})

case({
  name = "agree",
  tree = true,
  check = function()
    local wrong = {}
    local name = nameplate()
    local title = require("mivn.title").render()
    local status = vim.api.nvim_eval_statusline(vim.o.statusline, {}).str

    if title ~= name then
      wrong[#wrong + 1] = ("title: expected %s, got %s"):format(name, title)
    end

    if not status:find(name, 1, true) then
      wrong[#wrong + 1] = ("status line: expected %s somewhere in [%s]"):format(name, vim.trim(status))
    end

    return wrong
  end,
})

case({
  name = "rule",
  tree = true,
  check = function()
    local wrong = {}

    for _, pair in ipairs({ { vim.env.HOME, "~" }, { "/", "/" } }) do
      vim.fn.chdir(pair[1])

      if nameplate() ~= pair[2] then
        wrong[#wrong + 1] = ("%s: expected %s, got %s"):format(pair[1], pair[2], nameplate())
      end
    end

    return wrong
  end,
})

--- Puts the case's starting state on screen. Returns nothing the shell
--- reads; what goes wrong in here comes back through the verdict.
function M.setup(i)
  local c = M.cases[i]

  vim.cmd("messages clear")

  local ok, err = pcall(function()
    if c.buffers then
      fill()
    end

    -- NOTE: opened or closed, never toggled. mivn opens the tree itself at
    -- startup, so a toggle would close it for a case that wants it open.
    local tree = require("nvim-tree.api").tree

    if c.tree then
      tree.open({ focus = false })
    else
      tree.close()
    end
  end)

  M.raised = not ok and tostring(err) or nil
  M.seen[0] = vim.api.nvim_get_current_buf()
end

--- How many clicks this case wants.
function M.clicks(i)
  return #(M.cases[i].clicks or {})
end

--- Presses click `n` of case `i`, and answers the column it pressed.
function M.click(i, n)
  local col = M.cases[i].clicks[n]

  if col < 0 then
    col = tree_columns() - col
  end

  vim.api.nvim_input_mouse("left", "press", "", 0, 0, col)
  vim.api.nvim_input_mouse("left", "release", "", 0, 0, col)

  return col
end

--- What the editor was left in after click `n`, read on the call after it so
--- the click has been through the loop by now.
function M.landed(n)
  M.seen[n] = vim.api.nvim_get_current_buf()

  return M.seen[n]
end

function M.verdict(i)
  local c = M.cases[i]

  local ok, wrong = pcall(c.check)
  if not ok then
    wrong = { "raised: " .. tostring(wrong) }
  end

  local raised = M.raised or H.raised()
  if raised then
    wrong[#wrong + 1] = "raised: " .. raised
  end

  return H.verdict(c.name, wrong)
end
