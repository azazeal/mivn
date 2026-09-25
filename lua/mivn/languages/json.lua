-- JSON: the VS Code server with SchemaStore's catalog, and jq for the
-- formatting.

local schemas = require("mivn.schemas")

-- Schemas I want matched on file names SchemaStore's catalog has never heard
-- of. Anything the catalog already knows does not belong here.
local EXTRA = {
  {
    fileMatch = { "wails.json" },
    url = "https://raw.githubusercontent.com/wailsapp/wails/master/website/static/schemas/config.v2.json",
  },
}

return {
  servers = {
    jsonls = {
      -- NOTE: the plain command, because nvim-lspconfig's own `cmd` is a
      -- function that prefers `<root>/node_modules/.bin/<server>` when the
      -- project has one, i.e. opening a repository would run the language
      -- server that repository shipped.
      cmd = { "vscode-json-language-server", "--stdio" },

      -- No harmless one-shot flag: the vscode-languageserver runtime under it
      -- exits 1 on anything that does not name a transport.
      probe = false,

      config = {
        settings = {
          json = {
            -- NOTE: not optional, even though it reads like a default. The
            -- server computes
            -- `validateEnabled = !!settings.json.validate.enable` when settings
            -- arrive, so any settings sent without it turn validation off,
            -- schemas and `$schema` lines included.
            validate = { enable = true },
          },
        },

        -- The catalog is 470KB of JSON, so it is read when the server starts
        -- rather than when the editor does. The client sends the settings
        -- table filled in here once the server is up.
        before_init = function(_, config)
          config.settings.json.schemas = vim.list_extend(schemas.json(), EXTRA)
        end,
      },
    },
  },

  formatters = {
    -- jq knows nothing about EditorConfig, so it gets the indent from the
    -- buffer, where EditorConfig has set it. `--indent` caps at 7.
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
