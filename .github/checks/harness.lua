-- What the checks under .github/scripts share on the editor's side: picking
-- cases by name, reading what went wrong, and the row each case prints.

local H = {}

--- A new set of cases, reachable from the shell as the global `M`.
function H.new()
  local M = { cases = {} }

  --- The indexes of the cases whose name matches the Lua `pattern`, every
  --- case when it is empty.
  function M.matching(pattern)
    local found = {}

    for i, c in ipairs(M.cases) do
      if pattern == "" or c.name:find(pattern) then
        found[#found + 1] = i
      end
    end

    return found
  end

  _G.M = M
  return M
end

--- The fields of `want` that `got` disagrees with, one line each, sorted.
function H.differences(got, want)
  local wrong = {}

  for what, value in pairs(want) do
    if not vim.deep_equal(got[what], value) then
      wrong[#wrong + 1] = ("%s: expected %s, got %s"):format(what, vim.inspect(value), vim.inspect(got[what]))
    end
  end

  table.sort(wrong)
  return wrong
end

--- What the message history says went wrong since it was last cleared: an
--- error number and its line, a traceback, or nil.
---
--- E1568 is left out: it is the pty not answering what its background colour
--- is, which is the terminal and not the config.
function H.raised()
  local said = vim.fn.execute("messages"):gsub("E1568:[^\n]*", "")

  return said:match("E%d+:[^\n]*") or (said:find("stack traceback", 1, true) and "a traceback") or nil
end

--- The row a case prints: ok, or FAIL and every line in `wrong`.
function H.verdict(name, wrong)
  if #wrong == 0 then
    return ("  ok    %s"):format(name)
  end

  return ("  FAIL  %s\n        %s"):format(name, table.concat(wrong, "\n        "))
end

return H
