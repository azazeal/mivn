-- Elixir: expert, the community's successor to elixir-ls.
--
-- It compiles the project to answer anything, mix.exs included, and the
-- first time it loads a project it clones a dependency of its own,
-- elixir_sense, into deps/. So a language server runs git here.

return {
  servers = {
    expert = {
      binary = "expert",

      -- No harmless one-shot flag: it starts speaking LSP whatever it is
      -- handed.
      probe = false,

      config = {
        -- Both are on by default, and both are the server doing work I did
        -- not ask for in someone else's checkout: compileOnType runs the
        -- project's macros as I type, and autoFetchDependencies runs `mix
        -- deps.get`, which reaches the network and puts code on the disk.
        -- lua/mivn/trust.lua decides whether the server starts at all; these
        -- decide what it does once it has.
        --
        -- NOTE: Flat keys, not nested under a section. expert reads them
        -- straight from the didChangeConfiguration notification.
        settings = {
          compileOnType = false,
          autoFetchDependencies = false,
        },

        -- My git config stays out of that clone, for the reason
        -- lua/mivn/update.lua gives.
        --
        -- NOTE: The excludes file needs its own line. git reads
        -- $XDG_CONFIG_HOME/git/ignore even with no config at all, and fails
        -- when it cannot read it.
        cmd_env = {
          GIT_CONFIG_GLOBAL = "/dev/null",
          GIT_CONFIG_SYSTEM = "/dev/null",
          GIT_TERMINAL_PROMPT = "0",
          GIT_CONFIG_COUNT = "1",
          GIT_CONFIG_KEY_0 = "core.excludesFile",
          GIT_CONFIG_VALUE_0 = "/dev/null",
        },
      },
    },
  },
}
