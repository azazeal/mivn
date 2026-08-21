-- Lua: lua-language-server, which is what tells me about Neovim's own API,
-- and stylua for the formatting.

local format = require("mivn.format")

return {
  servers = {
    lua_ls = {
      binary = "lua-language-server",

      config = {
        settings = {
          Lua = {
            runtime = { version = "LuaJIT" },
            workspace = {
              checkThirdParty = false,
              library = { vim.env.VIMRUNTIME },
            },
            telemetry = { enable = false },
          },
        },
      },
    },
  },

  formatters = {
    lua = { "stylua", "--stdin-filepath", format.FILE, "-" },
  },
}
