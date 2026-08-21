-- XML: no server, only the formatter. xmllint adds an <?xml?> declaration to
-- a file that has none.

return {
  formatters = {
    xml = { "xmllint", "--format", "-" },
  },
}
