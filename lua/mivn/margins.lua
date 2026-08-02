-- How long lines are shown: the width markers, and the wrap toggle.
--
-- The markers: prose wraps hard at 80, code carries a soft 100 and a hard
-- 120. Instead of colorcolumn's full stripe, the single character one column
-- past each limit is colored, escalating from green to red, so only a line
-- that crosses a limit shows anything.
--
-- `%v` is the virtual column, so a tab counts as its display width, which is
-- what a width limit means. Inlay hints are not buffer text and do not
-- count, so with hints on, the marked character sits further right on
-- screen than the column it marks.

local MARKS = {
  { column = 81, group = "MivnMargin80" },
  { column = 101, group = "MivnMargin100" },
  { column = 121, group = "MivnMargin120" },
}

--- Set or clear this window's marker matches to fit the buffer it now shows.
---
--- Matches are window state and windows outlive the buffers they show, so this
--- has to run whenever the pairing changes. Only ordinary file buffers get
--- markers; the tree, the terminal and the banner have no width budget.
local function refresh()
  for _, id in ipairs(vim.w.mivn_margin_ids or {}) do
    pcall(vim.fn.matchdelete, id)
  end
  vim.w.mivn_margin_ids = nil

  if vim.bo.buftype ~= "" then
    return
  end

  local ids = {}
  for _, mark in ipairs(MARKS) do
    ids[#ids + 1] = vim.fn.matchadd(mark.group, ("\\%%%dv."):format(mark.column))
  end
  vim.w.mivn_margin_ids = ids
end

vim.api.nvim_create_autocmd({ "BufWinEnter", "WinNew" }, {
  group = vim.api.nvim_create_augroup("mivn.margins", { clear = true }),
  desc = "Width markers at 80, 100 and 120",
  callback = refresh,
})

-- Long lines run off the right edge ('wrap' is off in init.lua); this brings
-- them back for the window I am in. Window-local, so a prose buffer can wrap
-- while the code beside it does not.
vim.keymap.set("n", "<leader>w", function()
  vim.wo.wrap = not vim.wo.wrap
end, { desc = "Wrap long lines in this window" })
