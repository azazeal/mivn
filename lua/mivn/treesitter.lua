-- Tree-sitter: highlighting, folds, and language injection.
--
-- Neovim parses with tree-sitter itself; nvim-treesitter only supplies the
-- grammars and their query files. Grammars are compiled C, so they are not
-- installed automatically: run `:MivnInstallGrammars` once, with a C compiler
-- present. Anything without a grammar falls back to regex highlighting.

local ts = require("nvim-treesitter")

--- Where the parsers and their query files are put. Named once and exported
--- below, because `:checkhealth mivn` has to look inside it and a second
--- spelling of this path is a second thing to keep in step.
local INSTALL_DIR = vim.fs.joinpath(vim.fn.stdpath("data"), "site")

ts.setup({
  install_dir = INSTALL_DIR,
})

local M = {}

--- Every grammar with a parser on disk right now.
function M.installed()
  return ts.get_installed()
end

--- Where a language's query files are looked for.
---
--- They are not copied here: each one is a symlink into the plugin's own
--- runtime directory, which is why a link can outlive what it points at.
function M.queries_of(lang)
  return vim.fs.joinpath(INSTALL_DIR, "queries", lang)
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

vim.api.nvim_create_user_command("MivnInstallGrammars", function()
  ts.install(grammars)
end, { desc = "Compile the tree-sitter grammars mivn knows about" })

vim.api.nvim_create_user_command("MivnUpdateGrammars", function()
  ts.update()
end, { desc = "Update every installed tree-sitter grammar" })

--- Go templates, over whatever they are templates of -------------------------

-- `jsonc` has no grammar of its own and the json parser accepts the comments.
vim.treesitter.language.register("json", "jsonc")

-- Files that are JSON with comments in them but are not called `.jsonc`.
--
-- The file type is what decides how the file is formatted: `jsonc` has no
-- formatter of its own, so it goes to the language server, which keeps the
-- comments, while `json` goes to jq, which cannot parse one. So a file
-- carrying comments under the wrong name is not formatted at all, and says so
-- on every save.
--
-- Neovim already names most of them (`:h ft-jsonc`, and `[jt]sconfig*.json`,
-- `.babelrc`, `.eslintrc`, `.jshintrc`, `.luaurc`, `bun.lock` among them).
-- These are the ones it misses. The first four are on Zed's list for the same
-- language and the rest are documented by the tools that read them.
--
-- The `.vscode` pattern is the gap worth having: Neovim reads the *user*
-- settings under `Code/User/` as jsonc and a project's own `.vscode` as plain
-- json, and a project's is the one I open.
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

-- Compose files earn a filetype of their own, because that is the name the
-- Docker language server claims them by (lua/mivn/languages/dockerfile.lua);
-- nothing else produces it, so it is declared here. The yaml grammar keeps highlighting
-- them: the dotted name means "yaml, then more specific", and the register
-- call is what tells tree-sitter that.
vim.treesitter.language.register("yaml", "yaml.docker-compose")

vim.filetype.add({
  filename = {
    ["docker-compose.yml"] = "yaml.docker-compose",
    ["docker-compose.yaml"] = "yaml.docker-compose",
    ["compose.yml"] = "yaml.docker-compose",
    ["compose.yaml"] = "yaml.docker-compose",
  },
})

--- The language a template is a template *of*, or nil when the name does not
--- say, the file type has no grammar, or that grammar is not installed.
---
--- Two shapes: `foo.json.tmpl`, where the suffix comes off, and
--- `.chezmoitemplates/foo.json`, where the name already is it.
local function inner_lang(path, buf)
  local name = vim.fs.basename(path)
  local stem = name:match("^(.*)%.tmpl$") or name:match("^(.*)%.tpl$") or name

  -- The basename alone: matched against the whole path, a file under
  -- `.chezmoitemplates` would come back as a template again.
  local ft = vim.filetype.match({ filename = stem, buf = buf })
  local lang = ft and vim.treesitter.language.get_lang(ft)

  -- `foo.tmpl.tmpl` would inject the template language into itself, and each
  -- round has text nodes of its own to inject into again.
  if not lang or lang == "gotmpl" then
    return nil
  end

  -- The grammar it names may not be one this config carries. language.add()
  -- answers that with nil and a message rather than an error, so the return
  -- value is what has to be checked.
  return vim.treesitter.language.add(lang) and lang or nil
end

--- Claim the buffer as a Go template, and leave the language it is a template
--- of on the buffer as `b:mivn_template_lang`, or false when there is none.
---
--- The second half is why this is a function rather than a file type name.
--- vim.filetype.match() answers "what would this file be without the template
--- around it", but only from here: several of its detectors return nothing
--- once a file type has been decided for this read (`:h did_filetype()`), and
--- by the time a FileType autocmd runs one has. Detection is still in progress
--- here and the buffer already holds the file, so a shebang still counts.
local function detect_template(path, buf)
  if buf then
    vim.b[buf].mivn_template_lang = inner_lang(path, buf) or false
  end

  return "gotmpl"
end

-- A `.tmpl` file is two languages at once: Go's text/template outside, and the
-- language of the file it produces between the actions. Neovim's own detection
-- calls it `template`, a file type with an unrelated syntax file behind it,
-- and reads `.tpl` as Smarty; `gotmpl` is what the grammar is called.
--
-- chezmoi also reads everything under a `.chezmoitemplates` directory as a
-- template whatever it is called, so those files have no `.tmpl` to go on and
-- would open as the plain language with every action an error. The priority is
-- what puts the pattern ahead of the extension.
vim.filetype.add({
  extension = {
    tmpl = detect_template,
    tpl = detect_template,
  },

  pattern = {
    [".*/%.chezmoitemplates/.*"] = { detect_template, { priority = 10 } },
  },
})

--- Parse `buf` as a Go template with the language named by the rest of its
--- name highlighted in between the actions.
---
--- The file arrives as a run of `text` fragments with holes where the actions
--- were. `injection.combined` is what makes that work: the fragments are
--- parsed as one document rather than one each, so a `{{ if }}` in the middle
--- of an object does not end the object.
---
--- The query has to be built per buffer, since it names the language this file
--- is a template of. So this creates the parser and the autocmd below finds it
--- already made.
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

-- Highlighting is per-buffer and opt-in, so it is started as files open. A
-- missing grammar is the normal case on a fresh checkout, not an error, but
-- it is no longer swallowed whole: Vim's own syntax highlighting stands in,
-- and a warning names the missing grammar and the command that builds it.
--
-- Indentation is left to Neovim's built-in ftplugins: tree-sitter's indent is
-- still rougher than the hand-written rules for several of these languages.
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
      -- Failing silently here cost real time twice: a fresh clone has no
      -- compiled grammars (they live in the data directory, not this repo),
      -- and everything just stays plain with no hint why. Say it, once per
      -- language per session, and only for grammars the config actually
      -- wants; a stray filetype outside the list is not a problem to report.
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

    -- Folds follow the syntax tree. 'foldenable' stays off, so they exist to
    -- be opened with `za` but nothing starts collapsed.
    vim.wo[0][0].foldmethod = "expr"
    vim.wo[0][0].foldexpr = "v:lua.vim.treesitter.foldexpr()"
  end,
})

vim.o.foldenable = false

return M
