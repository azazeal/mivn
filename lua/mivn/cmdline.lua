-- The command line: a completion menu that opens as I type, and the typed
-- commands mivn answers itself instead of letting them run as written.

--- Completion as I type ------------------------------------------------------
--
-- `wildtrigger()` opens the menu, and 'wildmode' says what each Tab does after
-- that. `noselect` has to come first: with `longest` there, the trigger would
-- insert the common prefix of the matches while I was still typing. `:` only,
-- since over a search the menu would cover the match 'incsearch' is showing.
vim.opt.wildoptions = "pum"
vim.opt.wildmode = "noselect:lastused,longest:full,full"

local group = vim.api.nvim_create_augroup("mivn.cmdline", { clear = true })

vim.api.nvim_create_autocmd("CmdlineChanged", {
  group = group,
  pattern = ":",
  desc = "Open the completion menu as the command line is typed",
  callback = function()
    vim.fn.wildtrigger()
  end,
})

--- Rewriting what was typed --------------------------------------------------
--
-- A user command cannot shadow a built-in, and Vim has no event that can veto
-- one, so a built-in that needs answering differently is changed on the
-- command line the moment before it runs. Only a typed line gets here: a
-- mapping's <Cmd> and nvim_cmd() go straight through.
--
-- NOTE: not a cnoreabbrev, the usual tool for this. Its bang trigger is flaky:
-- `:bd!` right after an expanded `:bd` went through unexpanded.

local M = {}

local rewrites = {}

--- Have `fn` see every typed Ex command line before it runs. It returns the
--- line to run instead, or nil to leave it alone; the first answer wins.
function M.rewrite(fn)
  rewrites[#rewrites + 1] = fn
end

--- Whether `word` is a spelling of the command `full`: a prefix of it, at
--- least `shortest` letters long.
function M.spells(word, full, shortest)
  return word ~= nil and #word >= shortest and full:find(word, 1, true) == 1
end

vim.api.nvim_create_autocmd("CmdlineLeavePre", {
  group = group,
  desc = "Rewrite the typed commands mivn answers itself",
  callback = function()
    if vim.fn.getcmdtype() ~= ":" then
      return
    end

    local line = vim.fn.getcmdline()

    for _, fn in ipairs(rewrites) do
      local instead = fn(line)

      if instead then
        -- NOTE: setcmdline() answers 0, which Lua reads as true, and a
        -- callback that returns true deletes its own autocmd. Returning its
        -- result here would make the first rewrite the last.
        vim.fn.setcmdline(instead)
        return
      end
    end
  end,
})

return M
