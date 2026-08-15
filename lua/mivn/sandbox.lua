-- What a language server is allowed to touch.
--
-- A language server is a program someone else wrote, reading a project
-- someone else wrote, and several of them run that project's code on their
-- own: rust-analyzer executes build scripts and proc macros, expert compiles
-- mix.exs, gopls shells out to a toolchain. Opening a repository has always
-- meant running its code, and the store's install prompt never gated that;
-- it gated the download.
--
-- So every server this config starts is wrapped in `mise exec` with the
-- flags below. mise carries the sandbox: Landlock plus a seccomp filter on
-- Linux, Seatbelt on macOS, which is why this is not bwrap (Linux only).
-- mise applies the restrictions and then execs the real program, so nothing
-- stays resident and the cost is one config resolution, about 6ms, per
-- server start.
--
-- The property that makes it worth doing: **children inherit it, and cannot
-- drop it**. The risk was never gopls itself, it is the `go` gopls runs. A
-- restriction on the server is a restriction on the whole tree under it.
--
-- What this does not do: `:terminal` is never wrapped, since that is my own
-- shell, and neither is Neovim. A sandboxed server can still read and send
-- the project it was pointed at, which is its job; what it can no longer do
-- is read ~/.ssh, my tokens, or another project.

local M = {}

local overrides = require("mivn.overrides")

--- A directory beside Neovim's own under XDG_CACHE_HOME, which is where the
--- servers that keep a cache keep it. Normalised because a `..` left in the
--- middle is a path Landlock takes literally.
local function cache(name)
  return vim.fs.normalize(vim.fs.joinpath(vim.fn.stdpath("cache"), "..", name))
end

--- Where the Go toolchain keeps what it downloads and what it builds. Asked
--- once, because both move with GOPATH and with which Go mise resolved, and
--- a wrong guess here is a server that cannot type-check anything. Empty
--- when there is no `go` to ask, which is also when nothing needs them.
local go_dirs
local function go_caches()
  if go_dirs == nil then
    go_dirs = {}

    local ok, result = pcall(function()
      return vim.system({ "go", "env", "GOMODCACHE", "GOCACHE" }, { text = true }):wait(5000)
    end)

    if ok and result.code == 0 then
      for line in (result.stdout or ""):gmatch("[^\r\n]+") do
        if line ~= "" then
          go_dirs[#go_dirs + 1] = line
        end
      end
    end
  end

  return go_dirs
end

--- A directory beside Neovim's own under XDG_DATA_HOME, for the servers that
--- unpack themselves before they can run.
local function data(name)
  return vim.fs.normalize(vim.fs.joinpath(vim.fn.stdpath("data"), "..", name))
end

--- A directory in $HOME, for the toolchains that keep their caches there.
local function home(name)
  return vim.fs.joinpath(vim.uv.os_homedir() or "~", name)
end

--- The policy per server. Absent from this table means unwrapped, which is
--- how a server joins deliberately rather than by being forgotten.
---
---   net    false denies it outright. Most of these read a project and
---          answer questions about it; the exception is a server that
---          fetches JSON schemas, which is a network feature however it
---          looks. Keeping the network also needs the resolver directory
---          readable, since /etc/resolv.conf is a symlink into /run and
---          mise's own read list stops at /etc. Named narrowly rather than
---          granting /run, which holds the ssh agent's socket.
---   write  a list of extra writable paths; absent denies every write.
---          `/tmp` stays writable whatever this says, which is mise's own
---          floor, so treat it as public.
---   project  the workspace itself is writable. The servers that compile
---          need it: gopls' tidy, vendor and generate codelenses write into
---          the repository, rust-analyzer's build scripts write `target/`,
---          expert writes `_build/`. It also means those servers can rewrite
---          any file in the checkout, which they can already do through the
---          edits they hand back, so nothing is lost by admitting it.
---   go     the Go module cache and build cache, read and written. Anything
---          that runs `go list` needs both, and that is more servers than it
---          sounds: templ proxies to gopls, and golangci-lint compiles.
---   own    lets the server write inside its own installed copy. Only
---          lua-language-server needs it: it keeps a parse cache and a lock
---          under `<entry>/log/cache/<pid>` and exits 1 when it cannot
---          create them (measured 2026-08-15). The grant is that one
---          version's directory, not the store.
---   read   extra readable paths, on top of the workspace and the install
---          directories above, as a list or as a function of the workspace
---          that returns one. mise already allows /usr, /lib, /bin, /etc,
---          /proc, /sys and /home/linuxbrew.
---   env    the variable patterns that survive; absent keeps only mise's
---          floor of PATH, HOME, USER, SHELL, TERM, COLORTERM and LANG.
---   setenv variables to set for this server, which are allowed through by
---          name automatically. For the ones that have to be told something
---          rather than merely permitted.
local POLICY = {
  -- buf unpacks the well-known protobuf types into its cache and exits 1
  -- when it cannot (measured 2026-08-15).
  buf_ls = { net = false, write = { cache("buf") } },
  docker_language_server = { net = false },
  lua_ls = { net = false, own = true },
  marksman = { net = false },
  superhtml = { net = false },

  -- The two schema servers keep the network for the same reason taplo does:
  -- a schema is a URL. yamlls fetches SchemaStore's catalog itself, which is
  -- what makes a GitHub workflow file validate without being told anything.
  jsonls = {},
  yamlls = {},

  -- Also keeps the network, and for the same reason: it resolves the schema
  -- a `#:schema` line names, or one its catalog matches by file name.
  -- Denying it turns every mise.toml and Cargo.toml back into unchecked text
  -- (measured 2026-08-15). The read is Neovim's cache directory, where
  -- lua/mivn/schemas.lua keeps the catalog taplo is pointed at.
  taplo = { read = { vim.fn.stdpath("cache") } },
  terraformls = { net = false },
  tsgo = { net = false },

  -- Python. ruff formats, so it writes the checkout and keeps a cache in it;
  -- ty only reads. Neither fetches anything: the environment they inspect is
  -- already on disk.
  ruff = { net = false, project = true },
  ty = { net = false },

  --- The compiler-backed servers ----------------------------------------------
  --
  -- These keep the network, deliberately. gopls already runs almost
  -- everything with GOPROXY=off and opts in for exactly seven things, the
  -- upgrade codelens, vulncheck, vendor, generate, the module graph and the
  -- first load among them, and those are the ones worth having. What they
  -- lose instead is the environment: `GO*` and the toolchains' own variables
  -- survive, everything else does not, so a compromised build script has no
  -- token to send anywhere.
  --
  -- GOPRIVATE has to be in that list for a reason beyond convenience:
  -- without it the go command treats private module paths as public and asks
  -- proxy.golang.org about them by name.
  --
  -- What they cannot do is read `~/.ssh`, `~/.aws` or another checkout, so a
  -- private module that is not already in the cache fails here and gets
  -- fetched in a terminal instead. That is the trade, and it is deliberate.
  -- gopls keeps a cache of its own beside the build cache, and cannot work
  -- without writing it: measured 2026-08-15, every hover in a large repo
  -- came back empty while the log filled with "storing export data ...
  -- permission denied".
  gopls = { env = { "GO*" }, project = true, go = true, write = { cache("gopls") } },
  templ = { env = { "GO*" }, project = true, go = true, write = { cache("gopls") } },

  golangci_lint_ls = {
    env = { "GO*" },
    project = true,
    go = true,
    write = { cache("golangci-lint") },

    -- golangci-lint walks up for its config, and an organisation's checkouts
    -- often share one a directory above the repository. Granted as that one
    -- file rather than the directory holding it, which would open every
    -- sibling checkout at once. Without it every Go file reports "can't read
    -- viper config: permission denied" (measured 2026-08-15).
    read = function(dir)
      local found = vim.fs.find({
        ".golangci.yml",
        ".golangci.yaml",
        ".golangci.toml",
        ".golangci.json",
      }, { path = dir, upward = true, type = "file" })[1]

      return found and vim.fs.relpath(dir, found) == nil and { found } or {}
    end,
  },

  rust_analyzer = {
    env = { "CARGO*", "RUST*" },
    project = true,
    read = { home(".rustup") }, -- the sysroot, and rust-src inside it
    write = { home(".cargo") },
  },

  -- expert is a burrito build: it unpacks a whole BEAM release beside
  -- Neovim's data directory on first run and writes a cookie into it, so
  -- without that grant it answers `error: AccessDenied` and never speaks
  -- (measured 2026-08-15, on an umbrella project).
  --
  -- The two directories under $HOME are mix's, not expert's: converging an
  -- umbrella's dependencies reads the hex registry and rebar's cache, and
  -- without them the load fails inside Mix.Dep.Converger while the server
  -- stays up and silent (measured 2026-08-15, and it does not happen
  -- unsandboxed, which is how it was found).
  expert = {
    env = { "MIX_*", "ELIXIR*", "ERL*" },
    project = true,
    write = { data(".burrito"), cache("expert"), home(".hex"), home(".mix"), cache("rebar3") },

    -- expert carries a dependency of its own, elixir_sense, which is in no
    -- project's mix.exs: it adds it to the tree and clones it into deps/ the
    -- first time it loads a project. So a language server runs git here, and
    -- git without a global config is the only version of that worth having.
    -- `/dev/null` for the same two reasons lua/mivn/update.lua uses it: a
    -- `url.<base>.insteadOf` rewrite would turn the public clone into ssh
    -- and need a key, and reading ~/.gitconfig is not something a language
    -- server should be able to do. Measured 2026-08-15: without this the
    -- load dies on `unable to access '/home/azazeal/.gitconfig'` and expert
    -- stays up knowing nothing.
    -- The excludes file needs saying separately: git defaults it to
    -- $XDG_CONFIG_HOME/git/ignore with no configuration involved, and treats
    -- being unable to read it as fatal rather than as "no ignores". Set
    -- through git's own environment interface, which is the way to configure
    -- git without a file it has to open.
    setenv = {
      GIT_CONFIG_GLOBAL = "/dev/null",
      GIT_CONFIG_SYSTEM = "/dev/null",
      GIT_TERMINAL_PROMPT = "0",
      GIT_CONFIG_COUNT = "1",
      GIT_CONFIG_KEY_0 = "core.excludesFile",
      GIT_CONFIG_VALUE_0 = "/dev/null",
    },
  },
  gleam = { env = { "GLEAM*" }, project = true },
}

--- Why the sandbox is off, when it is. Read by lua/mivn/health.lua.
local off

--- Whether `mise exec` can run anything at all here.
---
--- The wrapper is mise, so mise's opinion of this workspace decides whether
--- any of these servers start. MISE_SAFE covers a config that is untrusted,
--- and does not cover one mise cannot parse: measured 2026-08-15, a
--- mise.toml with `idiomatic_version_file_enable_tools = "go"` (a string
--- where a list belongs) made every wrapped server exit 1 before it spoke a
--- word. Losing the sandbox is bad; losing every language server, on a file
--- the servers exist to tell me about, is worse.
---
--- So this probes once, and a failure turns the wrapping off loudly rather
--- than taking the servers down with it. It is also a way in: a repository
--- that ships a config mise chokes on gets its language servers unconfined.
--- That is why the notice is a warning and not a log line.
---
--- **MISE_AUTO_INSTALL=0 is what keeps this cheap.** `mise exec` installs a
--- missing tool before it runs anything, so in a checkout whose go.mod names
--- a toolchain this machine has never had, the probe becomes a toolchain
--- download. Measured 2026-08-15: it fetched a whole Go and blew a
--- five-second timeout, which stood the sandbox down for that session.
--- Neither startup nor a server start may wait on a download; installing is
--- `mise install`, run by me, in a terminal that shows it happening.
local probed
local function usable()
  if probed == nil then
    local ok, result = pcall(function()
      return vim
        .system({ "env", "MISE_SAFE=1", "MISE_AUTO_INSTALL=0", "mise", "exec", "--deny-net", "--", "true" }, {
          text = true,
          cwd = vim.fn.getcwd(),
        })
        :wait(10000)
    end)

    probed = ok and result.code == 0

    if not probed then
      off = "mise cannot run here; `mise exec -- true` in this directory says why"
      vim.schedule(function()
        vim.notify(("Language servers are not sandboxed: %s."):format(off), vim.log.levels.WARN)
      end)
    end
  end

  return probed
end

--- Whether the sandbox applies at all: `sandbox = false` in local.lua turns
--- it off for this machine or, through `projects`, for one directory.
local function enabled()
  if overrides.sandbox == false then
    off = "turned off in local.lua"
    return false
  end

  if vim.fn.executable("mise") ~= 1 then
    off = "mise is not installed"
    return false
  end

  return usable()
end

--- The directory holding `binary`, so the server can execute itself when it
--- lives somewhere the install list above does not cover (the `path` escape
--- hatch in local.lua points at exactly such a place).
local function home_of(binary)
  local path = binary:find("/", 1, true) and binary or vim.fn.exepath(binary)
  return path ~= "" and vim.fs.dirname(path) or nil
end

--- Wrap `cmd` in the sandbox `name`'s policy asks for. Returns `cmd`
--- unchanged when there is no policy, when mise is missing, or when the
--- overrides turn it off, so every caller can wrap unconditionally.
function M.wrap(name, cmd)
  local policy = POLICY[name]
  if not policy or not enabled() or type(cmd) ~= "table" or #cmd == 0 then
    return cmd
  end

  local o = (overrides.lsp or {})[name]
  if type(o) == "table" and o.sandbox == false then
    return cmd
  end

  local flags = {}
  local function flag(...)
    for _, value in ipairs({ ... }) do
      flags[#flags + 1] = value
    end
  end

  -- Reads: the workspace, wherever the server itself lives, and whatever
  -- the entry adds. One --allow-read is what turns reads into a whitelist,
  -- so this list is also the whole of what it can see.
  local reads = { vim.fn.getcwd() }
  vim.list_extend(reads, type(policy.read) == "function" and policy.read(vim.fn.getcwd()) or policy.read or {})

  if policy.net == false then
    flag("--deny-net")
  else
    reads[#reads + 1] = "/run/systemd/resolve"
  end

  local binary = home_of(cmd[1])
  if binary then
    reads[#reads + 1] = binary
  end

  -- mise warns about a rule for a path that is not there, and that warning
  -- lands on the server's stderr and in the LSP log. Nothing is lost by
  -- leaving out what does not exist yet.
  for _, path in ipairs(reads) do
    if vim.uv.fs_stat(path) then
      flag("--allow-read", path)
    end
  end

  local writes = vim.list_slice(policy.write or {})
  if policy.project then
    writes[#writes + 1] = vim.fn.getcwd()
  end

  if policy.go then
    vim.list_extend(writes, go_caches())
  end

  if policy.own and binary then
    -- The entry rather than the bin/ inside it, since that is where the
    -- cache goes. Servers whose executable sits at the entry root get the
    -- same directory either way.
    writes[#writes + 1] = vim.fs.basename(binary) == "bin" and vim.fs.dirname(binary) or binary
  end

  writes = vim.tbl_filter(function(path)
    return vim.uv.fs_stat(path) ~= nil
  end, writes)

  if #writes > 0 then
    for _, path in ipairs(writes) do
      flag("--allow-write", path)
    end
  else
    flag("--deny-write")
  end

  if policy.env then
    for _, pattern in ipairs(policy.env) do
      flag("--allow-env", pattern)
    end
  else
    flag("--deny-env")
  end

  -- MISE_SAFE, because the wrapper must not care what the workspace's own
  -- mise config says. Without it, an untrusted or malformed mise.toml in the
  -- project makes `mise exec` refuse before the server ever starts, and every
  -- language server dies with an error about trust (measured 2026-08-15).
  -- Safe mode makes that config inert, which is all this needs: the sandbox
  -- comes from the flags, and the environment came from lua/mivn/env.lua
  -- before any of this ran.
  local wrapped = { "env", "MISE_SAFE=1", "MISE_AUTO_INSTALL=0" }
  for name, value in vim.spairs(policy.setenv or {}) do
    wrapped[#wrapped + 1] = ("%s=%s"):format(name, value)
    flag("--allow-env", name)
  end

  vim.list_extend(wrapped, { "mise", "exec" })
  vim.list_extend(wrapped, flags)
  wrapped[#wrapped + 1] = "--"

  return vim.list_extend(wrapped, cmd)
end

--- Whether `name` is sandboxed, for lua/mivn/health.lua.
function M.covers(name)
  return POLICY[name] ~= nil and enabled()
end

--- Why nothing is sandboxed, when nothing is; nil while it works. Also for
--- lua/mivn/health.lua.
function M.off()
  enabled()
  return off
end

return M
