-- Who owns 'guicursor'. The option is global, and two things override it for a
-- while: the panels hide the caret, and Select paints it orange.
--
-- NOTE: the option is built again from what init.lua set plus the overrides
-- that are on, never saved and put back. Save and restore leaks when two
-- overrides overlap: one saves a value that carries the other's entry and
-- writes it back after the other is gone, and the entry stays for the rest of
-- the session.

local M = {}

--- 'guicursor' as init.lua left it, read at load, before any override.
local BASE = vim.o.guicursor

--- The overrides in the order they are appended; a later `a:` entry wins. The
--- panel comes last, so picking something out in a panel keeps the caret
--- hidden.
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

--- Draw every mode's caret with `group` until `name` is dropped. Asking again
--- for the same thing costs nothing.
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
