-- Docker: the Docker language server, and dockerfmt for the formatting.
--
-- Both of the server's own defaults are turned off here, and they are the
-- reason this file has settings at all. It reports telemetry by default, and
-- `experimental.vulnerabilityScanning` is on by default, which is Docker
-- Scout: opening a Dockerfile sends what it names somewhere to be looked up.
-- Neither is something an editor should do without being asked.
--
-- The section it reads is `docker.lsp`, and Neovim splits a section on the
-- dot before answering, so the table has to be nested rather than named with
-- the dot in it.

return {
  servers = {
    docker_language_server = {
      binary = "docker-language-server",

      config = {
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
