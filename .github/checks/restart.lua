local H = dofile(debug.getinfo(1, "S").source:match("^@(.*/)") .. "harness.lua")

local M = H.new()

-- The two files the script made. The anchor is what the editor is started
-- on; the witness is only ever opened by hand, so it is back after a restart
-- because a session put it back.
local ANCHOR = vim.env.MIVN_ANCHOR
local WITNESS = vim.env.MIVN_WITNESS

--- A case: what is pressed, whether there is unsaved work when it is, and
--- what has to be true once the dust settles. `restarted` is whether the pid
--- changed, `session` whether the second file came back, `terminal` whether
--- the panel did, and `refusal` the error a reader should have been given, or
--- false for a case that is not refused.
local function case(name, keys, dirty, expect)
  M.cases[#M.cases + 1] = { name = name, keys = keys, dirty = dirty, expect = expect }
end

--- The three spellings, with nothing to save ---------------------------------
--
-- :restart and ZR are the same key: both carry the session and put the panels
-- back. A counted ZR is Vim's own meaning, a restart without a session, so
-- neither the witness nor the terminal is expected back.

case(":restart carries the session", { ":restart<CR>" }, false, {
  restarted = true,
  session = true,
  terminal = true,
  refusal = false,
})
case("ZR carries the session", { "ZR" }, false, {
  restarted = true,
  session = true,
  terminal = true,
  refusal = false,
})
case("a counted ZR leaves the session behind", { "1ZR" }, false, {
  restarted = true,
  session = false,
  terminal = false,
  refusal = false,
})

--- The same three, with unsaved work ----------------------------------------
--
-- :restart quits, and quitting refuses while a buffer has unsaved work. What
-- matters is that the refusal reads as an error and not as a traceback
-- through this module, and that the panels are where they were left, since
-- the session spellings step them out of the way before they ask.

case(":restart refuses on unsaved work", { ":restart<CR>" }, true, {
  restarted = false,
  session = true,
  terminal = true,
  refusal = "E37",
})
case("ZR refuses on unsaved work", { "ZR" }, true, {
  restarted = false,
  session = true,
  terminal = true,
  refusal = "E37",
})
case("a counted ZR refuses on unsaved work", { "1ZR" }, true, {
  restarted = false,
  session = true,
  terminal = true,
  refusal = "E37",
})

--- The driver's half ---------------------------------------------------------

--- Windows holding a terminal, and whether the witness file is on screen.
local function screen()
  local terminals, witness = 0, false

  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)

    if vim.bo[buf].buftype == "terminal" then
      terminals = terminals + 1
    end
    if vim.api.nvim_buf_get_name(buf) == WITNESS then
      witness = true
    end
  end

  return terminals, witness
end

--- Put the editor back the way every case starts, and answer with the pid it
--- is about to be restarted from.
---
--- WARN: the tree is left alone. It opens on its own at startup, so it comes
--- back either way and says nothing about the session; the terminal does not,
--- which is why it is the panel this reads.
function M.setup(i)
  vim.api.nvim_feedkeys(vim.keycode("<Esc><C-\\><C-n>"), "nx", false)
  vim.cmd("stopinsert")

  local terminal = require("mivn.terminal")
  if terminal.is_open() then
    terminal.toggle()
  end

  vim.cmd("silent! only")
  vim.cmd("edit! " .. vim.fn.fnameescape(ANCHOR))
  vim.bo.swapfile = false

  vim.cmd("split " .. vim.fn.fnameescape(WITNESS))
  vim.bo.swapfile = false
  vim.cmd("wincmd b")

  terminal.toggle()
  vim.api.nvim_feedkeys(vim.keycode("<C-\\><C-n>"), "nx", false)
  vim.cmd("wincmd t")

  if M.cases[i].dirty then
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { "unsaved" })
  end

  vim.cmd("messages clear")

  return vim.fn.getpid()
end

function M.press(i, j)
  vim.api.nvim_input(M.cases[i].keys[j])
end

function M.keys(i)
  return #M.cases[i].keys
end

--- What the editor looks like now, against what the case asked for. `was` is
--- the pid M.setup answered with, which bash carries across the restart
--- because nothing in this state survives one.
function M.verdict(i, was)
  local c = M.cases[i]
  local terminals, witness = screen()

  -- E1568 is the terminal declining to say what its background colour is,
  -- which is the pty and not this config.
  local said = vim.fn.execute("messages"):gsub("E1568:[^\n]*", "")

  local got = {
    restarted = vim.fn.getpid() ~= was,
    session = witness,
    terminal = terminals == 1,
    refusal = said:match("E%d+") or false,
    traceback = said:find("stack traceback", 1, true) ~= nil,
  }

  local wrong = H.differences(got, vim.tbl_extend("error", { traceback = false }, c.expect))

  -- Two terminals is a panel that was put back on top of one that never left,
  -- which the count above reads as a plain miss.
  if terminals > 1 then
    wrong[#wrong + 1] = ("terminal: %d of them, so one was opened over another"):format(terminals)
  end

  return H.verdict(c.name, wrong)
end
