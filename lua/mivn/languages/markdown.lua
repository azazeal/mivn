-- Markdown: marksman, for the links between notes, and rumdl for the tables.
--
-- rumdl is a linter that fixes, and `-e` runs one rule and nothing else, so a
-- file with no table comes back byte for byte and the prose I wrapped by hand
-- stays where I put it. mdformat and prettier own the whole document instead:
-- headings, bullets, numbering, nesting, code blocks and escapes all change.
--
-- MD060 is off by default and its style keeps whatever padding it finds, so
-- both overrides are needed for an aligned table. max-width leaves a table
-- compact when aligning it would cross 120 columns, the limit nothing here may
-- cross.
--
-- A project with a rumdl config of its own decides for itself, and none of the
-- settings above are passed. The config is found from the file rather than
-- left to rumdl, which walks up from its working directory, i.e. where the
-- editor started, so a file from another checkout would get this checkout's
-- rules.
--
-- --no-cache because the cache only helps when rumdl walks a directory, and
-- without it every save leaves a .rumdl_cache where the editor started.

-- Where rumdl reads a config from, in its own order within a directory. The
-- markdownlint files count only for a project that configured markdownlint
-- and not rumdl.
local CONFIGS = {
  ".rumdl.toml",
  "rumdl.toml",
  "pyproject.toml",
  ".markdownlint.json",
  ".markdownlint.jsonc",
  ".markdownlint.yaml",
  ".markdownlint.yml",
}

--- Whether `path`, a pyproject.toml, has a `[tool.rumdl]` section or a rule's
--- table under it. rumdl reads nothing else from that file.
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
      -- NOTE: honoring a config means running what it says. rumdl's
      -- `[code-block-tools]` names commands to run over fenced code blocks;
      -- `fmt --stdin` does not run them and a file argument does (rumdl
      -- 0.2.52). Passing the file, or a rumdl that changes this, needs the
      -- trust gate saving already has.
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
