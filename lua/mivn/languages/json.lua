-- JSON: the same server VS Code uses, plus the catalog VS Code's extension
-- hands it, plus jq for the formatting.

local schemas = require("mivn.schemas")

-- What SchemaStore's catalog does not carry, by name and URL. An entry earns
-- its place here by being a schema I want matched on a file name that the
-- catalog has never heard of; anything the catalog already knows is one line
-- too many.
local EXTRA = {
  {
    fileMatch = { "wails.json" },
    url = "https://raw.githubusercontent.com/wailsapp/wails/master/website/static/schemas/config.v2.json",
  },
}

return {
  servers = {
    jsonls = {
      -- nvim-lspconfig ships a `cmd` **function** that prefers
      -- `<root>/node_modules/.bin/<server>` whenever the project has one, so
      -- opening a repository would run the language server that repository
      -- shipped.
      cmd = { "vscode-json-language-server", "--stdio" },

      -- No harmless one-shot flag: the vscode-languageserver runtime under it
      -- exits 1 on anything that does not name a transport.
      probe = false,

      config = {
        settings = {
          json = {
            -- Not optional even though it reads like a default. The server
            -- computes `validateEnabled = !!settings.json.validate.enable`
            -- when configuration arrives, so sending any settings at all
            -- without it turns validation off entirely, schemas and
            -- `$schema` lines included.
            validate = { enable = true },
          },
        },

        -- The catalog is 470KB of JSON, so it is read when the server starts
        -- rather than when the editor does. The settings table filled in here
        -- is the one the client sends once the server is up.
        before_init = function(_, config)
          config.settings.json.schemas = vim.list_extend(schemas.json(), EXTRA)
        end,
      },
    },
  },

  formatters = {
    -- jq knows nothing about EditorConfig, so the indent is handed to it from
    -- the buffer, where EditorConfig has settled it. `--indent` caps at 7.
    json = function(buf)
      if not vim.bo[buf].expandtab then
        return { "jq", "--tab", "." }
      end

      local width = vim.bo[buf].shiftwidth
      if width == 0 then
        width = vim.bo[buf].tabstop
      end

      return { "jq", "--indent", tostring(math.min(width, 7)), "." }
    end,
  },
}
