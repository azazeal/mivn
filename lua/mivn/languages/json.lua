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

--- The catalog and the extras above, as `json.schemas` wants them. Asked for
--- only when the server is installed, since reading the catalog is 470KB of
--- JSON on the startup path.
local function all()
  return vim.list_extend(schemas.json(), EXTRA)
end

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

      config = function()
        return {
          settings = {
            json = {
              schemas = all(),

              -- Not optional even though it reads like a default. The server
              -- computes `validateEnabled = !!settings.json.validate.enable`
              -- when configuration arrives, so sending any settings at all
              -- without it turns validation off entirely, schemas and
              -- `$schema` lines included. Measured 2026-08-15: adding the
              -- catalog alone made package.json stop reporting anything.
              validate = { enable = true },
            },
          },
        }
      end,
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
