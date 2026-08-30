-- Files Neovim has no way to display: PDFs, images, audio, video, fonts.
-- Opening one offers to hand it to the system's opener (vim.ui.open, the
-- same call `gx` makes) instead of filling a buffer with binary soup. The
-- hook is BufReadCmd, which fires in place of the read, so a yes never
-- loads the file at all; the cost is that a declined read is this module's
-- to perform.
--
-- Most formats zipPlugin already browses (epub, jars and the rest of the
-- zip family) are left to it: those have a default, this covers the ones
-- with none. The deliberate overlaps, claimed here because this autocmd
-- registers first and wins the tie (verified): docx, xlsx and pptx, which
-- read better in an office suite than as a zip listing, and otf, which
-- zipPlugin takes for OpenDocument formula templates while every .otf
-- here is an OpenType font.

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
--- Deleting it out from under the edit crashes the redraw. After the event,
--- the window has moved on to whatever buffer is next in line.
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

    -- A name with no file behind it is a new file: nothing to open outside,
    -- nothing to read here. Leave the buffer empty, as a plain edit would.
    if not vim.uv.fs_stat(path) then
      return
    end

    -- Only ask when someone is there to answer: with no UI attached,
    -- confirm() quietly returns its default button, and a headless script
    -- touching a PDF would pop a viewer onto the desktop. Measured, not
    -- hypothetical. No UI reads as No, the raw view every other file gets.
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

      -- No opener took it; fall through to the raw view, which beats an
      -- empty buffer shadowing a real file.
      vim.notify(err, vim.log.levels.ERROR)
    elseif choice ~= 2 and not vim.b[ev.buf].mivn_raw then
      -- Cancel, which is also what Escape answers (0, no button at all):
      -- neither the app nor the raw view, so the open never happened. The
      -- buffer goes with it, because an empty buffer named after a real
      -- file is that file truncated on the next `:w`. Cancelling a reload
      -- of a raw view falls through instead: it arrives here emptied, and
      -- the read below puts back exactly what was on screen.
      drop(ev.buf)
      return
    end

    -- Declined: do what the read would have done. The wipe first, because a
    -- reload (:e!) comes through here too and the read only appends. ++edit
    -- keeps the stock fileformat and encoding detection, the deleted line is
    -- the empty one the wiped buffer keeps on top, and BufReadPost hands the
    -- buffer to filetype detection and everything else that expects a normal
    -- load. Modelines are skipped; binary soup gets no say.
    vim.cmd("silent keepalt %delete _")
    vim.cmd("silent keepalt read ++edit " .. vim.fn.fnameescape(path))
    vim.cmd("silent 1delete _")
    vim.bo[ev.buf].modified = false

    -- What a later cancel reads to tell a reload from a first open.
    vim.b[ev.buf].mivn_raw = true

    vim.api.nvim_exec_autocmds("BufReadPost", { pattern = path, modeline = false })
  end,
})
