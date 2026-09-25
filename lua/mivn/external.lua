-- Files Neovim has no way to display: PDFs, images, audio, video, fonts.
-- Opening one offers to hand it to the system's opener (vim.ui.open, the same
-- call `gx` makes) instead of filling a buffer with binary soup. The hook is
-- BufReadCmd, which fires in place of the read, so a yes never loads the file
-- at all, and a declined read is this module's to perform.
--
-- The zip family zipPlugin already browses is left to it, except docx, xlsx and
-- pptx, which read better in an office suite, and otf, which zipPlugin takes
-- for an OpenDocument template. This autocmd registers first, so it wins those.

local EXTENSIONS = {
  "avi",
  "avif",
  "bmp",
  "doc",
  "docx",
  "flac",
  "gif",
  "ico",
  "jpeg",
  "jpg",
  "m4a",
  "mkv",
  "mov",
  "mp3",
  "mp4",
  "ogg",
  "opus",
  "otf",
  "pdf",
  "png",
  "ppt",
  "pptx",
  "tif",
  "tiff",
  "ttf",
  "wav",
  "webm",
  "webp",
  "woff",
  "woff2",
  "xls",
  "xlsx",
}

local patterns = {}
for i, extension in ipairs(EXTENSIONS) do
  patterns[i] = "*." .. extension
end

--- Wipe the buffer the autocmd is editing, once the read event is over.
---
--- NOTE: not during the event. Deleting it out from under the edit crashes the
--- redraw; after it, the window has moved on to the next buffer.
local function drop(buf)
  vim.schedule(function()
    if vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_delete(buf, { force = true })
    end
  end)
end

vim.api.nvim_create_autocmd("BufReadCmd", {
  group = vim.api.nvim_create_augroup("mivn.external", { clear = true }),
  pattern = patterns,
  desc = "Offer non-text files to the system opener",
  callback = function(ev)
    local path = vim.api.nvim_buf_get_name(ev.buf)

    -- a new file: nothing to open or read, so the buffer stays empty
    if not vim.uv.fs_stat(path) then
      return
    end

    -- NOTE: only ask when someone is there to answer. With no UI attached,
    -- confirm() quietly returns its default button, and a headless script
    -- touching a PDF would pop a viewer onto the desktop. No UI reads as No,
    -- the raw view every other file gets.
    local choice = 2

    if #vim.api.nvim_list_uis() > 0 then
      local name = vim.fs.basename(path)
      local question = name .. " is not text. Open it with the system app?"

      choice = vim.fn.confirm(question, "&Yes\n&No\n&Cancel", 1)
    end

    if choice == 1 then
      local _, err = vim.ui.open(path)

      if not err then
        drop(ev.buf)
        return
      end

      -- no opener took it: the raw view beats an empty buffer over a real file
      vim.notify(err, vim.log.levels.ERROR)
    elseif choice ~= 2 and not vim.b[ev.buf].mivn_raw then
      -- NOTE: Cancel, or Escape (0), and the open never happened. The buffer
      -- goes with it, because an empty buffer named after a real file is that
      -- file truncated on the next `:w`. A cancelled reload of a raw view
      -- arrives here emptied, so it falls through, and the read below puts back
      -- what was on screen.
      drop(ev.buf)
      return
    end

    -- NOTE: declined, so do what the read would have done. The wipe comes
    -- first, because a reload (:e!) comes through here too and :read only
    -- appends. ++edit keeps the stock fileformat and encoding detection, the
    -- deleted line is the empty one a wiped buffer keeps, and BufReadPost hands
    -- the buffer to filetype detection and the rest. Modelines are skipped;
    -- binary soup gets no say.
    vim.cmd("silent keepalt %delete _")
    vim.cmd("silent keepalt read ++edit " .. vim.fn.fnameescape(path))
    vim.cmd("silent 1delete _")
    vim.bo[ev.buf].modified = false

    -- how a later cancel tells a reload from a first open
    vim.b[ev.buf].mivn_raw = true

    vim.api.nvim_exec_autocmds("BufReadPost", { pattern = path, modeline = false })
  end,
})
