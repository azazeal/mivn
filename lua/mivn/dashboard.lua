-- The landing buffer.
--
-- A banner, a tagline and a byline, centered in an empty window. Hand-rolled
-- rather than a dashboard plugin: those are widget engines for
-- recents/projects/sessions lists, and none of that is wanted here.
--
-- A fallback, never a destination: it shows when mivn opens with nothing to
-- edit, and again when the last real buffer is closed. This module only
-- draws it; when it comes back and when closing the last file ends the
-- session instead is lua/mivn/session.lua's call.

local M = {}

local FILETYPE = "mivn-dashboard"
M.FILETYPE = FILETYPE -- session.lua tells the banner apart by it
local ns = vim.api.nvim_create_namespace("mivn.dashboard")

-- Nothing here to put a cursor on. The window still has one and the motions
-- still move it, it is simply not drawn; see lua/mivn/panel.lua, which owns
-- that because 'guicursor' is global.
require("mivn.panel").hide_cursor_in(FILETYPE)

-- mivn in ANSI-shadow block letters. Every row is the same display width, so
-- the block can be centered with one uniform pad and keep its columns aligned.
local art = {
  "███╗   ███╗██╗██╗   ██╗███╗   ██╗",
  "████╗ ████║██║██║   ██║████╗  ██║",
  "██╔████╔██║██║██║   ██║██╔██╗ ██║",
  "██║╚██╔╝██║██║╚██╗ ██╔╝██║╚██╗██║",
  "██║ ╚═╝ ██║██║ ╚████╔╝ ██║ ╚████║",
  "╚═╝     ╚═╝╚═╝  ╚═══╝  ╚═╝  ╚═══╝",
}

-- One MivnDashboardFire group per row, defined in colors/basalt.lua.

local tagline = "modal · tree-sitter · lsp · my leader maze"
local byline_prefix = "by "
local byline_name = "@azazeal"

-- Keys to press anywhere, not rows to select: the ways out of an empty editor,
-- plus the habit that makes the rest of the grammar answer for itself.
local hints = {
  "<Space>f find file   <Space>: commands   :Tutor",
  "hold any key for a moment to see what can follow it",
}

--- Left-pad `text` so it sits centered across `width` columns.
local function center(text, width)
  local pad = math.max(0, math.floor((width - vim.fn.strdisplaywidth(text)) / 2))
  return string.rep(" ", pad) .. text
end

--- Build the buffer's lines plus the highlights to lay over them.
---
--- Returns the lines and a list of {row, hl_group}. Highlights cover whole
--- lines, so there is no column arithmetic over the multi-byte block
--- characters, except on the byline where the name is colored separately.
local function build(width, height)
  local lines, marks = {}, {}

  -- One pad for the whole block: centering rows individually would shear the
  -- letters apart.
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

  -- The release rides in front of the byline rather than on a line of its own:
  -- it is what this copy is, said next to whose it is, and it costs no row.
  -- The name stays last on the row, which is what the highlight below counts
  -- backwards from. A checkout with no release to name drops it and the row
  -- reads as it always did.
  local running = require("mivn.update").running()
  local byline = byline_prefix .. byline_name
  if running then
    byline = running .. " " .. byline
  end

  local centered = center(byline, width)
  local row = { text = centered, hl = "MivnDashboardByline", name = true }

  if running then
    -- center() only ever pads the left, so the difference is exactly where the
    -- text starts, and the version starts with it.
    local at = #centered - #byline
    row.version = { from = at, to = at + #running }

    -- How far past the release this checkout is gets its own color, the count
    -- alone and not the + in front of it, which stays grey with the version it
    -- belongs to. Sitting on a release there is no suffix at all, so a suffix
    -- is the one thing on the row worth noticing, and it should not have to be
    -- read to be seen.
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

  -- The one line here that asks for anything, and only when there is
  -- something to ask for; lua/mivn/update.lua answers nil the rest of the
  -- time, which is nearly always.
  local update = require("mivn.update").status()
  if update then
    body[#body + 1] = { text = "" }
    body[#body + 1] = {
      text = center(("%s is out; :MivnUpdate takes it"):format(update.latest), width),
      hl = "MivnDashboardUpdate",
    }
  end

  -- Vertical centering: blank rows above the block so it sits in the middle.
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

    -- The release rides on the same row, at the front of it, with the distance
    -- past it laid over the top of that again.
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

    -- The name rides on the byline's row, highlighted over the top of it.
    if mark.name then
      local start = #line - #byline_name
      vim.api.nvim_buf_set_extmark(buf, ns, mark.row, start, {
        end_col = #line,
        hl_group = "MivnDashboardName",
      })
    end
  end
end

--- The Normal-mode keys that would otherwise fail on this buffer.
---
--- All of them want to change text and the buffer is 'nomodifiable', so each
--- would raise E21 on the first screen of the session. Motions are left alone:
--- they move an invisible cursor and nothing happens.
---
--- `d` and `c` are operator prefixes, so this shadows which-key's panel for
--- them in this one buffer. Accepted, since there is nothing to operate on.
---
--- `<Insert>` is spelled out because it is a name and not a character:
--- lua/mivn/keymaps.lua makes it the way in and out of typing, so it opens
--- Insert here exactly the way `i` does and failed exactly the way `i` would
--- have. It is also the one key taken in Visual, where it opens Insert as
--- well. The letters are not: there `i` and `a` pick out a text object and
--- `o` moves to the other end, and none of that touches the text.
local EDIT_KEYS = { "<Insert>" }

for key in ("iIaAoOxXpPrRsScCdD"):gmatch(".") do
  EDIT_KEYS[#EDIT_KEYS + 1] = key
end

local function nothing_to_edit()
  vim.notify("Nothing to edit here. <Space>f opens a file.")
end

--- Whether the banner has claimed this session: it opened at startup, or I
--- summoned it with :MivnDashboard. A session it never claimed is an editor
--- session (`git commit`, `nvim file.txt`), and those end when the last file
--- closes instead of falling back here; session.lua reads the flag and acts.
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

  -- `vim.wo[win][0]` and not `vim.wo[win]`: the second index scopes these to
  -- this buffer's stay in this window. A plain window-local set outlives the
  -- buffer, so every file opened here afterwards would inherit a window with
  -- no line numbers and no sign column.
  local win = vim.api.nvim_get_current_win()
  vim.wo[win][0].number = false
  vim.wo[win][0].relativenumber = false
  vim.wo[win][0].cursorline = false
  vim.wo[win][0].signcolumn = "no"
  vim.wo[win][0].colorcolumn = ""
  vim.wo[win][0].list = false
  vim.wo[win][0].wrap = false
  vim.wo[win][0].fillchars = "eob: "

  -- Any blank listed buffer nothing shows goes, usually the startup [No Name]
  -- one, which would otherwise sit in the tab bar as a tab that opens nothing.
  -- Deleting is safe here because this buffer exists, so Neovim has no reason
  -- to conjure a blank one in its place.
  require("mivn.session").reap_blanks("delete", buf)

  M.render(buf, win)

  -- Re-centered whenever the geometry changes, windows coming and going
  -- included: the tree opens beside this buffer a tick after startup, which
  -- used to leave the banner centered for the full editor width. Scheduled,
  -- because WinNew fires while the new window's columns are still being dealt.
  local function redraw()
    if not vim.api.nvim_buf_is_valid(buf) then
      return true -- the banner is gone, and the autocmd goes with it
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

  -- The update check answers a couple of seconds after startup, well after
  -- this buffer was drawn, so its line has to arrive on its own.
  vim.api.nvim_create_autocmd("User", {
    group = group,
    pattern = "MivnUpdate",
    callback = redraw,
  })

  return buf
end

-- At startup, when there is nothing to edit. `mivn <dir>` hands Neovim a
-- directory, which would otherwise open a file listing; the banner shows
-- instead. Coming back later, after the last file closes, is session.lua's
-- decision, not this module's.
vim.api.nvim_create_autocmd("VimEnter", {
  group = vim.api.nvim_create_augroup("mivn.dashboard", { clear = true }),
  -- nested, because M.open swaps the window's buffer, and without it that
  -- swap fires no BufWinEnter: whatever hooked the startup buffer (the width
  -- markers, window-local as matches are) would silently stay behind on the
  -- banner.
  nested = true,
  callback = function()
    if not require("mivn.session").empty_start() then
      return
    end
    -- Something else already claimed the window (a session, a piped stdin).
    if vim.api.nvim_buf_get_name(0) ~= "" and vim.fn.argc() == 0 then
      return
    end

    -- Opening a directory leaves Neovim holding a listing buffer for it. The
    -- landing buffer replaces that rather than sitting on top, since otherwise
    -- closing the banner drops me back into the listing.
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
