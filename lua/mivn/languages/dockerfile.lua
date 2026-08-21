-- Dockerfiles and compose files: docker's own language server, and dockerfmt
-- for the formatting.

return {
  servers = {
    docker_language_server = { binary = "docker-language-server" },
  },

  formatters = {
    dockerfile = { "dockerfmt" },
  },

  -- Not --version: dockerfmt calls that an unknown flag and exits 1.
  probes = {
    dockerfmt = { "version" },
  },
}
