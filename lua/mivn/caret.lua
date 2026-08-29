-- Who owns 'guicursor'.
--
-- The option is global and names a highlight group per mode, and two places
-- here want to override it for a while: lua/mivn/panel.lua hides the caret in
-- the tree and the banner, and lua/mivn/select.lua paints it Select's orange
-- for as long as Select lasts.
--
-- WARN: both used to do that the obvious way, appending an `a:` entry and
-- putting back the string they found, and it leaks the moment the two
-- overlap. One of them reads a value that already carries the other's entry
-- and writes it back after the other has gone, and the entry is then stuck for
-- the rest of the session. Measured on four running editors: none, one, two
-- and three entries piled on the end. The one with three drew every mode in
-- Select's orange, which reads as "the caret has no mode colour" rather than
-- as a bug, because the mode it is right for is the one you notice.
--
-- So nobody saves a string. This holds the option as init.lua left it and
-- rebuilds it from that plus whatever is on, which cannot drift however the
-- two interleave.

local M = {}

--- 'guicursor' as init.lua left it. Read at load, which is after init.lua has
--- set it and before any module has asked for an override.
local BASE = vim.o.guicursor

--- The overrides, in the order they are appended. A later `a:` entry beats an
--- earlier one, so the last one on is the one that draws.
---
--- The panel comes after Select on purpose: hiding the caret is a fact about
--- the window, and picking something out in there should not put it back.
local ORDER = { "select", "panel" }

--- Which overrides are on, by name, each holding the group it draws with.
local on = {}

local function apply()
  local parts = { BASE }

  for _, name in ipairs(ORDER) do
    local group = on[name]

    if group then
      parts[#parts + 1] = ("a:%s/%s"):format(group, group)
    end
  end

  vim.o.guicursor = table.concat(parts, ",")
end

--- Draw every mode's caret with `group` until `name` is dropped.
---
--- The override is named rather than the caller, so one can go off without the
--- other having to know, and saying the same thing twice costs nothing.
function M.override(name, group)
  if on[name] == group then
    return
  end

  on[name] = group
  apply()
end

--- Take `name`'s override off, if it is on.
function M.drop(name)
  if on[name] == nil then
    return
  end

  on[name] = nil
  apply()
end

return M
