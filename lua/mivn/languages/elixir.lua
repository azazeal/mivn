-- Elixir: expert, which is the community's successor to elixir-ls.
--
-- It compiles the project to answer anything, mix.exs included, and it
-- carries a dependency of its own, elixir_sense, which is in no project's
-- mix.exs: it adds that to the tree and clones it into deps/ the first time
-- it loads a project. So a language server runs git here.

return {
  servers = {
    expert = {
      binary = "expert",

      -- No harmless one-shot flag: it starts speaking LSP whatever it is
      -- handed.
      probe = false,

      -- git without a global config is the only version of that clone worth
      -- having. `/dev/null` for the same reason lua/mivn/update.lua uses it:
      -- a `url.<base>.insteadOf` rewrite would turn the public clone into ssh
      -- and need a key nothing here can offer, and then the load dies inside
      -- Mix.Dep.Converger while the server stays up and silent.
      --
      -- The excludes file needs saying separately: git defaults it to
      -- $XDG_CONFIG_HOME/git/ignore with no configuration involved, and
      -- treats being unable to read it as fatal rather than as "no ignores".
      -- Set through git's own environment interface, which is the way to
      -- configure git without a file it has to open.
      config = {
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
