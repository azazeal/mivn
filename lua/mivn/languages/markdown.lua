-- Markdown: marksman, for the cross-references between notes, and rumdl for
-- the tables.
--
-- rumdl is a linter that fixes rather than a formatter, and that is exactly
-- why it is here. `-e` turns on one rule and nothing else runs, so a file
-- with no table in it comes back byte for byte as it went in, and the prose
-- I wrapped by hand stays wrapped where I put it. Every real markdown
-- formatter owns the whole document instead: mdformat aligned the table and
-- also turned setext headings into ATX, `*` bullets into `-`, `1)` into
-- `1.`, four-space nesting into two, indented code into fenced, and
-- unescaped `\_`. Prettier does the same and brings node. Measured, both.
--
-- MD060 is off by default and its style defaults to keeping whatever padding
-- it finds, so both overrides are needed to get an aligned table at all.
--
-- max-width is the reason a wide table is left alone: aligning pads every row
-- out to the longest one, and this repo's tables reach 132 columns that way,
-- past the 120 nothing here may cross. Over the limit rumdl writes the table
-- compact instead, which is what it already looked like.
--
-- All of that is only what happens when nobody else has said anything. A
-- project carrying a rumdl config decides what saving a markdown file in it
-- does, the way it would for any other tool a team shares, and then none of
-- the settings above are passed and rumdl runs its own rules. Handing it the
-- wheel is a smaller thing than it sounds: on its defaults it left setext
-- headings, `*` bullets, `1)` numbering, indented code, backslash escapes
-- and a 150 column paragraph exactly as they were.
--
-- The config is found here rather than left to rumdl, which walks up from its
-- working directory. That is the directory the editor started in, not the
-- file's, so a markdown file from another checkout would be formatted by this
-- checkout's rules. Naming the file outright is what makes "the project" mean
-- the project the file is in.
--
-- WARN: honoring a config is running what it says. rumdl's
-- `[code-block-tools]` section names commands to run over fenced code blocks,
-- and which commands they are is the config's to choose. `fmt --stdin`, what
-- runs here, does not run them and a file argument does (measured, 0.2.52).
-- If that gap ever closes this needs the same trust gate saving already has.
--
-- --no-cache because the cache only buys something when rumdl walks a
-- directory, and all it ever gets from here is one buffer on stdin. Without
-- it every save leaves a .rumdl_cache behind in the directory nvim was
-- started in.

-- What rumdl reads a config from, in its own order of preference within a
-- directory. The markdownlint files are last because that is where rumdl puts
-- them: they count only for a project that configured markdownlint and not
-- rumdl.
local CONFIGS = {
  ".rumdl.toml",
  "rumdl.toml",
  "pyproject.toml",
  ".markdownlint.json",
  ".markdownlint.jsonc",
  ".markdownlint.yaml",
  ".markdownlint.yml",
}

--- Whether `path`, a pyproject.toml, has anything to say to rumdl.
---
--- rumdl reads that file for its own section and nothing else, and a Python
--- project without one has not configured rumdl. Both spellings count, the
--- section itself and a rule's table under it.
local function configures_rumdl(path)
  local ok, lines = pcall(vim.fn.readfile, path)
  if not ok then
    return false
  end

  for _, line in ipairs(lines) do
    if line:match("^%s*%[tool%.rumdl[%.%]]") then
      return true
    end
  end

  return false
end

--- The config the project holding `path` gives rumdl, or nil for a file whose
--- project says nothing.
local function project_config(path)
  if path == "" then
    return nil
  end

  for dir in vim.fs.parents(path) do
    for _, name in ipairs(CONFIGS) do
      local candidate = vim.fs.joinpath(dir, name)

      if vim.uv.fs_stat(candidate) and (name ~= "pyproject.toml" or configures_rumdl(candidate)) then
        return candidate
      end
    end
  end

  return nil
end

return {
  servers = {
    marksman = { binary = "marksman" },
  },

  formatters = {
    markdown = function(buf)
      local config = project_config(vim.api.nvim_buf_get_name(buf))
      if config then
        return { "rumdl", "fmt", "--stdin", "--silent", "--no-cache", "-c", config }
      end

      return {
        "rumdl",
        "fmt",
        "--stdin",
        "--silent",
        "--no-config",
        "--no-cache",
        "-e",
        "MD060",
        "-c",
        "MD060.enabled = true",
        "-c",
        'MD060.style = "aligned"',
        "-c",
        "MD060.max-width = 120",
      }
    end,
  },
}
