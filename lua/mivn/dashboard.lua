-- The landing buffer.
--
-- A banner, a tagline and a byline, centered in an empty window. Hand-rolled
-- rather than a dashboard plugin: those are widget engines for
-- recents/projects/sessions lists, and none of that is wanted here.
--
-- A fallback, never a destination: it shows when mivn opens with nothing to
-- edit, and again when the last real buffer is closed.

local M = {}

local FILETYPE = "mivn-dashboard"
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

local tagline = "modal · tree-sitter · lsp · no leader maze"
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
  body[#body + 1] = {
    text = center(byline_prefix .. byline_name, width),
    hl = "MivnDashboardByline",
    name = true,
  }
  body[#body + 1] = { text = "" }

  for _, hint in ipairs(hints) do
    body[#body + 1] = { text = center(hint, width), hl = "MivnDashboardTagline" }
  end

  -- Vertical centering: blank rows above the block so it sits in the middle.
  local top = math.max(0, math.floor((height - #body) / 2))
  for _ = 1, top do
    lines[#lines + 1] = ""
  end

  for _, entry in ipairs(body) do
    lines[#lines + 1] = entry.text
    if entry.hl then
      marks[#marks + 1] = { row = #lines - 1, hl = entry.hl, name = entry.name }
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
local EDIT_KEYS = "iIaAoOxXpPrRsScCdD"

local function nothing_to_edit()
  vim.notify("Nothing to edit here. <Space>f opens a file.")
end

--- Show the landing buffer in the current window.
function M.open()
  local buf = vim.api.nvim_create_buf(false, true)

  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].buflisted = false
  vim.bo[buf].filetype = FILETYPE
  vim.bo[buf].undolevels = -1

  for key in EDIT_KEYS:gmatch(".") do
    vim.keymap.set("n", key, nothing_to_edit, {
      buffer = buf,
      desc = "Nothing to edit on the landing buffer",
    })
  end

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
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if
      b ~= buf
      and vim.api.nvim_buf_is_loaded(b)
      and vim.bo[b].buflisted
      and vim.bo[b].buftype == ""
      and not vim.bo[b].modified
      and vim.api.nvim_buf_get_name(b) == ""
      and vim.fn.bufwinid(b) == -1
    then
      pcall(vim.api.nvim_buf_delete, b, { force = true })
    end
  end

  M.render(buf, win)

  -- Re-centered whenever the geometry changes, windows coming and going
  -- included: the tree opens beside this buffer a tick after startup, which
  -- used to leave the banner centered for the full editor width. Scheduled,
  -- because WinNew fires while the new window's columns are still being dealt.
  vim.api.nvim_create_autocmd({ "VimResized", "WinResized", "WinNew", "WinClosed" }, {
    group = vim.api.nvim_create_augroup("mivn.dashboard.render", { clear = true }),
    callback = function()
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
    end,
  })

  return buf
end

--- Every buffer that counts as something I am actually editing.
---
--- Not keyed on 'buflisted': netrw flips that flag on its own buffer as it
--- redraws, so a rule trusting it reads state that moves underneath it. A real
--- buffer has an empty 'buftype' and either a file name or unsaved changes.
local function real_buffers()
  return vim.tbl_filter(function(buf)
    return vim.api.nvim_buf_is_loaded(buf)
      and vim.bo[buf].buftype == ""
      and vim.bo[buf].filetype ~= FILETYPE
      and (vim.api.nvim_buf_get_name(buf) ~= "" or vim.bo[buf].modified)
  end, vim.api.nvim_list_bufs())
end

--- Is this the blank buffer Neovim leaves behind when nothing is open?
local function is_blank(buf)
  if vim.bo[buf].buftype ~= "" or vim.bo[buf].modified then
    return false
  end
  if vim.api.nvim_buf_get_name(buf) ~= "" then
    return false
  end

  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  return #lines <= 1 and (lines[1] or "") == ""
end

local group = vim.api.nvim_create_augroup("mivn.dashboard", { clear = true })

-- At startup, when there is nothing to edit. `mivn <dir>` hands Neovim a
-- directory, which would otherwise open a file listing; the banner shows
-- instead.
vim.api.nvim_create_autocmd("VimEnter", {
  group = group,
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

-- And again on the blank buffer Neovim leaves behind, which is where `:bd` on
-- the last file puts me.
--
-- Keyed on arriving at a buffer rather than on one being deleted: the delete
-- events fire while the window is still on its way somewhere, so a deferred
-- check sees whatever Neovim fell back to mid-flight. BufEnter is settled.
vim.api.nvim_create_autocmd("BufEnter", {
  group = group,
  callback = function(ev)
    if vim.v.exiting ~= vim.NIL then
      return
    end
    -- Already here. Without this the landing buffer re-triggers itself.
    if vim.bo[ev.buf].filetype == FILETYPE then
      return
    end
    if not is_blank(ev.buf) or #real_buffers() > 0 then
      return
    end

    -- One at a time. `:bd` with the cursor in the tree deletes the tree's own
    -- buffer and leaves its window holding a blank one, which would otherwise
    -- open a second banner. Not also skipping when a tree window exists: the
    -- tree is open in the ordinary case too, and testing for it would stop the
    -- banner coming back after `:bd` on the last file.
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == FILETYPE then
        return
      end
    end

    vim.schedule(function()
      if vim.api.nvim_get_current_buf() == ev.buf and is_blank(ev.buf) then
        M.open()
      end
    end)
  end,
})

vim.api.nvim_create_user_command("MivnDashboard", M.open, {
  desc = "Open the mivn landing buffer",
})

return M
