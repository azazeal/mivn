-- The status line: one across the whole editor rather than one per window
-- ('laststatus' is 3), so it pairs with the tab bar at the top.
--
-- It carries the mode, because 'showmode' is off, which makes the mode block
-- the most important thing on the line and why it gets the accent color. The
-- block is the color first and a letter second: the hue says the mode from
-- across the room, the letter confirms it up close, and one letter keeps the
-- block the same width in every mode, so nothing beside it ever shifts.

local statusline = require("mini.statusline")

--- Git ------------------------------------------------------------------------
--
-- mini.statusline's own section_git reads a summary that mini.git or gitsigns
-- publishes, and neither is installed, so this collects it instead.
--
-- One `git status` gives the branch and the dirty flag together, run through
-- vim.system so a slow repository never blocks a redraw. The line itself only
-- reads the string this leaves behind: it is evaluated many times a second and
-- must not do work.

local git = { branch = nil, dirty = false }

local refresh_timer, refreshing = nil, false

local function parse(out)
  local branch, dirty = nil, false

  for line in out:gmatch("[^\n]+") do
    local head = line:match("^# branch%.head (.+)$")
    if head then
      -- Detached HEAD reports the literal "(detached)", left as it comes.
      branch = head
    elseif not line:match("^#") then
      dirty = true
      -- The header lines come first, so with the branch already read there is
      -- nothing left to learn from the rest of the output.
      if branch then
        break
      end
    end
  end

  return branch, dirty
end

local function refresh()
  if refreshing then
    return
  end

  local dir = vim.fn.getcwd()
  refreshing = true

  vim.system(
    { "git", "status", "--porcelain=v2", "--branch" },
    { cwd = dir, text = true },
    vim.schedule_wrap(function(res)
      refreshing = false

      if res.code ~= 0 then
        git.branch, git.dirty = nil, false
      else
        git.branch, git.dirty = parse(res.stdout or "")
      end

      vim.cmd.redrawstatus()
    end)
  )
end

--- Coalesce a burst of events into one call. BufEnter alone fires several times
--- for a single `:bd`, and each one would otherwise be a subprocess.
local function schedule_refresh()
  if refresh_timer then
    refresh_timer:stop()
  end

  refresh_timer = vim.defer_fn(refresh, 150)
end

local function section_git()
  if not git.branch then
    return ""
  end
  -- The dot is the whole dirty indicator; a count of changed files would be
  -- another subprocess for what the gutter already says. No leading space:
  -- the group padding supplies it.
  return git.branch .. (git.dirty and " ●" or "")
end

--- Sections -------------------------------------------------------------------

--- The mode, one letter and its highlight.
---
--- The line-wise and block-wise variants collapse into V and S: the selection
--- itself already draws that difference on screen, so the block would only
--- repeat it. Visual and Select stay apart, because nothing else on screen
--- tells them apart and they differ in the one thing worth knowing: in Visual
--- the letters I type are commands, in Select they replace the selection.
--- mini.statusline hands both the Visual highlight, so Select carries its own.
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
  -- mode() answers with the state first ("no", "niI", "Rv"), so the first
  -- byte picks the letter; "no" is the exception, since its first byte reads
  -- as Normal while an operator is waiting.
  local mode = vim.fn.mode()
  local entry = vim.startswith(mode, "no") and MODE_FALLBACK or modes[mode:sub(1, 1)] or MODE_FALLBACK

  return entry[1], entry[2]
end

--- The macro recording indicator: `q` starts one silently, and 'showmode'
--- being off took away the "recording @w" that said so.
local function section_recording()
  local rec = vim.fn.reg_recording()

  return rec ~= "" and ("rec @" .. rec) or ""
end

--- Is this a buffer holding a file, rather than a panel?
---
--- The file tree, the landing buffer, help and quickfix all have a 'buftype'
--- and none of them has a path worth showing. Unchecked, the banner gets a
--- `[Scratch][-]` and a column number.
local function is_file()
  return vim.bo.buftype == ""
end

--- The file, as a path relative to the project.
---
--- mini.statusline's own section_filename shows the absolute path, which is a
--- wide column of shared prefix. `%f` is the path as opened, relative to the
--- working directory, and the launcher makes that the project root. `%m` is
--- the modified flag, `%r` the read-only one; a terminal gets its name.
local function section_filename()
  if vim.bo.buftype == "terminal" then
    return "%t"
  end

  return "%f%m%r"
end

--- The project: the parent directory and the directory, joined.
---
--- Shown in place of the file name when there is no file, so the line still
--- says where I am while I am on the banner or in the tree.
local function section_project()
  local cwd = vim.fn.getcwd()
  local parent = vim.fs.basename(vim.fs.dirname(cwd))

  if parent == "" or parent == "/" then
    return vim.fs.basename(cwd)
  end

  return parent .. "/" .. vim.fs.basename(cwd)
end

--- The filetype, with the glyph the rest of the editor draws for it.
---
--- mini.statusline's own section_fileinfo builds the same pair and then adds
--- the encoding, the line ending and the file size, all three near-constant
--- here, so they are three columns of noise beside the one that matters.
---
--- The glyph alone was tried and taken out: at this size a logo that has to
--- be decoded is worse than a word. Beside the word it costs nothing and is
--- read by shape, which is the same reason the tree and the pickers draw it.
--- It is the same glyph in all three.
---
--- What made the difference is colour, and it took a while to see. The glyph
--- looked washed out here while the same one read fine in the tree, and the
--- tree was drawing it in its own colour while this was not. At one cell,
--- colour carries as much as shape does. Every other lead was measured and
--- came to nothing: the icon sets all live in the same font at the same
--- codepoints, so no family changes the drawing, and Material is the only
--- set with per-language icons worth having.
---
--- Required inside rather than at the top: this runs on redraw, long after
--- lua/mivn/find.lua has set the plugin up, and requiring it at load would
--- put the order of two unrelated modules in the way of drawing at all.
local function section_filetype(trunc_width)
  local filetype = vim.bo.filetype
  if statusline.is_truncated(trunc_width) or filetype == "" then
    return ""
  end

  local ok, icons = pcall(require, "mini.icons")
  if not ok then
    return filetype
  end

  local glyph, glyph_hl, default = icons.get("filetype", filetype)

  -- A filetype mini.icons has no glyph for gets a generic file, which says
  -- nothing the word beside it does not, so those go without.
  if default then
    return filetype
  end

  -- Coloured, in the icon's own group, and back to the section's for the
  -- word. Uncoloured was tried first and is what made the glyph look washed
  -- out here while the same one reads fine in the tree: the tree draws it in
  -- its colour, and colour is doing as much of the work as shape at this
  -- size. The icon groups set a foreground and no background, so the block
  -- this section is drawn as keeps its own.
  return ("%%#%s#%s%%#MiniStatuslineFileinfo# %s"):format(glyph_hl, glyph, filetype)
end

--- The search count, labelled: "F: 3/20" while a search is live.
---
--- mini.statusline's own section gives the bare "3/20", empty once
--- `:nohlsearch` runs, which Esc does (lua/mivn/keymaps.lua), so the block comes
--- and goes with the search itself. The command line used to carry this
--- count; 'shortmess' "S" (init.lua) turned that copy off in favor of this
--- one. One honest limit: while a search is still being typed, searchcount()
--- counts the *previous* pattern, so the number here is one search behind
--- until Enter.
local function section_search(trunc_width)
  local count = statusline.section_searchcount({ trunc_width = trunc_width })

  return count ~= "" and "F: " .. count or ""
end

--- Where the cursor is: row and column, and nothing else.
---
--- mini.statusline's own section_location reads `28|515 12|12`: four numbers
--- for a question that has two.
---
--- The column counts characters of text, not `%v`'s screen cells: a tab is
--- one, an inlay hint is nothing, a Greek letter counts like a Latin one. It
--- is the number `{count}|` takes (lua/mivn/margins.lua) and, on an all-ASCII
--- line, the col a compiler prints, so the number read here can be typed
--- right back.
---
--- The dash in `%-2{}` pads the column to two cells. Without it, crossing
--- column 9 widens this block and shifts the whole right-hand group sideways
--- while I am moving along a line. The row only gains a digit when the file
--- does.
local LOCATION = "%l:%-2{charcol('.')}"

statusline.setup({
  use_icons = true,

  content = {
    active = function()
      local mode, mode_hl = section_mode()

      -- On a panel: the mode, the branch, and where the project is.
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
        -- `%S` is where 'showcmd' prints the command in progress, which
        -- init.lua points here with 'showcmdloc'. First slot after `%=` on
        -- purpose: while a count or an operator is pending the group grows
        -- leftward into the empty middle, so nothing beside it ever moves.
        { hl = "MiniStatuslineFileinfo", strings = { "%S", section_search(75), section_filetype(120) } },
        { hl = mode_hl, strings = { LOCATION } },
      })
    end,
  },
})

local group = vim.api.nvim_create_augroup("mivn.statusline", { clear = true })

-- BufWritePost because the format-on-save pass is what most often makes a
-- clean tree dirty; FocusGained because a commit usually happens in the
-- terminal beside this window, not in it.
vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost", "FocusGained", "DirChanged" }, {
  group = group,
  callback = schedule_refresh,
})

refresh()
