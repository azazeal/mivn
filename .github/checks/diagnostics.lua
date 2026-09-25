local H = dofile(debug.getinfo(1, "S").source:match("^@(.*/)") .. "harness.lua")

local M = H.new()

--- My own namespace, so no case waits on a language server. What a server
--- publishes goes through the same handler and the same `format`.
local NS = vim.api.nvim_create_namespace("mivn.check.diagnostics")

--- The rule the handler draws in front of every line of a message: the elbow
--- `└──── ` on the first, six spaces on the rest. Both are six cells, and
--- every character of them is one cell wide, so cutting six characters off a
--- row is cutting six columns off it.
local RULE = 6

local LINES = {
  "package main",
  "",
  "func main() { handle() }",
  "\tif err != nil { return err }",
}

--- A gopls type mismatch, near enough: 300-odd characters of ASCII with one
--- space between words, so the rows joined with a space are the message
--- again.
local LONG = "cannot use handler (variable of type func(w http.ResponseWriter, r *http.Request) error)"
  .. " as http.Handler value in argument to mux.Handle: func(w http.ResponseWriter, r *http.Request)"
  .. " error does not implement http.Handler (missing method ServeHTTP), and the same is true of"
  .. " every other route in this file"

--- Two bytes to the cell. A wrap counting bytes breaks this about a third too
--- early, and every row comes out short.
local GREEK = "δεν μπορώ να χρησιμοποιήσω αυτή τη μεταβλητή εδώ, γιατί ο τύπος της δεν ταιριάζει με"
  .. " αυτόν που περιμένει η συνάρτηση, και το ίδιο ισχύει για κάθε άλλη κλήση της μέσα σε αυτό"
  .. " το αρχείο, οπότε το μήνυμα βγαίνει αρκετά μεγάλο για να χρειαστεί σπάσιμο σε γραμμές"

--- Three bytes and two cells to the character. A wrap counting characters
--- runs this off the right edge; one counting bytes stops short of it.
local JAPANESE = "この 変数 は ここ では 使えません。 型 が 合っていない から です。 期待 されている 型 は"
  .. " http.Handler で、 渡された 型 は 関数 です。 同じ こと が この ファイル の 他 の すべて の"
  .. " 経路 に も 当てはまります。 もう 一度 確認 して ください。"

--- Short words, so the greedy wrap keeps landing right on the boundary
--- instead of near it.
local EDGE = "a bb ccc dddd eeeee ffffff ggggggg hhhhhhhh iiiiiiiii jjjjjjjjjj kkk ll m nn ooo pppp"
  .. " qqqqq rrrrrr sssssss tttttttt uuuuuuuuu vvvvvvvvvv ww x yy zzz aaaa bbbbb cccccc ddddddd"
  .. " eeeeeeee fffffffff gggggggggg hh iii jjjj kkkkk llllll mmmmmmm nnnnnnnn ooooooooo"

--- One token, wider than any window. It is meant to run off the edge: half a
--- path is worse than a whole one that overflows.
local TOKEN = "/home/azazeal/projects/azazeal/mivn/lua/mivn/languages/"
  .. "a_file_name_long_enough_that_nothing_should_ever_break_it_in_half.lua"

--- A rustc-shaped message that carries its own newlines, with a middle line
--- long enough to need wrapping of its own and a last line that is indented
--- on purpose.
local SNIPPET = table.concat({
  "mismatched types",
  "expected `Vec<String>`, found `Vec<&str>`, and the collect at the end of that chain is the"
    .. " call that decides it",
  "    let names: Vec<String> = words.iter().map(|w| w).collect();",
}, "\n")

--- Long enough to be cut at a third of any window this runs in.
local ENDLESS = ("this message goes on and on and has no intention of stopping any time soon. "):rep(40)

--- A case: how wide the window is, what is wrong with which line, and what
--- has to hold of what got drawn.
---
--- `fits` is on unless a case says otherwise, and is the screen check. `back`
--- is the message the rows have to rejoin to, `rows` how many of them there
--- should be, `greedy` that none of them could have taken the first word of
--- the row below it, and `ellipsis` that the last one says it was cut.
local function case(c)
  M.cases[#M.cases + 1] = c
end

case({
  name = "short",
  width = 80,
  diagnostics = { { message = "undefined: fmt" } },
  rows = 1,
  elbow = true,
  back = "undefined: fmt",
})

case({
  name = "long, 80 columns",
  width = 80,
  diagnostics = { { message = LONG } },
  elbow = true,
  back = LONG,
  greedy = true,
})

case({
  name = "long, 140 columns",
  width = 140,
  diagnostics = { { message = LONG } },
  elbow = true,
  back = LONG,
  greedy = true,
})

case({
  name = "edge",
  width = 80,
  diagnostics = { { message = EDGE } },
  back = EDGE,
  greedy = true,
})

case({
  name = "greek",
  width = 80,
  diagnostics = { { message = GREEK } },
  back = GREEK,
  greedy = true,
})

case({
  name = "japanese",
  width = 80,
  diagnostics = { { message = JAPANESE } },
  back = JAPANESE,
  greedy = true,
})

case({
  name = "newlines",
  width = 80,
  diagnostics = { { message = SNIPPET } },
  rows = 4,
  first = "mismatched types",
  last = "    let names: Vec<String> = words.iter().map(|w| w).collect();",
})

case({
  name = "one long token overflows",
  width = 80,
  diagnostics = { { message = TOKEN } },
  fits = false,
  rows = 1,
  back = TOKEN,
})

-- The tab is the point: what the handler indents by is cells and not bytes,
-- so a wrap that counted the byte would have four columns it does not own.
case({
  name = "indented, past a tab",
  width = 80,
  lnum = 3,
  col = 1,
  diagnostics = { { message = LONG, lnum = 3, col = 1 } },
  greedy = true,
})

-- Two on one line: the handler draws a `│` down the left of the second one
-- and the indent shifts, so the room left is not what either of them would
-- have had alone.
case({
  name = "two on one line",
  width = 80,
  diagnostics = {
    { message = LONG, col = 0 },
    { message = GREEK, col = 8 },
  },
  column = true,
})

case({
  name = "capped, with an ellipsis",
  width = 80,
  diagnostics = { { message = ENDLESS } },
  capped = true,
  ellipsis = true,
})

case({
  name = "resize, narrower",
  width = 140,
  resize = 80,
  diagnostics = { { message = LONG } },
  back = LONG,
  greedy = true,
})

case({
  name = "resize, wider",
  width = 80,
  resize = 140,
  diagnostics = { { message = LONG } },
  back = LONG,
  greedy = true,
})

--- What the window is, once the frame is up.
local function info()
  return vim.fn.getwininfo(vim.api.nvim_get_current_win())[1]
end

--- Every virtual line the handler drew, as the text of its row, in the order
--- it drew them.
local function drawn()
  local rows = {}
  local buf = vim.api.nvim_get_current_buf()

  for name, ns in pairs(vim.api.nvim_get_namespaces()) do
    if name:find("diagnostic.virtual_lines", 1, true) then
      for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, { details = true })) do
        for _, vline in ipairs(mark[4].virt_lines or {}) do
          local text = {}

          for _, chunk in ipairs(vline) do
            text[#text + 1] = chunk[1]
          end

          rows[#rows + 1] = table.concat(text)
        end
      end
    end
  end

  return rows
end

--- One row without the rule in front of it, which is what the message on it
--- was before the handler took it.
local function said(row, indent)
  return vim.fn.strcharpart(row, indent + RULE)
end

--- The line without the spaces at the end of it, which is where a screen row
--- and the row it was drawn from differ and should not.
local function bare(row)
  return (row:gsub("%s+$", ""))
end

--- What the handler was handed is what the editor drew, and none of it
--- reaches the window's last column.
---
--- NOTE: the first half has to be read off the screen with screenstring().
--- The extmark holds the whole row whether or not it fitted, and asking it
--- how wide the window was would ask the same arithmetic that put the breaks
--- in. The second half is not enough alone: a cut that lands on one of the
--- message's own spaces leaves the last column blank, and the row still lost
--- its tail.
local function fits(rows, lnum)
  local wrong = {}
  local win = info()

  vim.cmd("redraw")

  local width = win.width - win.textoff

  for i, row in ipairs(rows) do
    local cells = {}

    -- the cells between `textoff` and the right edge; a double-width
    -- character answers once and then with ""
    for col = win.wincol + win.textoff, win.wincol + win.width - 1 do
      cells[#cells + 1] = vim.fn.screenstring(win.winrow + lnum + i, col)
    end

    local screen = bare(table.concat(cells))

    if screen ~= bare(row) then
      wrong[#wrong + 1] = ("row %d was drawn as [%s]"):format(i, screen)
    end

    local drawn_width = vim.fn.strdisplaywidth(row)
    if drawn_width >= width then
      wrong[#wrong + 1] = ("row %d is %d cells of the %d there are"):format(i, drawn_width, width)
    end
  end

  return wrong
end

--- The wrap is as full as it could be: no row could have taken the first word
--- of the row below it without reaching the last column.
---
--- This is where a wrap measuring anything but cells fails, and it fails on
--- the Greek and Japanese lines only.
local function greedy(rows, width)
  local wrong = {}

  for i = 1, #rows - 1 do
    local next_word = rows[i + 1]:match("%S+") or ""
    local together = vim.fn.strdisplaywidth(rows[i]) + 1 + vim.fn.strdisplaywidth(next_word)

    if together < width then
      wrong[#wrong + 1] = ("row %d stopped %d cells short of the %d it had: [%s]"):format(
        i,
        width - together,
        width,
        rows[i]
      )
    end
  end

  return wrong
end

--- The rows put back together are the message that went in: the wrap took
--- nothing out and put nothing in.
local function rejoin(rows, indent, message)
  local parts = {}

  for _, row in ipairs(rows) do
    parts[#parts + 1] = said(row, indent)
  end

  local back = table.concat(parts, " ")
  if back == message then
    return {}
  end

  return { ("rejoined to [%s]"):format(back) }
end

--- Puts the fixture, the frame and the diagnostics on screen.
---
--- The window is sized by splitting rather than by resizing the terminal: a
--- lone window is as wide as the screen and stays that way, and what the wrap
--- reads is the window in any case.
function M.setup(i)
  local c = M.cases[i]

  vim.cmd("messages clear")
  vim.diagnostic.reset(NS, 0)
  vim.cmd("only")

  vim.api.nvim_buf_set_lines(0, 0, -1, false, LINES)

  if c.width < vim.o.columns - 1 then
    vim.cmd("botright vnew")
    vim.cmd("wincmd h")
    vim.api.nvim_win_set_width(0, c.width)
  end

  local diagnostics = {}
  for _, d in ipairs(c.diagnostics) do
    diagnostics[#diagnostics + 1] = {
      lnum = d.lnum or 0,
      col = d.col or 0,
      message = d.message,
      severity = vim.diagnostic.severity.ERROR,
    }
  end

  vim.api.nvim_win_set_cursor(0, { (c.lnum or 0) + 1, 0 })
  vim.diagnostic.set(NS, vim.api.nvim_get_current_buf(), diagnostics)
end

--- 1 when case `i` resizes the window after the diagnostics are drawn, else 0.
function M.resizes(i)
  return M.cases[i].resize and 1 or 0
end

function M.resize(i)
  vim.api.nvim_win_set_width(0, M.cases[i].resize)
end

function M.verdict(i)
  local c = M.cases[i]
  local win = info()
  local width = win.width - win.textoff
  local rows = drawn()
  local wrong = {}

  local function add(list)
    for _, line in ipairs(list) do
      wrong[#wrong + 1] = line
    end
  end

  local indent = vim.fn.strdisplaywidth(vim.fn.strcharpart(LINES[(c.lnum or 0) + 1], 0, c.col or 0))

  if #rows == 0 then
    wrong[#wrong + 1] = "nothing was drawn under the line"
  end

  if c.fits ~= false then
    add(fits(rows, c.lnum or 0))
  end

  if c.rows and #rows ~= c.rows then
    wrong[#wrong + 1] = ("rows: expected %d, got %d"):format(c.rows, #rows)
  end

  if c.elbow and rows[1] and not rows[1]:find("└────", 1, true) then
    wrong[#wrong + 1] = ("no elbow on the first row: [%s]"):format(rows[1])
  end

  if c.back then
    add(rejoin(rows, indent, c.back))
  end

  if c.greedy then
    add(greedy(rows, width))
  end

  if c.first and rows[1] and said(rows[1], indent) ~= c.first then
    wrong[#wrong + 1] = ("first row: expected [%s], got [%s]"):format(c.first, said(rows[1], indent))
  end

  if c.last and #rows > 0 and said(rows[#rows], indent) ~= c.last then
    wrong[#wrong + 1] = ("last row: expected [%s], got [%s]"):format(c.last, said(rows[#rows], indent))
  end

  if c.capped then
    local want = math.max(math.floor(win.height / 3), 3)

    if #rows ~= want then
      wrong[#wrong + 1] = ("capped at %d rows of a %d-row window, got %d"):format(want, win.height, #rows)
    end
  end

  if c.ellipsis and #rows > 0 and not vim.endswith(rows[#rows], "…") then
    wrong[#wrong + 1] = ("the last row does not say it was cut: [%s]"):format(rows[#rows])
  end

  if c.column then
    local found = false

    for _, row in ipairs(rows) do
      found = found or row:find("│", 1, true) ~= nil
    end

    if not found then
      wrong[#wrong + 1] = "no column joins the second diagnostic to its line"
    end
  end

  local raised = H.raised()
  if raised then
    wrong[#wrong + 1] = "raised: " .. raised
  end

  return H.verdict(c.name, wrong)
end
