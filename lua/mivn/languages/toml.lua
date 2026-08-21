-- TOML: taplo, for the schema as much as the syntax.
--
-- taplo is expected to be a source build of the head of its default branch,
-- `master`, which is 08f343b (2026-07-28, `fix: update schemastore URL`). No
-- release carries that fix: the newest is 0.10.0, from 2025-05-23, and it
-- checks SchemaStore's catalog against the json.schemastore.org URL compiled
-- into it while the catalog now says www.schemastore.org, so every TOML file
-- loses its schema. With the fix taplo reaches its own catalog and wants
-- nothing from lua/mivn/schemas.lua.

return {
  servers = {
    taplo = {
      binary = "taplo",

      config = {
        settings = {
          evenBetterToml = {
            -- Named outright rather than left to the default, so the URL this
            -- build is expected to reach is written down where the comment
            -- above can point at it.
            schema = {
              enabled = true,
              catalogs = { "https://www.schemastore.org/api/json/catalog.json" },
            },
          },
        },
      },
    },
  },

  formatters = {
    toml = { "taplo", "format", "-" },
  },
}
