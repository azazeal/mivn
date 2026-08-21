-- What the file lists show: dotfiles, and the files the SCM ignores.
--
-- One answer for the tree and for the finders. They are two views of the same
-- directory, and a file drawn in one and missing from the other is a worse
-- lie about the project than either rule is on its own.
--
-- Where it starts is what a checkout usually wants: dotfiles shown, since
-- they are configuration somebody wrote, and ignored files hidden, since they
-- are build output. `.git/` is out of both and is not a toggle. It is a
-- dotfile git does not ignore, and there is nothing in it to read.
--
-- <Space>th and <Space>ti flip them, in lua/mivn/keymaps.lua. The tree's own
-- `H` and `I` are bound to the same two functions, so a flip from inside it
-- moves the finders with it.

local M = {}

--- Shown, rather than filtered: the reading that needs no inversion in the
--- one place it is asked out loud. nvim-tree's own flags mean the opposite
--- and lua/mivn/tree.lua inverts them where it hands them over.
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
-- takes no arguments from here, so the only way to reach it is ripgrep's own
-- configuration file, which is what mini.pick's documentation says to use.
-- The file is written on every flip and pointed at through the environment,
-- which the picker's `rg` inherits along with everything else this editor
-- starts.
--
-- WARN: it has to be this editor's own file and not one path under the cache.
-- What it describes is the state of one session, so a shared name would have
-- two windows overwriting each other's answer, and a grep in one showing what
-- was toggled in the other. tempname() is per process, and Neovim removes the
-- directory it sits in on the way out, so nothing is left behind either.
--
-- The file finder does not need this, since that command is built here (see
-- lua/mivn/find.lua) and has to carry its flags anyway for `fd`, which has no
-- configuration file at all. Both end up saying the same thing.

local RG = vim.fn.tempname()

--- Whatever ripgrep was already configured with when this editor started.
--- ripgrep reads one file and has no way to include another, so carrying it
--- is the only way not to quietly drop it.
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

  -- Last, so it is the answer whatever the two above said.
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

--- Flip one, move the tree to match, and say what the lists show now.
---
--- The tree is toggled through its own API rather than reconfigured, which is
--- what redraws it; it starts from the same table below, so the two only ever
--- move together. `nvim-tree` is required here rather than at the top so this
--- module stays loadable before the tree is set up.
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
