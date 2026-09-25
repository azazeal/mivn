-- Who wrote the line I am on, said once, in the status line.
--
-- The cursor's line and no other, and in the status line rather than at the end
-- of the code line; DEFAULTS.md has the trade. This module only answers the
-- question, so the status line, rebuilt many times a second, does nothing but
-- read a string.
--
-- Lines with nothing committed behind them say nothing, and neither do blank
-- ones. What gets blamed is the buffer and not the file on disk, so an unsaved
-- change is part of the question rather than something the answer disagrees
-- with. git is asked once per buffer and the answer kept, since moving the
-- cursor must not spawn a subprocess; typing asks again once the text settles.

local M = {}

local GROUP = vim.api.nvim_create_augroup("mivn.blame", { clear = true })

--- The zero hash `git blame` gives a line that is not committed yet.
local UNCOMMITTED = "^0+$"

--- How long, in milliseconds, the text has to sit still before it is worth
--- asking git again.
local SETTLE = 750

--- On or off, for the whole session.
local enabled = false

--- The last answer per buffer: one entry per line, and the line count it was
--- true for, so a stale answer can be told apart.
local answers = {}

--- The buffers git has been asked about, so that coming back to one does not
--- ask again. Writing and typing still do.
local asked = {}

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

--- Who to name for a line: the part of the author's address before the `@`, or
--- the full name when the commit has no address.
local function whom(name, mail)
  local address = mail and mail:match("^<(.*)>$") or mail
  local handle = address and address:match("^([^@]+)@")

  return handle or name
end

--- One entry per line of the file, in order, from `git blame --porcelain`: the
--- commit that line came from, as `{ sha, author, when }`, shared by every line
--- of the same commit.
---
--- The porcelain format is a header naming the commit, the commit's fields the
--- first time it is seen, then the line's own text behind a tab.
local function parse(stdout)
  local commits, lines = {}, {}
  local commit

  for line in vim.gsplit(stdout, "\n", { plain = true }) do
    local sha = line:match("^(%x+) %d+ %d+")

    if sha then
      commit = commits[sha] or { sha = sha }
      commits[sha] = commit
    elseif vim.startswith(line, "\t") then
      lines[#lines + 1] = commit
    elseif vim.startswith(line, "author ") then
      commit.name = line:sub(#"author " + 1)
    elseif vim.startswith(line, "author-mail ") then
      commit.mail = line:sub(#"author-mail " + 1)
    elseif vim.startswith(line, "author-time ") then
      commit.when = tonumber(line:sub(#"author-time " + 1))
    end
  end

  for _, each in pairs(commits) do
    each.author = whom(each.name, each.mail)
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

--- Who wrote the line the cursor is on, as `panos · 3 months ago`, or the empty
--- string when there is nobody to name.
---
--- The answer is dropped once the buffer gains or loses lines, since naming the
--- wrong person is worse than naming nobody; typing brings a fresh one within
--- SETTLE.
---
--- NOTE: the status line calls this on every redraw, so it has to stay a lookup
--- and never ask git itself.
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

--- Ask git who wrote this buffer, in the background, and keep the answer.
local function ask(buf)
  if not blameable(buf) then
    return
  end

  local file = vim.api.nvim_buf_get_name(buf)
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

  asked[buf] = true

  -- `--contents -` blames the buffer as it is, not the file on disk
  vim.system({ "git", "blame", "--porcelain", "--contents", "-", "--", file }, {
    text = true,
    stdin = table.concat(lines, "\n") .. "\n",
    cwd = vim.fs.dirname(file),
    timeout = 10000,
    -- no index refresh, since this only reads, and never a prompt
    env = { GIT_OPTIONAL_LOCKS = "0", GIT_TERMINAL_PROMPT = "0" },
  }, function(out)
    if out.code ~= 0 then
      return
    end

    vim.schedule(function()
      -- the answer can outlive both the mode and the buffer that asked
      if not enabled or not vim.api.nvim_buf_is_valid(buf) then
        return
      end

      answers[buf] = { lines = parse(out.stdout), count = #lines }

      -- pcall, since the command-line window refuses a redraw
      pcall(vim.cmd.redrawstatus)
    end)
  end)
end

--- Ask again once the typing stops. Every change schedules a look, and only the
--- one whose 'changedtick' still matches does any work, so there is no timer to
--- keep per buffer.
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

  ask(vim.api.nvim_get_current_buf())

  -- only a buffer that comes on screen, so one loaded behind my back (a rename
  -- touching twenty files) costs nothing
  vim.api.nvim_create_autocmd("BufEnter", {
    group = GROUP,
    callback = function(event)
      if not asked[event.buf] then
        ask(event.buf)
      end
    end,
  })

  -- writing asks again, so the answer follows a commit made in the terminal
  vim.api.nvim_create_autocmd("BufWritePost", {
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
      asked[event.buf] = nil
    end,
  })
end

local function disable()
  enabled = false
  answers = {}
  asked = {}

  vim.api.nvim_clear_autocmds({ group = GROUP })
  pcall(vim.cmd.redrawstatus)
end

--- Whether the blame is on.
function M.on()
  return enabled
end

--- Turn the blame on or off, and say which: the line I am on may have nothing
--- to show either way.
function M.toggle()
  if enabled then
    disable()
  else
    enable()
  end

  vim.notify(("Blame: %s"):format(enabled and "on" or "off"))
end

-- On from the start. This runs while init.lua is still loading, before any file
-- is open, so the autocmds are what catch the first one.
enable()

return M
