-- The resolved personal overrides, and the only module that reads local.lua.
--
-- local.lua's top-level keys are global. Its optional `projects` key scopes
-- any of the same keys to a directory: when Neovim starts inside one, that
-- directory's values merge over the globals, and when several match, the
-- longest (most specific) directory wins. Resolved once, against the startup
-- working directory: one Neovim is one project.
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
    resolved = vim.tbl_deep_extend("force", resolved, entry.values)
  end
end

return resolved
