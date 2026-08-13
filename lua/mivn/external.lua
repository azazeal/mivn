-- Files Neovim has no way to display: PDFs, images, audio, video, fonts.
-- Opening one offers to hand it to the system's opener (vim.ui.open, the
-- same call `gx` makes) instead of filling a buffer with binary soup. The
-- hook is BufReadCmd, which fires in place of the read, so a yes never
-- loads the file at all; the cost is that a declined read is this module's
-- to perform.
--
-- Formats zipPlugin already browses (docx, epub and the rest of the zip
-- family) are left to it: those have a default, this covers the ones with
-- none. otf is the one deliberate overlap: zipPlugin claims it for
-- OpenDocument formula templates, but every .otf here is an OpenType font,
-- and this autocmd registers first, so it wins the tie (verified).

local EXTENSIONS = {
  "pdf",
  "png",
  "jpg",
  "jpeg",
  "gif",
  "webp",
  "bmp",
  "ico",
  "tif",
  "tiff",
  "avif",
  "mp4",
  "mkv",
  "webm",
  "mov",
  "avi",
  "mp3",
  "flac",
  "wav",
  "ogg",
  "opus",
  "m4a",
  "ttf",
  "otf",
  "woff",
  "woff2",
  "doc",
  "xls",
  "ppt",
}

local patterns = {}
for i, extension in ipairs(EXTENSIONS) do
  patterns[i] = "*." .. extension
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
    -- hypothetical.
    local ask = #vim.api.nvim_list_uis() > 0

    local name = vim.fs.basename(path)

    if ask and vim.fn.confirm(name .. " is not text. Open it with the system app?", "&Yes\n&No", 1) == 1 then
      local _, err = vim.ui.open(path)

      if not err then
        -- This buffer is the one the autocmd is editing, and deleting it
        -- out from under the edit crashes the redraw. After the event, the
        -- window has moved on to whatever buffer is next in line.
        vim.schedule(function()
          if vim.api.nvim_buf_is_valid(ev.buf) then
            vim.api.nvim_buf_delete(ev.buf, { force = true })
          end
        end)

        return
      end

      -- No opener took it; fall through to the raw view, which beats an
      -- empty buffer shadowing a real file.
      vim.notify(err, vim.log.levels.ERROR)
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
    vim.api.nvim_exec_autocmds("BufReadPost", { pattern = path, modeline = false })
  end,
})
