-- The prompt about a swap file nothing is using any more.
--
-- Vim writes a swap file beside every file I open and finds it again the next
-- time that file is opened. That is worth having: it holds the work a crash
-- would otherwise take. What it costs is E325, the prompt that stops
-- everything to ask what to do about it, and the one I actually get is never
-- about a crash. It is the editor I killed, whose buffer had nothing unsaved
-- in it, and answering it is busywork on the way into a file I asked for.
--
-- So when the swap file can say for itself that it holds no work and belongs
-- to no editor, the prompt is answered here with the same "delete it" I would
-- have typed. Every other one is left to ask.
--
-- Two things measured here rather than taken from the docs. What the header
-- says: a live editor with a clean buffer writes dirty 0 and its own pid, the
-- same editor with one unsaved change writes dirty 1, and killed with the
-- buffer clean what stays on disk is dirty 0 and pid 0. So dirty is the work,
-- the pid is the owner, and the file with neither is the leftover.
--
-- And which of the two messages this is about: a swap file whose Nvim is
-- still running is not a prompt at all, it is W325 in passing, and opening
-- goes ahead under the next swap name. E325 is only ever the ownerless one.
-- So this answers the case that blocks and leaves the case that informs.
--
-- Answering the prompt rather than sweeping the swap directory at startup is
-- deliberate, and not only because the scan costs something on every start.
-- Vim raises this the moment it finds the file and waits for the answer, so
-- there is no gap for a second editor to be writing that same swap file in,
-- which a scan reading headers behind Vim's back would have. It also covers
-- a file opened an hour into the session, which a scan at startup does not.
-- What it gives up is the leftovers for files I never open again: those stay
-- on disk, harmless, until something asks about them.

--- Does a process with this id still exist?
---
--- Signal 0 asks without sending anything. EPERM is a yes: the process is
--- there and belongs to somebody else, which on this machine should not
--- happen, but reads as "in use" either way.
local function running(pid)
  local ok, _, name = vim.uv.kill(pid, 0)

  return ok ~= nil or name == "EPERM"
end

--- Is this swap file one nothing would miss?
---
--- WARN: the whole safety of this rests on dirty. A swap file with dirty 0
--- describes a buffer that matched the file on disk, so dropping it loses
--- nothing that is not already saved. The pid test is the other half: it is
--- what leaves a running editor's swap file alone.
local function spent(info)
  -- A swap file this Vim cannot read. Somebody else's business.
  if info.error then
    return false
  end

  -- Unsaved work. This is the case the prompt exists for.
  if info.dirty ~= 0 then
    return false
  end

  -- Another machine's, so its pid means nothing here.
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
      -- "d" deletes it and opens the file. Left empty, Vim asks, which is
      -- what every other swap file still gets.
      vim.v.swapchoice = "d"
    end
  end,
})
