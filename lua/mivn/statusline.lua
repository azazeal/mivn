-- The status line, one across the whole editor ('laststatus' is 3).
--
-- 'showmode' is off, so the mode block is where the mode is said: the colour
-- first and one letter second, which keeps the block the same width in every
-- mode.

local blame = require("mivn.blame")
local project = require("mivn.project")
local statusline = require("mini.statusline")

--- Git ------------------------------------------------------------------------
--
-- mini.statusline's own section_git needs mini.git or gitsigns, and neither is
-- installed. One `git status` in the background gives the branch and the
-- dirty flag, and the line only reads what it left behind, since it is drawn
-- many times a second.

local git = { branch = nil, dirty = false }

local refreshing, pending = false, false

local function parse(out)
  local branch, dirty = nil, false

  for line in out:gmatch("[^\n]+") do
    local head = line:match("^# branch%.head (.+)$")
    if head then
      -- a detached HEAD reads "(detached)", kept as it comes
      branch = head
    elseif not line:match("^#") then
      dirty = true
      -- the headers come first, so the rest has nothing more to tell
      if branch then
        break
      end
    end
  end

  return branch, dirty
end

local function refresh()
  -- one run at a time, but a request during a run is kept, or the dot goes
  -- stale
  if refreshing then
    pending = true
    return
  end

  local dir = vim.fn.getcwd()
  refreshing = true

  -- NOTE: GIT_OPTIONAL_LOCKS=0 keeps `git status` from taking the index lock
  -- to write a refreshed index back. This runs on every buffer switch and
  -- every return to the window, which is just when a commit in the terminal
  -- beside it wants that lock.
  vim.system(
    { "git", "status", "--porcelain=v2", "--branch" },
    { cwd = dir, text = true, env = { GIT_OPTIONAL_LOCKS = "0", GIT_TERMINAL_PROMPT = "0" } },
    vim.schedule_wrap(function(res)
      refreshing = false

      if res.code ~= 0 then
        git.branch, git.dirty = nil, false
      else
        git.branch, git.dirty = parse(res.stdout or "")
      end

      vim.cmd.redrawstatus()

      if pending then
        pending = false
        refresh()
      end
    end)
  )
end

local refresh_timer = assert(vim.uv.new_timer())

--- Runs refresh once per burst of events, since BufEnter alone fires several
--- times for one `:bd`. Starting the one timer again pushes its deadline back.
local function schedule_refresh()
  refresh_timer:start(150, 0, vim.schedule_wrap(refresh))
end

local function section_git()
  if not git.branch then
    return ""
  end
  -- no leading space: the group's padding gives it
  return git.branch .. (git.dirty and " ●" or "")
end

--- Sections -------------------------------------------------------------------

--- The letter and highlight for each mode. Line-wise and block-wise share V
--- and S, since the selection already shows its shape. Visual and Select stay
--- apart, since in Select what I type replaces the selection.
local modes = {
  n = { "N", "MiniStatuslineModeNormal" },
  i = { "I", "MiniStatuslineModeInsert" },

  v = { "V", "MiniStatuslineModeVisual" },
  V = { "V", "MiniStatuslineModeVisual" },
  ["\22"] = { "V", "MiniStatuslineModeVisual" }, -- CTRL-V, a raw byte

  s = { "S", "MiniStatuslineModeSelect" },
  S = { "S", "MiniStatuslineModeSelect" },
  ["\19"] = { "S", "MiniStatuslineModeSelect" }, -- CTRL-S, a raw byte

  R = { "R", "MiniStatuslineModeReplace" },
  c = { "C", "MiniStatuslineModeCommand" },

  t = { "T", "MiniStatuslineModeOther" }, -- terminal
  r = { "P", "MiniStatuslineModeOther" }, -- hit-enter and more prompts
  ["!"] = { "X", "MiniStatuslineModeOther" }, -- a shell command running
}

local MODE_FALLBACK = { "O", "MiniStatuslineModeOther" } -- operator-pending

local function section_mode()
  -- the first byte picks the letter, but "no" is Normal with an operator
  -- waiting
  local mode = vim.fn.mode()
  local entry = vim.startswith(mode, "no") and MODE_FALLBACK or modes[mode:sub(1, 1)] or MODE_FALLBACK

  return entry[1], entry[2]
end

--- "rec @w" while a macro records, since with 'showmode' off nothing else
--- says so.
local function section_recording()
  local rec = vim.fn.reg_recording()

  return rec ~= "" and ("rec @" .. rec) or ""
end

--- The 'buftype's that hold text I read: a file, a help page, a quickfix list.
--- The rest (the tree, the banner, the terminal) are panels, which get the
--- project's name instead of a file and a location.
local READABLE = { [""] = true, help = true, quickfix = true }

local function is_file()
  return READABLE[vim.bo.buftype] == true
end

--- The base names that more than one listed buffer is using, rebuilt when the
--- buffer list changes rather than on every redraw.
local shared = {}

local function count_shared()
  local seen = {}

  shared = {}

  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[buf].buflisted then
      local name = vim.fs.basename(vim.api.nvim_buf_get_name(buf))

      if name ~= "" then
        if seen[name] then
          shared[name] = true
        end

        seen[name] = true
      end
    end
  end
end

--- What the tab bar does not say about the buffer: its modified and readonly
--- flags, and its path when another open buffer has the same name.
local function section_filename()
  local buftype = vim.bo.buftype

  -- a help page or a quickfix list is not in the tab bar
  if buftype == "help" then
    return "help " .. vim.fn.expand("%:t:r")
  end

  if buftype == "quickfix" then
    local list = vim.fn.win_gettype() == "loclist" and vim.fn.getloclist(0, { title = 1 })
      or vim.fn.getqflist({ title = 1 })

    return list.title ~= "" and list.title or "%q"
  end

  if shared[vim.fs.basename(vim.api.nvim_buf_get_name(0))] then
    return "%f%m%r"
  end

  return "%m%r"
end

--- The project's name, for a panel, which has no file to name.
local function section_project()
  -- NOTE: mini.statusline puts what a section returns into the line itself,
  -- so a directory called `50%` would be read as an item.
  return (project.name():gsub("%%", "%%%%"))
end

--- The filetype, after its mini.icons glyph in the glyph's own colour.
local function section_filetype(trunc_width)
  local filetype = vim.bo.filetype
  if statusline.is_truncated(trunc_width) or filetype == "" then
    return ""
  end

  -- required on draw, long after lua/mivn/find.lua has set it up
  local ok, icons = pcall(require, "mini.icons")
  if not ok then
    return filetype
  end

  local glyph, glyph_hl, default = icons.get("filetype", filetype)

  -- a generic file glyph says nothing the word does not
  if default then
    return filetype
  end

  -- the icon groups set no background, so the glyph keeps the block's
  return ("%%#%s#%s%%#MiniStatuslineFileinfo# %s"):format(glyph_hl, glyph, filetype)
end

--- The search count as "F: 3/20", empty once the highlight is cleared. While
--- a search is still being typed it counts the previous pattern.
local function section_search(trunc_width)
  local count = statusline.section_searchcount({ trunc_width = trunc_width })

  return count ~= "" and "F: " .. count or ""
end

--- Row and column. The column counts characters, not screen cells, so it is
--- the number `{count}|` takes and can be typed right back.
---
--- NOTE: The dash in `%-2{}` pads the column to two cells. Without it, going
--- past column 9 widens the block and shifts everything left of it.
local LOCATION = "%l:%-2{charcol('.')}"

statusline.setup({
  use_icons = true,

  content = {
    active = function()
      local mode, mode_hl = section_mode()

      if not is_file() then
        return statusline.combine_groups({
          { hl = mode_hl, strings = { mode } },
          { hl = "MivnStatuslineGit", strings = { section_git() } },
          { hl = "MiniStatuslineDevinfo", strings = { section_recording() } },
          "%<",
          { hl = "MiniStatuslineFilename", strings = { section_project() } },
          "%=",
          { hl = "MiniStatuslineFileinfo", strings = { "%S" } },
        })
      end

      local diagnostics = statusline.section_diagnostics({ trunc_width = 75 })
      local lsp = statusline.section_lsp({ trunc_width = 75 })

      return statusline.combine_groups({
        { hl = mode_hl, strings = { mode } },
        { hl = "MivnStatuslineGit", strings = { section_git() } },
        { hl = "MiniStatuslineDevinfo", strings = { section_recording(), diagnostics, lsp } },
        "%<", -- where the line is cut first when the window is narrow
        { hl = "MiniStatuslineFilename", strings = { section_filename() } },
        "%=", -- everything after this is pushed to the right
        -- NOTE: The order is the point. This side is laid out right to left,
        -- so a piece that grows pushes only what is to its left. What comes
        -- and goes as I type (`%S`, where 'showcmd' prints, and the search
        -- count) goes first, and what I read at a glance goes last.
        { hl = "MiniStatuslineFileinfo", strings = { "%S", section_search(75) } },
        { hl = "MivnStatuslineBlame", strings = { blame.line() } },
        { hl = "MiniStatuslineFileinfo", strings = { section_filetype(120) } },
        { hl = mode_hl, strings = { LOCATION } },
      })
    end,
  },
})

local group = vim.api.nvim_create_augroup("mivn.statusline", { clear = true })

-- FocusGained because I usually commit in a terminal beside this window.
vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost", "FocusGained", "DirChanged" }, {
  group = group,
  callback = schedule_refresh,
})

-- The shared names change only when the buffer list does, or when a buffer is
-- renamed.
vim.api.nvim_create_autocmd({ "BufAdd", "BufDelete", "BufFilePost" }, {
  group = group,
  callback = vim.schedule_wrap(count_shared),
})

count_shared()

refresh()
