-- Docker: the Docker language server, and dockerfmt for the formatting.
--
-- The settings turn two of the server's defaults off: telemetry, and
-- `experimental.vulnerabilityScanning`, which is Docker Scout sending what a
-- Dockerfile names somewhere to be looked up. An editor should do neither
-- without being asked.

return {
  servers = {
    docker_language_server = {
      binary = "docker-language-server",

      config = {
        -- NOTE: the section is `docker.lsp`, and Neovim splits a section on
        -- the dot before it looks it up, so the table has to be nested. A key
        -- with the dot in it is never found.
        settings = {
          docker = {
            lsp = {
              telemetry = "off",
              experimental = { vulnerabilityScanning = false },
            },
          },
        },
      },
    },
  },

  formatters = {
    dockerfile = { "dockerfmt" },
  },

  -- Not --version: dockerfmt calls that an unknown flag and exits 1.
  probes = {
    dockerfmt = { "version" },
  },
}
