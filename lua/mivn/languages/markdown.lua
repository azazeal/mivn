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
-- --no-config so that a repository carrying its own .rumdl.toml cannot decide
-- what saving a file does in here.

return {
  servers = {
    marksman = { binary = "marksman" },
  },

  formatters = {
    markdown = {
      "rumdl",
      "fmt",
      "--stdin",
      "--silent",
      "--no-config",
      "-e",
      "MD060",
      "-c",
      "MD060.enabled = true",
      "-c",
      'MD060.style = "aligned"',
      "-c",
      "MD060.max-width = 120",
    },
  },
}
