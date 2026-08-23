-- Who wrote the line I am on, said once, in the status line.
--
-- The line I am on, and no other. This is Zed's shape: its `inline_blame`
-- annotates the cursor's line alone, and the view of a whole file at once is a
-- separate thing over in the gutter with avatars and short hashes, rather than
-- the same text repeated down the right-hand side. Annotating every line was
-- tried here first and it reads badly. The same name comes back every few
-- lines, a blank line belongs to whichever commit added the section above it
-- so the name lands out at column zero beside nothing, and a file with unsaved
-- work in it breaks into a fresh run after every line I have touched.
--
-- The status line rather than the end of the line, which is Zed's other
-- location for the same text and the one that suits this editor. It never sits
-- on top of code, never depends on how long a line is, and is always in the
-- same place, so the eye learns where to look once. What it gives up is
-- nearness to the line it describes, and that is a trade worth making when the
-- line in question is the one the cursor is already on.
--
-- lua/mivn/statusline.lua owns the slot and the color. This file only answers
-- the question, so that the line, which is rebuilt many times a second, does
-- nothing but read a string.
--
-- Lines with nothing committed behind them say nothing, and neither do blank
-- ones. The gutter already marks what I have changed and <leader>tr already
-- shows what it was, so a line I am in the middle of writing simply goes quiet.
--
-- What gets blamed is the buffer and not the file on disk, so an unsaved
-- change is part of the question rather than something the answer disagrees
-- with. git is asked once per buffer and the answer kept, since moving the
-- cursor must not spawn a subprocess; typing asks again once the text settles.

local M = {}

local GROUP = vim.api.nvim_create_augroup("mivn.blame", { clear = true })

--- The zero hash `git blame` gives a line that is not committed yet.
local UNCOMMITTED = "^0+$"

--- How long the text has to sit still before it is worth asking git again.
local SETTLE = 750

--- On or off, for the whole session. On is the resting state.
local enabled = false

--- The last answer per buffer: one entry per line, plus what the buffer looked
--- like when it was true, so a stale answer can be recognised as one.
local answers = {}

local MINUTE, HOUR, DAY = 60, 60 * 60, 24 * 60 * 60
local WEEK, MONTH, YEAR = 7 * DAY, 30 * DAY, 365 * DAY

local function plural(count, unit)
  return count .. " " .. unit .. (count == 1 and "" or "s") .. " ago"
end

--- How long ago `when` was, in the words a person would use. One unit and no
--- more, since the question is roughly when rather than how long.
local function ago(when)
  local since = os.time() - when

  if since < MINUTE then
    return "just now"
  elseif since < HOUR then
    return plural(math.floor(since / MINUTE), "minute")
  elseif since < DAY then
    return plural(math.floor(since / HOUR), "hour")
  elseif since < WEEK then
    return plural(math.floor(since / DAY), "day")
  elseif since < MONTH then
    return plural(math.floor(since / WEEK), "week")
  elseif since < YEAR then
    return plural(math.floor(since / MONTH), "month")
  end

  return plural(math.floor(since / YEAR), "year")
end

--- Who to name for a line: the part of the author's address before the `@`.
---
--- git has no username of its own, so this is the nearest thing it knows and
--- it is the handle the same person goes by everywhere else. It is also much
--- the shorter half, `panos` against `Panagiotis Siatras`, on a line that has
--- other things to say. The full name is what is left when an address is
--- missing, which happens on a commit made without one.
local function whom(name, mail)
  local address = mail and mail:match("^<(.*)>$") or mail
  local handle = address and address:match("^([^@]+)@")

  return handle or name
end

--- One entry per line of the file, in order, from `git blame --line-porcelain`.
---
--- The porcelain format is a header naming the commit, then its fields, then
--- the line's own text behind a tab. `--line-porcelain` repeats the fields for
--- every line rather than only the first time a commit is seen, which is more
--- output to read and no table to keep.
local function parse(stdout)
  local lines = {}
  local sha, name, mail, when

  for line in vim.gsplit(stdout, "\n", { plain = true }) do
    local hash = line:match("^(%x+) %d+ %d+")

    if hash then
      sha = hash
    elseif vim.startswith(line, "author ") then
      name = line:sub(#"author " + 1)
    elseif vim.startswith(line, "author-mail ") then
      mail = line:sub(#"author-mail " + 1)
    elseif vim.startswith(line, "author-time ") then
      when = tonumber(line:sub(#"author-time " + 1))
    elseif vim.startswith(line, "\t") then
      -- The text of the line closes its block, so everything needed is read.
      lines[#lines + 1] = { sha = sha, author = whom(name, mail), when = when }
    end
  end

  return lines
end

--- Whether this buffer is a file on disk that blaming could mean anything for.
local function blameable(buf)
  if not vim.api.nvim_buf_is_loaded(buf) or vim.bo[buf].buftype ~= "" then
    return false
  end

  local file = vim.api.nvim_buf_get_name(buf)
  return file ~= "" and vim.uv.fs_stat(file) ~= nil
end

--- Who wrote the line the cursor is on, as `panos · 3 months ago`, or the
--- empty string when there is nobody to name.
---
--- The answer is dropped rather than reported once the buffer has gained or
--- lost lines, because one blamed line is one buffer line only for as long as
--- that holds, and naming the wrong person is worse than naming nobody. Typing
--- puts a fresh answer back within SETTLE.
---
--- Cheap on purpose: the status line calls this on every redraw, so it is a
--- table lookup and a concatenation and never any work.
function M.line()
  if not enabled then
    return ""
  end

  local win = vim.api.nvim_get_current_win()
  local buf = vim.api.nvim_win_get_buf(win)

  local answer = answers[buf]
  if not answer or answer.count ~= vim.api.nvim_buf_line_count(buf) then
    return ""
  end

  local row = vim.api.nvim_win_get_cursor(win)[1]
  local line = answer.lines[row]

  if not line or not line.author or not line.when or line.sha:match(UNCOMMITTED) then
    return ""
  end

  local text = vim.api.nvim_buf_get_lines(buf, row - 1, row, false)[1] or ""
  if text:match("^%s*$") then
    return ""
  end

  return line.author .. " · " .. ago(line.when)
end

--- Ask git who wrote this buffer, and keep the answer.
---
--- Nothing waits for it. `git blame` on a long file in a big repository takes
--- real time, and an editor that stops while it thinks is worse than an answer
--- a moment late.
local function ask(buf)
  if not blameable(buf) then
    return
  end

  local file = vim.api.nvim_buf_get_name(buf)
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

  -- `--contents -` blames what I am looking at rather than what is on disk,
  -- which is what keeps the answer line for line with the buffer while it is
  -- dirty. The path still has to be named, since it is what git looks the
  -- history up by.
  vim.system({ "git", "blame", "--line-porcelain", "--contents", "-", "--", file }, {
    text = true,
    stdin = table.concat(lines, "\n") .. "\n",
    cwd = vim.fs.dirname(file),
    timeout = 10000,
    -- No index refresh, since this only reads, and no prompt if something
    -- upstream of me decides to ask for one.
    env = { GIT_OPTIONAL_LOCKS = "0", GIT_TERMINAL_PROMPT = "0" },
  }, function(out)
    if out.code ~= 0 then
      return
    end

    vim.schedule(function()
      -- The answer can outlive both the mode and the buffer that asked.
      if not enabled or not vim.api.nvim_buf_is_valid(buf) then
        return
      end

      answers[buf] = { lines = parse(out.stdout), count = #lines }

      -- The status line is not redrawn by anything this module does, so it
      -- has to be told the answer has landed. Guarded because redrawing is
      -- refused outright from inside the command-line window.
      pcall(vim.cmd.redrawstatus)
    end)
  end)
end

--- Ask again once the typing stops. Debounced through 'changedtick' rather
--- than a timer per buffer: every change schedules a look, and only the one
--- still matching the tick it was scheduled under does any work.
local function ask_when_settled(buf)
  local tick = vim.b[buf].changedtick

  vim.defer_fn(function()
    if enabled and vim.api.nvim_buf_is_valid(buf) and vim.b[buf].changedtick == tick then
      ask(buf)
    end
  end, SETTLE)
end

local function enable()
  enabled = true

  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    ask(buf)
  end

  -- A file opened while this is on arrives ready, and writing one asks again,
  -- so the answer follows a commit made from the terminal.
  vim.api.nvim_create_autocmd({ "BufReadPost", "BufWritePost" }, {
    group = GROUP,
    callback = function(event)
      ask(event.buf)
    end,
  })

  vim.api.nvim_create_autocmd({ "TextChanged", "InsertLeave" }, {
    group = GROUP,
    callback = function(event)
      ask_when_settled(event.buf)
    end,
  })

  vim.api.nvim_create_autocmd("BufWipeout", {
    group = GROUP,
    callback = function(event)
      answers[event.buf] = nil
    end,
  })
end

local function disable()
  enabled = false
  answers = {}

  vim.api.nvim_clear_autocmds({ group = GROUP })
  pcall(vim.cmd.redrawstatus)
end

--- Show who wrote the line under the cursor, or stop.
function M.toggle()
  if enabled then
    disable()
  else
    enable()
  end
end

-- On as soon as this module is loaded, which is while init.lua is still
-- running: the buffer sweep finds nothing to do that early and the autocmds
-- are what catch the file being opened. Both halves are needed anyway, since
-- the key can turn this off and on again at any point after.
enable()

return M
