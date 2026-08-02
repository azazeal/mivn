-- The resolved personal overrides, and the only module that reads local.lua.
--
-- local.lua's top-level keys are global. Its optional `projects` key scopes
-- any of the same keys to a directory: when Neovim starts inside one, that
-- directory's values merge over the globals, and when several match, the
-- longest (most specific) directory wins. Resolved once, against the startup
-- working directory: one Neovim is one project.
--
-- Merging goes exactly two levels: a top-level key (lsp,
-- treesitter_grammars) merges per entry, and an entry replaces its
-- predecessor whole. No deep merge on purpose: a deep merge can only add,
-- so a more specific scope could never say "exactly this and nothing else"
-- for a server. What a project states is what applies.
--
-- Deliberately no per-project files of its own: 'exrc' is on (init.lua), so
-- a project that wants to carry editor config does it the standard way, in a
-- .nvim.lua that runs after this config and tweaks Neovim directly
-- (vim.lsp.config merges over the defaults here, for instance). This file's
-- keys are the personal, machine-side knobs, and they stay in local.lua.
local ok, raw = pcall(require, "mivn.local")
if not ok then
  raw = {}
end

local resolved = vim.deepcopy(raw)
resolved.projects = nil

--- Merge `values` over `resolved`, per the two-level rule above.
local function merge(values)
  for key, value in pairs(values) do
    if type(value) == "table" and type(resolved[key]) == "table" then
      for name, entry in pairs(value) do
        resolved[key][name] = vim.deepcopy(entry)
      end
    else
      resolved[key] = vim.deepcopy(value)
    end
  end
end

-- Shortest first, so later (longer, more specific) merges win.
local scoped = {}
for dir, values in pairs(raw.projects or {}) do
  scoped[#scoped + 1] = { dir = vim.fs.normalize(dir), values = values }
end
table.sort(scoped, function(a, b)
  return #a.dir < #b.dir
end)

local cwd = vim.fs.normalize(vim.fn.getcwd())
for _, entry in ipairs(scoped) do
  -- relpath, not a prefix compare: it knows ~/x does not contain ~/x-fork.
  if vim.fs.relpath(entry.dir, cwd) then
    merge(entry.values)
  end
end

return resolved
