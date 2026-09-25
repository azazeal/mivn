-- The landing buffer: a banner, a tagline and a byline, centered in an empty
-- window. It shows when mivn opens with nothing to edit; this module only
-- draws it, and when it comes back later is lua/mivn/session.lua's call.

local M = {}

local FILETYPE = "mivn-dashboard"
M.FILETYPE = FILETYPE -- how other modules tell the banner apart
local ns = vim.api.nvim_create_namespace("mivn.dashboard")

require("mivn.panel").hide_cursor_in(FILETYPE)

-- mivn in ANSI-shadow block letters.
local art = {
  "███╗   ███╗██╗██╗   ██╗███╗   ██╗",
  "████╗ ████║██║██║   ██║████╗  ██║",
  "██╔████╔██║██║██║   ██║██╔██╗ ██║",
  "██║╚██╔╝██║██║╚██╗ ██╔╝██║╚██╗██║",
  "██║ ╚═╝ ██║██║ ╚████╔╝ ██║ ╚████║",
  "╚═╝     ╚═╝╚═╝  ╚═══╝  ╚═╝  ╚═══╝",
}

local tagline = "modal · tree-sitter · lsp · my leader maze"
local byline_prefix = "by "
local byline_name = "@azazeal"

-- Keys to press anywhere, not rows to select.
local hints = {
  "<Space>f find file   <Space>: commands   :Tutor",
  "hold any key for a moment to see what can follow it",
}

--- Left-pad `text` so it sits centered across `width` columns.
local function center(text, width)
  local pad = math.max(0, math.floor((width - vim.fn.strdisplaywidth(text)) / 2))
  return string.rep(" ", pad) .. text
end

--- The lines for a `width` by `height` window, and the highlights to lay over
--- them: one group per highlighted row, over the whole line, and on the
--- byline the spans of the version and the name.
local function build(width, height)
  local lines, marks = {}, {}

  -- one pad for the whole block, since centering each row shears the letters
  local art_width = 0
  for _, row in ipairs(art) do
    art_width = math.max(art_width, vim.fn.strdisplaywidth(row))
  end
  local art_pad = string.rep(" ", math.max(0, math.floor((width - art_width) / 2)))

  local body = {}
  for i, row in ipairs(art) do
    body[#body + 1] = { text = art_pad .. row, hl = "MivnDashboardFire" .. i }
  end
  body[#body + 1] = { text = "" }
  body[#body + 1] = { text = center(tagline, width), hl = "MivnDashboardTagline" }
  body[#body + 1] = { text = "" }

  -- the release goes in front, since render() finds the name at the row's end
  local running = require("mivn.update").running()
  local byline = byline_prefix .. byline_name
  if running then
    byline = running .. " " .. byline
  end

  local centered = center(byline, width)
  local row = { text = centered, hl = "MivnDashboardByline", name = true }

  if running then
    -- center() pads only the left, so the difference is where the text starts
    local at = #centered - #byline
    row.version = { from = at, to = at + #running }

    -- the count past the release gets its own color, the + in front does not
    local plus = running:find("+", 1, true)
    if plus then
      row.ahead = { from = at + plus, to = at + #running }
    end
  end

  body[#body + 1] = row

  body[#body + 1] = { text = "" }

  for _, hint in ipairs(hints) do
    body[#body + 1] = { text = center(hint, width), hl = "MivnDashboardTagline" }
  end

  local update = require("mivn.update").status()
  if update then
    body[#body + 1] = { text = "" }
    body[#body + 1] = {
      text = center(("%s is out; :MivnUpdate takes it"):format(update.latest), width),
      hl = "MivnDashboardUpdate",
    }
  end

  local top = math.max(0, math.floor((height - #body) / 2))
  for _ = 1, top do
    lines[#lines + 1] = ""
  end

  for _, entry in ipairs(body) do
    lines[#lines + 1] = entry.text
    if entry.hl then
      marks[#marks + 1] = {
        row = #lines - 1,
        hl = entry.hl,
        name = entry.name,
        version = entry.version,
        ahead = entry.ahead,
      }
    end
  end

  return lines, marks
end

--- Render (or re-render) the banner into `buf`, sized to `win`.
function M.render(buf, win)
  if not (vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_win_is_valid(win)) then
    return
  end

  local lines, marks = build(vim.api.nvim_win_get_width(win), vim.api.nvim_win_get_height(win))

  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false

  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  for _, mark in ipairs(marks) do
    local line = lines[mark.row + 1]
    vim.api.nvim_buf_set_extmark(buf, ns, mark.row, 0, {
      end_col = #line,
      hl_group = mark.hl,
    })

    if mark.version then
      vim.api.nvim_buf_set_extmark(buf, ns, mark.row, mark.version.from, {
        end_col = mark.version.to,
        hl_group = "MivnDashboardVersion",
      })
    end

    if mark.ahead then
      vim.api.nvim_buf_set_extmark(buf, ns, mark.row, mark.ahead.from, {
        end_col = mark.ahead.to,
        hl_group = "MivnDashboardVersionAhead",
      })
    end

    if mark.name then
      local start = #line - #byline_name
      vim.api.nvim_buf_set_extmark(buf, ns, mark.row, start, {
        end_col = #line,
        hl_group = "MivnDashboardName",
      })
    end
  end
end

--- The Normal-mode keys that change text, each of which would raise E21 on
--- this 'nomodifiable' buffer. Motions are left alone. Taking `d` and `c`
--- hides which-key's panel for them here, which is fine with nothing to act on.
---
--- `<Insert>` is also taken in Visual, where it opens Insert too. The letters
--- are not: there `i`, `a` and `o` only pick out or move, and change nothing.
local EDIT_KEYS = { "<Insert>" }

for key in ("iIaAoOxXpPrRsScCdD"):gmatch(".") do
  EDIT_KEYS[#EDIT_KEYS + 1] = key
end

local function nothing_to_edit()
  vim.notify("Nothing to edit here. <Space>f opens a file.")
end

--- Whether the banner has claimed this session: it opened at startup, or
--- :MivnDashboard opened it. A session it never claimed (`git commit`,
--- `nvim file.txt`) ends when its last file closes instead of coming back here.
local claimed = false

function M.claimed()
  return claimed
end

--- Show the landing buffer in the current window.
function M.open()
  claimed = true

  local buf = vim.api.nvim_create_buf(false, true)

  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].buflisted = false
  vim.bo[buf].filetype = FILETYPE
  vim.bo[buf].undolevels = -1

  for _, key in ipairs(EDIT_KEYS) do
    vim.keymap.set("n", key, nothing_to_edit, {
      buffer = buf,
      desc = "Nothing to edit on the landing buffer",
    })
  end

  vim.keymap.set("x", "<Insert>", nothing_to_edit, {
    buffer = buf,
    desc = "Nothing to edit on the landing buffer",
  })

  vim.api.nvim_win_set_buf(0, buf)

  -- NOTE: `vim.wo[win][0]` and not `vim.wo[win]`. The second index scopes these
  -- to this buffer's stay in this window; a plain window-local set outlives
  -- the buffer, so every file opened here afterwards would have no line
  -- numbers and no sign column.
  local win = vim.api.nvim_get_current_win()
  vim.wo[win][0].number = false
  vim.wo[win][0].relativenumber = false
  vim.wo[win][0].cursorline = false
  vim.wo[win][0].signcolumn = "no"
  vim.wo[win][0].colorcolumn = ""
  vim.wo[win][0].list = false
  vim.wo[win][0].wrap = false
  vim.wo[win][0].fillchars = "eob: "

  -- blanks go, or the startup [No Name] sits in the tab bar opening nothing
  require("mivn.session").reap_blanks("delete", buf)

  M.render(buf, win)

  -- NOTE: the render waits for the next tick because WinNew fires before the
  -- new window's width is settled, so a render at the event centers the banner
  -- for the layout that is going away.
  local function redraw()
    if not vim.api.nvim_buf_is_valid(buf) then
      return true -- the banner is gone, so the autocmd goes too
    end

    vim.schedule(function()
      if not vim.api.nvim_buf_is_valid(buf) then
        return
      end

      local shown_in = vim.fn.bufwinid(buf)
      if shown_in ~= -1 then
        M.render(buf, shown_in)
      end
    end)
  end

  local group = vim.api.nvim_create_augroup("mivn.dashboard.render", { clear = true })

  vim.api.nvim_create_autocmd({ "VimResized", "WinResized", "WinNew", "WinClosed" }, {
    group = group,
    callback = redraw,
  })

  -- the update check answers seconds after the banner is drawn
  vim.api.nvim_create_autocmd("User", {
    group = group,
    pattern = "MivnUpdate",
    callback = redraw,
  })

  return buf
end

-- At startup, when there is nothing to edit. `mivn <dir>` counts: the banner
-- shows instead of the directory's file listing.
vim.api.nvim_create_autocmd("VimEnter", {
  group = vim.api.nvim_create_augroup("mivn.dashboard", { clear = true }),
  -- NOTE: nested, because M.open swaps the window's buffer and without it the
  -- swap fires no BufWinEnter, so whatever reacts to a buffer entering a
  -- window never sees the banner arrive.
  nested = true,
  callback = function()
    if not require("mivn.session").empty_start() then
      return
    end
    -- something else already claimed the window (a session, a piped stdin)
    if vim.api.nvim_buf_get_name(0) ~= "" and vim.fn.argc() == 0 then
      return
    end

    -- replace a directory's listing buffer, or closing the banner lands in it
    local startup = vim.api.nvim_get_current_buf()
    M.open()
    if vim.api.nvim_buf_is_valid(startup) and startup ~= vim.api.nvim_get_current_buf() then
      pcall(vim.api.nvim_buf_delete, startup, { force = true })
    end
  end,
})

vim.api.nvim_create_user_command("MivnDashboard", M.open, {
  desc = "Open the mivn landing buffer",
})

return M
