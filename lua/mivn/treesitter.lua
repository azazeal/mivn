-- Tree-sitter: highlighting, folds, and language injection.
--
-- Neovim parses with tree-sitter itself; nvim-treesitter only supplies the
-- grammars and their query files. Grammars are compiled C, so they are not
-- installed automatically: run `:MivnInstallGrammars` once, with a C compiler
-- present. Anything without a grammar falls back to regex highlighting.

local ts = require("nvim-treesitter")

ts.setup({
  install_dir = vim.fs.joinpath(vim.fn.stdpath("data"), "site"),
})

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

-- The same hatch lsp.lua's `lsp_servers` gives: `treesitter_grammars` in the
-- local overrides maps a grammar name to true (add) or false (drop).
local overrides = require("mivn.overrides")
for name, wanted in pairs(overrides.treesitter_grammars or {}) do
  if wanted == false then
    for i, grammar in ipairs(grammars) do
      if grammar == name then
        table.remove(grammars, i)
        break
      end
    end
  elseif not vim.tbl_contains(grammars, name) then
    grammars[#grammars + 1] = name
  end
end

vim.api.nvim_create_user_command("MivnInstallGrammars", function()
  ts.install(grammars)
end, { desc = "Compile the tree-sitter grammars mivn knows about" })

vim.api.nvim_create_user_command("MivnUpdateGrammars", function()
  ts.update()
end, { desc = "Update every installed tree-sitter grammar" })

--- Go templates, over whatever they are templates of -------------------------

-- `jsonc` has no grammar of its own and the json parser accepts the comments.
vim.treesitter.language.register("json", "jsonc")

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
-- missing grammar is the normal case on a fresh checkout, not an error, so the
-- failure is swallowed and Vim's own syntax highlighting stands in.
--
-- Indentation is left to Neovim's built-in ftplugins: tree-sitter's indent is
-- still rougher than the hand-written rules for several of these languages.
vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("mivn.treesitter", { clear = true }),
  callback = function(ev)
    if ev.match == "gotmpl" then
      parse_as_template(ev.buf)
    end

    local lang = vim.treesitter.language.get_lang(ev.match)
    if not lang or not pcall(vim.treesitter.start, ev.buf, lang) then
      return
    end

    -- Folds follow the syntax tree. 'foldenable' stays off, so they exist to
    -- be opened with `za` but nothing starts collapsed.
    vim.wo[0][0].foldmethod = "expr"
    vim.wo[0][0].foldexpr = "v:lua.vim.treesitter.foldexpr()"
  end,
})

vim.o.foldenable = false
