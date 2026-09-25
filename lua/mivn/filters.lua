-- What the file lists show: dotfiles, and the files the SCM ignores. One answer
-- for the tree and for the finders, since a file drawn in one and missing from
-- the other is a worse lie than either rule on its own.
--
-- It starts with dotfiles shown, since they are configuration somebody wrote,
-- and ignored files hidden, since they are build output. `.git/` is out of both
-- and not a toggle: git does not ignore it, and there is nothing in it to read.

local M = {}

--- What is shown, not what is filtered. nvim-tree's own flags mean the
--- opposite, and lua/mivn/tree.lua inverts them where it hands them over.
local shown = {
  dotfiles = true,
  ignored = false,
}

--- Whether dotfiles are listed.
function M.dotfiles()
  return shown.dotfiles
end

--- Whether the files the SCM ignores are listed.
function M.ignored()
  return shown.ignored
end

--- ripgrep's side of it -------------------------------------------------------
--
-- mini.pick runs `rg` for the live grep with a command line of its own that
-- takes no arguments from here, so the only way in is ripgrep's own config
-- file, as mini.pick's documentation says. The file is written on every flip
-- and named in the environment, which the picker's `rg` inherits.
--
-- NOTE: it has to be this editor's own file, not one path under the cache. It
-- holds the state of one session, so a shared name would have two windows
-- overwriting each other's answer. tempname() is per process, and Neovim
-- removes the directory it sits in on the way out.

local RG = vim.fn.tempname()

--- Whatever ripgrep was configured with when this editor started, carried over,
--- since ripgrep reads one file and cannot include another.
local inherited = (function()
  local path = vim.env.RIPGREP_CONFIG_PATH
  if not path or path == "" or path == RG then
    return ""
  end

  local file = io.open(path, "r")
  if not file then
    return ""
  end

  local text = file:read("*a")
  file:close()

  return text
end)()

local function write_rg()
  local lines = { inherited }

  if shown.dotfiles then
    lines[#lines + 1] = "--hidden"
  end

  if shown.ignored then
    lines[#lines + 1] = "--no-ignore"
  end

  -- last, so it wins whatever the two above said
  lines[#lines + 1] = "--glob=!.git/"

  local file = io.open(RG, "w")
  if not file then
    vim.notify(("Could not write %s, so the finders keep ripgrep's own rules."):format(RG), vim.log.levels.WARN)
    return
  end

  file:write(table.concat(lines, "\n") .. "\n")
  file:close()

  vim.env.RIPGREP_CONFIG_PATH = RG
end

write_rg()

--- Flipping them --------------------------------------------------------------

--- Flip one, move the tree to match, and say what the lists show now. The tree
--- is toggled through its own api, which redraws it; it started from `shown`,
--- so the two only ever move together.
---
--- NOTE: `nvim-tree` is required here rather than at the top, so this module
--- stays loadable before the tree is set up.
local function flip(key, toggle, noun)
  shown[key] = not shown[key]
  write_rg()

  toggle(require("nvim-tree.api"))

  vim.notify(("%s: %s"):format(noun, shown[key] and "shown" or "hidden"))
end

--- Show or hide dotfiles, in the tree and in the finders.
function M.toggle_dotfiles()
  flip("dotfiles", function(api)
    api.filter.dotfiles.toggle()
  end, "Dotfiles")
end

--- Show or hide what the SCM ignores, in the tree and in the finders.
function M.toggle_ignored()
  flip("ignored", function(api)
    api.filter.git.ignored.toggle()
  end, "Ignored files")
end

return M
