-- Which Go strings queries/go/injections.scm hands to the SQL parser. Each
-- case is a few statements inside a `func main`, and the strings that must
-- come out as SQL, no more and no fewer. Run headless by
-- .github/scripts/injections, which reads what `run()` prints.

local H = dofile(debug.getinfo(1, "S").source:match("^@(.*/)") .. "harness.lua")

local M = H.new()

local function case(name, body, sql)
  M.cases[#M.cases + 1] = { name = name, body = body, sql = sql }
end

--- One of each shape the tag can sit in ---------------------------------------

case("const", { "const q = /* sql */ `SELECT 1`" }, { "SELECT 1" })
case("var", { "var q = /* sql */ `SELECT 1`" }, { "SELECT 1" })
case("short declaration", { "q := /* sql */ `SELECT 1`" }, { "SELECT 1" })
case("assignment", { "q = /* sql */ `SELECT 1`" }, { "SELECT 1" })
case("interpreted string", { 'q := /* sql */ "SELECT 1"' }, { "SELECT 1" })
case("call argument", { 'db.Query( /* sql */ `SELECT 1`, "not sql")' }, { "SELECT 1" })
case("slice element", { '_ = []string{ /* sql */ "SELECT 1", "not sql"}' }, { "SELECT 1" })
case("struct field", { '_ = T{body: /* sql */ `SELECT 1`, other: "not sql"}' }, { "SELECT 1" })

--- The tag itself ---------------------------------------------------------------

case("tag, no spaces", { "q := /*sql*/ `SELECT 1`" }, { "SELECT 1" })
case("tag, capitals", { "q := /* SQL */ `SELECT 1`" }, { "SELECT 1" })
case("no tag", { "q := `SELECT 1`" }, {})
case("another comment", { "q := /* not sql */ `SELECT 1`" }, {})

--- Several values, only the tagged ones -----------------------------------------

case("first of two", { 'a, b := /* sql */ `SELECT 1`, "not sql"' }, { "SELECT 1" })
case("first of two, var", { 'var a, b = /* sql */ `SELECT 1`, "not sql"' }, { "SELECT 1" })
case("second of two", { 'a, b := "not sql", /* sql */ `SELECT 2`' }, { "SELECT 2" })
case("both of two", { "a, b := /* sql */ `SELECT 1`, /* sql */ `SELECT 2`" }, { "SELECT 1", "SELECT 2" })

-- gofmt moves a tag that stands before a later value to the far side of the
-- comma, onto the end of the value before it.
case("both of two, after gofmt", { "a, b := /* sql */ `SELECT 1` /* sql */, `SELECT 2`" }, { "SELECT 1", "SELECT 2" })

--- The driver's half ------------------------------------------------------------

--- The strings the SQL parser was handed in `body`, sorted, or nil and why
--- when there is nothing to parse with.
local function injected(body)
  local lines = { "package main", "", "func main() {" }
  for _, line in ipairs(body) do
    lines[#lines + 1] = "\t" .. line
  end
  lines[#lines + 1] = "}"

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  local ok, parser = pcall(vim.treesitter.get_parser, buf, "go")
  if not ok or not parser then
    return nil, "no go grammar"
  end

  parser:parse(true)

  local found = {}
  local sql = parser:children().sql

  for _, region in ipairs(sql and sql:included_regions() or {}) do
    for _, range in ipairs(region) do
      found[#found + 1] = vim.api.nvim_buf_get_text(buf, range[1], range[2], range[4], range[5], {})[1]
    end
  end

  vim.api.nvim_buf_delete(buf, { force = true })
  table.sort(found)

  return found
end

--- Print a row per case matching `pattern` and quit, non-zero on any FAIL.
function M.run(pattern)
  local failed = false

  -- NOTE: an injection whose grammar is missing is silently not made, so
  -- without the sql grammar every case expecting nothing would pass.
  if not vim.treesitter.language.add("sql") then
    io.write("injections: the sql grammar is not installed; :MivnInstallGrammars builds it\n")
    vim.cmd("cq!")
    return
  end

  for _, i in ipairs(M.matching(pattern)) do
    local c = M.cases[i]
    local got, why = injected(c.body)
    local wrong = got and H.differences({ sql = got }, { sql = c.sql }) or { why }

    failed = failed or #wrong > 0
    io.write(H.verdict(c.name, wrong), "\n")
  end

  vim.cmd(failed and "cq!" or "qa!")
end

return M
