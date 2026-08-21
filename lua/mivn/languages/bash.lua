-- Shell: bash-language-server, which runs shellcheck over the file, and shfmt
-- for the formatting.

local format = require("mivn.format")

return {
  servers = {
    bashls = { binary = "bash-language-server" },
  },

  formatters = {
    -- shfmt reads .editorconfig itself when it is given no formatting flags,
    -- which is why it gets the filename and nothing else.
    sh = { "shfmt", "--filename", format.FILE },
    bash = { "shfmt", "--filename", format.FILE },
  },
}
