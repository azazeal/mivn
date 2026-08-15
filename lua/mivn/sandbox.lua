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

--- Where servers live. Neither is under a path mise's sandbox allows by
--- default, so a server cannot execute itself without these.
--- The store. mise grants its own installs directory read access already,
--- so only Neovim's needs naming.
local STORE = vim.fs.joinpath(vim.fn.stdpath("data"), "servers")

--- A directory beside Neovim's own under XDG_CACHE_HOME, which is where the
--- servers that keep a cache keep it. Normalised because a `..` left in the
--- middle is a path Landlock takes literally.
local function cache(name)
  return vim.fs.normalize(vim.fs.joinpath(vim.fn.stdpath("cache"), "..", name))
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
---   own    lets the server write inside its own installed copy. Only
---          lua-language-server needs it: it keeps a parse cache and a lock
---          under `<entry>/log/cache/<pid>` and exits 1 when it cannot
---          create them (measured 2026-08-15). The grant is that one
---          version's directory, not the store.
---   read   extra readable paths, on top of the workspace and the install
---          directories above. mise already allows /usr, /lib, /bin, /etc,
---          /proc, /sys and /home/linuxbrew.
---   env    the variable patterns that survive; absent keeps only mise's
---          floor of PATH, HOME, USER, SHELL, TERM, COLORTERM and LANG.
local POLICY = {
  -- buf unpacks the well-known protobuf types into its cache and exits 1
  -- when it cannot (measured 2026-08-15).
  buf_ls = { net = false, write = { cache("buf") } },
  docker_language_server = { net = false },
  lua_ls = { net = false, own = true },
  marksman = { net = false },
  superhtml = { net = false },

  -- The one server here that keeps the network: it resolves the schema a
  -- `#:schema` line names, or one its catalog matches by file name, and
  -- validates against it. Denying the network turns every mise.toml and
  -- Cargo.toml back into unchecked text (measured 2026-08-15).
  taplo = {},
  terraformls = { net = false },
  tsgo = { net = false },
}

--- Whether the sandbox applies at all: `sandbox = false` in local.lua turns
--- it off for this machine or, through `projects`, for one directory.
local function enabled()
  return overrides.sandbox ~= false and vim.fn.executable("mise") == 1
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
  local reads = { vim.fn.getcwd(), STORE }
  vim.list_extend(reads, policy.read or {})

  if policy.net == false then
    flag("--deny-net")
  else
    reads[#reads + 1] = "/run/systemd/resolve"
  end

  local binary = home_of(cmd[1])
  if binary then
    reads[#reads + 1] = binary
  end

  for _, path in ipairs(reads) do
    flag("--allow-read", path)
  end

  local writes = vim.list_slice(policy.write or {})
  if policy.own and binary then
    -- The entry rather than the bin/ inside it, since that is where the
    -- cache goes. Servers whose executable sits at the entry root get the
    -- same directory either way.
    writes[#writes + 1] = vim.fs.basename(binary) == "bin" and vim.fs.dirname(binary) or binary
  end

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
  local wrapped = { "env", "MISE_SAFE=1", "mise", "exec" }
  vim.list_extend(wrapped, flags)
  wrapped[#wrapped + 1] = "--"

  return vim.list_extend(wrapped, cmd)
end

--- Whether `name` is sandboxed, for lua/mivn/health.lua.
function M.covers(name)
  return POLICY[name] ~= nil and enabled()
end

return M
