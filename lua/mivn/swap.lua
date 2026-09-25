-- The prompt about a swap file nothing is using any more (E325).
--
-- The swap file stays, since it holds what a crash would take. But the E325 I
-- get is never about a crash: it is the editor I killed with nothing unsaved.
-- When the swap file says for itself that it holds no work and belongs to no
-- editor, the prompt is answered here with the "delete it" I would have typed,
-- and every other one still asks. A swap file whose Nvim still runs gives W325
-- in passing, not a prompt, so E325 is only ever the ownerless one.
--
-- The prompt is answered rather than the swap directory swept at startup: Vim
-- waits on the answer, so no second editor can be writing that swap file
-- meanwhile, and a file opened an hour in is covered too. Leftovers for files I
-- never open again stay on disk, harmless.

--- Does a process with this id still exist? Signal 0 asks without sending
--- anything, and EPERM, a process that belongs to somebody else, is a yes.
local function running(pid)
  local ok, _, name = vim.uv.kill(pid, 0)

  return ok ~= nil or name == "EPERM"
end

--- Is this swap file one nothing would miss?
---
--- NOTE: the whole safety of this rests on dirty and pid. A live editor writes
--- dirty 0 with a clean buffer and 1 with an unsaved change, so dirty 0 means
--- the buffer matched the file on disk and dropping it loses nothing. A live
--- editor also writes its own pid and a killed one leaves 0, so the pid test is
--- what keeps a running editor's swap file safe.
local function spent(info)
  -- one this Vim cannot read is somebody else's business
  if info.error then
    return false
  end

  -- unsaved work, the case the prompt exists for
  if info.dirty ~= 0 then
    return false
  end

  -- another machine's, so its pid means nothing here
  if info.host ~= vim.uv.os_gethostname() then
    return false
  end

  return not info.pid or info.pid == 0 or not running(info.pid)
end

vim.api.nvim_create_autocmd("SwapExists", {
  group = vim.api.nvim_create_augroup("mivn.swap", { clear = true }),
  desc = "Drop a swap file with no work and no editor behind it, without asking",
  callback = function()
    if spent(vim.fn.swapinfo(vim.v.swapname)) then
      -- "d" deletes it and opens the file; left empty, Vim asks
      vim.v.swapchoice = "d"
    end
  end,
})
