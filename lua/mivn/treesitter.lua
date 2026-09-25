-- Tree-sitter: highlighting, folds and injections, and the file types that need
-- a word to reach the right grammar.
--
-- nvim-treesitter only supplies the grammars and their queries; Neovim does the
-- parsing. Grammars are compiled C and are not installed on their own:
-- `:MivnInstallGrammars` builds them, with a C compiler present. A language
-- with no grammar falls back to Vim's own syntax highlighting.

local ts = require("nvim-treesitter")

--- Where the parsers and their query files are put.
local INSTALL_DIR = vim.fs.joinpath(vim.fn.stdpath("data"), "site")

ts.setup({
  install_dir = INSTALL_DIR,
})

local M = {}

--- Every grammar with a parser on disk right now.
function M.installed()
  return ts.get_installed()
end

--- The installed grammars whose queries are gone, so the language turns on and
--- colors nothing. The queries are a symlink into the plugin's own directory,
--- which a moved plugin leaves pointing at nothing, and nvim-treesitter's
--- update does not notice, since it only compares parser revisions.
function M.broken()
  return vim.tbl_filter(function(lang)
    return vim.uv.fs_realpath(vim.fs.joinpath(INSTALL_DIR, "queries", lang)) == nil
  end, ts.get_installed())
end

-- The languages I use, plus what the grammars pull in on their own. `sql` is
-- here for its own files and because Go strings inject into it; see
-- queries/go/injections.scm.
local grammars = {
  "bash",
  "c",
  "comment",
  "cpp",
  "css",
  "diff",
  "dockerfile",
  "eex",
  "elixir",
  "gitattributes",
  "gitcommit",
  "gitignore",
  "gleam",
  "go",
  "gomod",
  "gosum",
  "gotmpl",
  "gowork",
  "graphql",
  "hcl",
  "heex",
  "html",
  "ini",
  "javascript",
  "json",
  "json5",
  "jsonnet",
  "just",
  "lua",
  "luadoc",
  "make",
  "markdown",
  "markdown_inline",
  "nix",
  "printf",
  "proto",
  "python",
  "query",
  "regex",
  "ruby",
  "rust",
  "scss",
  "sql",
  "starlark", -- Tiltfile, via the register below
  "templ",
  "terraform",
  "toml",
  "tsx",
  "typescript",
  "vim",
  "vimdoc",
  "xml",
  "yaml",
  "zig",
}

-- NOTE: forced, since a plain install skips any language whose parser is on
-- disk, and a broken grammar still has its parser.
vim.api.nvim_create_user_command("MivnInstallGrammars", function()
  local installed = ts.get_installed()
  local wanted = M.broken()

  for _, lang in ipairs(grammars) do
    if not vim.list_contains(installed, lang) then
      wanted[#wanted + 1] = lang
    end
  end

  if #wanted == 0 then
    vim.notify("Every grammar is installed, with its queries.")
    return
  end

  ts.install(wanted, { force = true })
end, { desc = "Compile the tree-sitter grammars mivn knows about, and repair broken ones" })

vim.api.nvim_create_user_command("MivnUpdateGrammars", function()
  ts.update()
end, { desc = "Update every installed tree-sitter grammar" })

-- `jsonc` has no grammar of its own and the json parser accepts the comments.
vim.treesitter.language.register("json", "jsonc")

-- JSON with comments that Neovim does not already call `jsonc` (`:h ft-jsonc`),
-- a project's own `.vscode` files among them. The name decides the formatter:
-- `jsonc` goes to the language server, which keeps comments, and `json` to jq,
-- which cannot parse them.
vim.filetype.add({
  filename = {
    ["devcontainer.json"] = "jsonc",
    ["pyrightconfig.json"] = "jsonc",
    [".stylelintrc"] = "jsonc",
    [".swcrc"] = "jsonc",
    [".eslintrc.json"] = "jsonc",
    ["deno.json"] = "jsonc",
  },

  pattern = {
    [".*/%.vscode/.*%.json"] = "jsonc",
  },
})

-- A Tiltfile is Starlark, and there is no grammar under its own name.
vim.treesitter.language.register("starlark", "tiltfile")

-- Compose files get `yaml.docker-compose`, the file type the Docker language
-- server claims them by, which nothing else sets. The register keeps the yaml
-- grammar on them, since tree-sitter does not read the dotted name as yaml.
vim.treesitter.language.register("yaml", "yaml.docker-compose")

vim.filetype.add({
  filename = {
    ["docker-compose.yml"] = "yaml.docker-compose",
    ["docker-compose.yaml"] = "yaml.docker-compose",
    ["compose.yml"] = "yaml.docker-compose",
    ["compose.yaml"] = "yaml.docker-compose",
  },
})

--- Go templates, over whatever they are templates of -------------------------

--- The language a template is a template *of*, or nil when the name does not
--- say, the file type has no grammar, or that grammar is not installed.
---
--- Two shapes: `foo.json.tmpl`, where the suffix comes off, and
--- `.chezmoitemplates/foo.json`, where the name already is it.
local function inner_lang(path, buf)
  local name = vim.fs.basename(path)
  local stem = name:match("^(.*)%.tmpl$") or name:match("^(.*)%.tpl$") or name

  -- the basename alone, or a file under `.chezmoitemplates` is a template again
  local ft = vim.filetype.match({ filename = stem, buf = buf })
  local lang = ft and vim.treesitter.language.get_lang(ft)

  -- `foo.tmpl.tmpl` would inject gotmpl into itself, round after round
  if not lang or lang == "gotmpl" then
    return nil
  end

  -- language.add() answers a grammar this config lacks with nil, not an error
  return vim.treesitter.language.add(lang) and lang or nil
end

--- Claim the buffer as a Go template, and leave the language it is a template
--- of on the buffer as `b:mivn_template_lang`, or false when there is none.
---
--- NOTE: the second half has to happen here, during detection, and not in a
--- FileType autocmd. By then a file type is set for this read, and several of
--- vim.filetype.match()'s detectors answer nothing once one is
--- (`:h did_filetype()`).
local function detect_template(path, buf)
  if buf then
    vim.b[buf].mivn_template_lang = inner_lang(path, buf) or false
  end

  return "gotmpl"
end

-- `.tmpl` and `.tpl` are Go templates, where Neovim's own detection reads them
-- as its unrelated `template` type and as Smarty. So is everything under a
-- `.chezmoitemplates` directory, as chezmoi reads it, whatever it is called;
-- the priority puts that pattern ahead of the extension.
vim.filetype.add({
  extension = {
    tmpl = detect_template,
    tpl = detect_template,
  },

  pattern = {
    [".*/%.chezmoitemplates/.*"] = { detect_template, { priority = 10 } },
  },
})

--- Parse `buf` as a Go template, with the language it is a template of injected
--- between the actions. `injection.combined` parses the `text` fragments as one
--- document, so a `{{ if }}` inside an object does not end the object. The
--- query names that language, so it is built per buffer and the parser made
--- here, before vim.treesitter.start() asks for one.
local function parse_as_template(buf)
  local lang = vim.b[buf].mivn_template_lang
  if not lang then
    return
  end

  local injection = ([[
    ((text) @injection.content
     (#set! injection.language "%s")
     (#set! injection.combined))
  ]]):format(lang)

  pcall(vim.treesitter.get_parser, buf, "gotmpl", { injections = { gotmpl = injection } })
end

-- Highlighting is per buffer and opt-in, so it starts as files open. A missing
-- grammar is normal on a fresh checkout: Vim's syntax highlighting stands in,
-- and a warning names the grammar once per session. Indentation stays with
-- Neovim's ftplugins, still better than tree-sitter's for several of these.
local missing_warned = {}

vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("mivn.treesitter", { clear = true }),
  callback = function(ev)
    if ev.match == "gotmpl" then
      parse_as_template(ev.buf)
    end

    local lang = vim.treesitter.language.get_lang(ev.match)
    if not lang then
      return
    end

    if not pcall(vim.treesitter.start, ev.buf, lang) then
      -- only grammars on the list; a stray file type is not a problem
      if vim.tbl_contains(grammars, lang) and not missing_warned[lang] then
        missing_warned[lang] = true
        vim.notify(
          (
            "The tree-sitter grammar for %s is not installed; :MivnInstallGrammars builds the configured set. "
            .. "Classic highlighting stands in meanwhile."
          ):format(lang),
          vim.log.levels.WARN
        )
      end

      return
    end

    -- folds follow the syntax tree; 'foldenable' is off, so none start closed
    vim.wo[0][0].foldmethod = "expr"
    vim.wo[0][0].foldexpr = "v:lua.vim.treesitter.foldexpr()"
  end,
})

vim.o.foldenable = false

return M
