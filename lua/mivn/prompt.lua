-- Prompts: what vim.ui.input opens. Anything that asks for a line of text (LSP
-- rename, the tree's create, rename and yes/no prompts) opens a one-line float
-- instead of the bottom bar, where a question goes to be missed. A question
-- about the thing under the cursor (opts.scope == "cursor", which is what
-- vim.lsp.buf.rename sends) anchors at the cursor; everything else centers.
--
-- NOTE: the contract is kept to the letter. on_confirm gets the line as typed
-- on Enter and nil on cancel, exactly once, with the previous window current
-- again first. nvim-tree's delete prompt reads Enter on an empty line as "yes",
-- so an empty answer stays "" and a cancel stays nil, or Esc would delete
-- files. LSP rename applies its edits to the current window, so calling
-- on_confirm with the float still focused would aim them at a scratch buffer.

local M = {}

--- Charwise Select over `[from, to)`, so typing replaces the range and an arrow
--- drops out of it to edit. 'selection' is exclusive (init.lua), so the
--- endpoint is the character after the range, which 'virtualedit' makes
--- reachable past the end of the line.
local function select_range(win, from, to)
  vim.wo[win].virtualedit = "onemore"
  vim.api.nvim_win_set_cursor(win, { 1, from })
  vim.cmd("normal! v")
  vim.api.nvim_win_set_cursor(win, { 1, to })
  vim.cmd("normal! " .. vim.keycode("<C-g>"))
end

--- vim.ui.input, as a floating prompt.
---
--- Beyond the standard opts (prompt, default, completion), two of my own:
--- `scope = "cursor"` anchors the float at the cursor and, when a default is
--- present, preselects it whole so typing replaces it; `select = {from, to}`
--- narrows that preselection to a byte range of the default.
function M.input(opts, on_confirm)
  opts = opts or {}

  -- a picker's choose runs before its window closes, so wait for it to go
  local pick = package.loaded["mini.pick"]
  if pick and pick.is_picker_active() then
    vim.api.nvim_create_autocmd("User", {
      pattern = "MiniPickStop",
      once = true,
      callback = vim.schedule_wrap(function()
        M.input(opts, on_confirm)
      end),
    })
    return
  end

  local default = opts.default or ""
  local title = (" %s "):format((opts.prompt or "Input"):gsub("%s*:?%s*$", ""))
  local at_cursor = opts.scope == "cursor"

  local prev = vim.api.nvim_get_current_win()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "wipe"
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { default })

  -- no menu of buffer words over a file name, no auto-closed quotes
  vim.bo[buf].autocomplete = false
  vim.b[buf].minipairs_disable = true

  local width = math.min(math.max(#default + 8, vim.fn.strwidth(title) + 4, 30), math.floor(vim.o.columns * 0.7))
  local config = {
    relative = "editor",
    row = math.floor((vim.o.lines - 3) / 2),
    col = math.floor((vim.o.columns - width - 2) / 2),
    width = width,
    height = 1,
    style = "minimal",
    border = "rounded",
    title = title,
    title_pos = "center",
  }

  if at_cursor then
    -- below the cursor when three rows fit, above otherwise: only the TUI keeps
    -- a float on screen, and Neovide places it itself
    config.relative = "cursor"
    config.col = 0
    if vim.fn.winline() + 3 > vim.api.nvim_win_get_height(prev) then
      config.anchor = "SW"
      config.row = 0
    else
      config.row = 1
    end
  end

  local win = vim.api.nvim_open_win(buf, true, config)

  local done = false
  local function finish(value)
    if done then
      return
    end
    done = true

    vim.cmd.stopinsert()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
    if vim.api.nvim_win_is_valid(prev) then
      vim.api.nvim_set_current_win(prev)
    end

    on_confirm(value)
  end

  local function map(mode, lhs, rhs)
    vim.keymap.set(mode, lhs, rhs, { buffer = buf, nowait = true })
  end

  map({ "i", "n", "s" }, "<CR>", function()
    finish(vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] or "")
  end)
  map({ "n", "s" }, "<Esc>", function()
    finish(nil)
  end)
  map({ "i", "n", "s" }, "<C-c>", function()
    finish(nil)
  end)

  -- with the menu open, Esc only closes the menu and keeps the typed path
  map("i", "<Esc>", function()
    if vim.fn.pumvisible() == 1 then
      vim.api.nvim_feedkeys(vim.keycode("<C-e>"), "n", false)
      return
    end
    finish(nil)
  end)

  if opts.completion then
    -- the whole line is one path, so the menu replaces it from column one
    map("i", "<Tab>", function()
      local line = vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] or ""
      local ok, matches = pcall(vim.fn.getcompletion, line, opts.completion)
      if ok and #matches > 0 then
        vim.fn.complete(1, matches)
      end
    end)
  end

  -- a click elsewhere would strand the float with no keyboard way back
  vim.api.nvim_create_autocmd("WinLeave", {
    buffer = buf,
    once = true,
    callback = function()
      finish(nil)
    end,
  })

  local select = opts.select
  if not select and at_cursor and #default > 0 then
    select = { 0, #default }
  end

  if select then
    select_range(win, select[1], select[2])
  else
    vim.cmd("startinsert!")
  end
end

vim.ui.input = M.input

return M
