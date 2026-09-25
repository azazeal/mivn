-- TOML: taplo, for the schema as much as the syntax.
--
-- taplo has to be built from `master`, at 08f343b or later. Up to 0.10.0,
-- the newest release, it checks SchemaStore's catalog against the
-- json.schemastore.org URL built into it, while the catalog now says
-- www.schemastore.org, so every TOML file loses its schema. A build with the
-- fix reaches the catalog on its own and wants nothing from
-- lua/mivn/schemas.lua.

return {
  servers = {
    taplo = {
      binary = "taplo",

      config = {
        settings = {
          evenBetterToml = {
            -- The default, written out so the URL the build has to reach is
            -- here to see.
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
