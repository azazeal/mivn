-- The language-server store: mivn downloads, verifies and spawns its own
-- server binaries instead of expecting them on PATH.
--
-- One entry is one immutable directory, `servers/<name>/v<version>` under
-- stdpath("data"), holding either the executable alone or, for servers
-- that need files beside it, the whole unpacked archive. An install builds
-- the entry in a staging directory on the same filesystem and renames it
-- into place, so a crash leaves staging litter but never a half entry, and
-- two instances racing at worst find the entry already there and call that
-- success. A version bump changes the directory name, so old and new
-- coexist until the sweep gets to the old one.
--
-- Installs and sweeps serialize across Neovim instances through one coarse
-- lock file created with O_CREAT|O_EXCL, the owner's PID inside; a lock
-- whose owner is dead is taken over. Reclamation is lazy on purpose:
-- turning a server off deletes nothing, the next sweep marks the unwanted
-- entry condemned, and only a sweep a week later deletes it. That makes
-- on/off flip-flops free and keeps an instance still running yesterday's
-- version from having its binary swept mid-session.
--
-- Linux and macOS, x86_64 and arm64. Downloads need curl, archives need
-- tar, gzip or unzip by their kind, all present on stock installs of
-- either OS except unzip on minimal Linux; checksums go through
-- vim.fn.sha256, so no platform hashing tool is involved.

local M = {}

local uv = vim.uv

--- The manifest ---------------------------------------------------------------

-- Pinned the way plugins.lua pins plugins: an exact version and, per
-- platform, the asset URL and its sha256. `args` is the argv after the
-- binary. The optional fields:
--
--   binary   what the executable is called, when that is not the server's
--            own name (buf_ls runs `buf`).
--   bin      set when the whole archive is the entry, because the server
--            needs files beside its executable; the value is the
--            executable's path inside the archive.
--   smoke    how the freshly staged binary proves it runs: the argv after
--            it for a one-shot run, false for a binary with no harmless
--            flag. Defaults to { "--version" }.
--
-- How a download unpacks follows its URL: .tar.* and .tgz go through tar,
-- a bare .gz is a gzipped single binary, .zip needs unzip, and anything
-- else already is the binary. One opinionated server per language. The
-- weekly repin workflow will grow a job that bumps these pins.
local SERVERS = {
  -- Python: types, completion, navigation.
  ty = {
    version = "0.0.65",
    args = { "server" },
    platforms = {
      ["x86_64-linux"] = {
        url = "https://github.com/astral-sh/ty/releases/download/0.0.65/ty-x86_64-unknown-linux-musl.tar.gz",
        sha256 = "5f90d8da23f1d9ab54baafa3abf4c70c947e0e925440da3b84afd2d0d515d969",
      },
      ["aarch64-linux"] = {
        url = "https://github.com/astral-sh/ty/releases/download/0.0.65/ty-aarch64-unknown-linux-musl.tar.gz",
        sha256 = "1f8b79699a6639b1aaad31a86941482064d5390236271b6188144e2ddf981ab0",
      },
      ["x86_64-darwin"] = {
        url = "https://github.com/astral-sh/ty/releases/download/0.0.65/ty-x86_64-apple-darwin.tar.gz",
        sha256 = "17f5eabf61e2cf9973a2fd6807367d491e4a684cb3566802d151713f65ca429a",
      },
      ["aarch64-darwin"] = {
        url = "https://github.com/astral-sh/ty/releases/download/0.0.65/ty-aarch64-apple-darwin.tar.gz",
        sha256 = "528f0eb7564ac42dded760762c94ee48d107752874c5697af2f7a49e3db244ba",
      },
    },
  },

  -- Python: linting and formatting, beside ty.
  ruff = {
    version = "0.16.1",
    args = { "server" },
    platforms = {
      ["x86_64-linux"] = {
        url = "https://github.com/astral-sh/ruff/releases/download/0.16.1/ruff-x86_64-unknown-linux-musl.tar.gz",
        sha256 = "23469683052cd2db1589f15032dd1751b2a3f212062e9fc901b0776d25fb36bc",
      },
      ["aarch64-linux"] = {
        url = "https://github.com/astral-sh/ruff/releases/download/0.16.1/ruff-aarch64-unknown-linux-musl.tar.gz",
        sha256 = "5929d9f37fc518a3825f33a76ad8092c0555ca045ca1dbf5e680038a402c840c",
      },
      ["x86_64-darwin"] = {
        url = "https://github.com/astral-sh/ruff/releases/download/0.16.1/ruff-x86_64-apple-darwin.tar.gz",
        sha256 = "00396fb9db4cb04e07ad277e6b10d845e6767f0a2aae67e1a57aa65fa01334f0",
      },
      ["aarch64-darwin"] = {
        url = "https://github.com/astral-sh/ruff/releases/download/0.16.1/ruff-aarch64-apple-darwin.tar.gz",
        sha256 = "a8df4e8e9f22e3b0ae0b9f165ddaafb7e34df692197a6c1a361e7426f90681d5",
      },
    },
  },

  -- Protocol Buffers.
  buf_ls = {
    version = "1.72.0",
    binary = "buf",
    args = { "lsp", "serve", "--log-format=text" },
    platforms = {
      ["x86_64-linux"] = {
        url = "https://github.com/bufbuild/buf/releases/download/v1.72.0/buf-Linux-x86_64",
        sha256 = "8720830e26a733da55bb89bcd3cb44849c0965fc0c44fb5d691cccdc64dca5af",
      },
      ["aarch64-linux"] = {
        url = "https://github.com/bufbuild/buf/releases/download/v1.72.0/buf-Linux-aarch64",
        sha256 = "bdbb275fb9624104ef4d8513d269cc410a153138646e67136cb3f8cc185be289",
      },
      ["x86_64-darwin"] = {
        url = "https://github.com/bufbuild/buf/releases/download/v1.72.0/buf-Darwin-x86_64",
        sha256 = "eb815a2708d4a43d31799049d5a2987ea81d0a9e98b53976d47bd1e78d154a8f",
      },
      ["aarch64-darwin"] = {
        url = "https://github.com/bufbuild/buf/releases/download/v1.72.0/buf-Darwin-arm64",
        sha256 = "5176f23a6118b9978de1340c3e3301a4ed0d48e16a669510be44b4c355170d57",
      },
    },
  },

  -- Dockerfile, Compose and Bake files.
  docker_language_server = {
    version = "0.20.1",
    binary = "docker-language-server",
    args = { "start", "--stdio" },
    platforms = {
      ["x86_64-linux"] = {
        url = "https://github.com/docker/docker-language-server/releases/download/v0.20.1/docker-language-server-linux-amd64-v0.20.1",
        sha256 = "01907aa5b0eae11e44cffea0a993d08aa155542a9af570295dd1dff39e67692a",
      },
      ["aarch64-linux"] = {
        url = "https://github.com/docker/docker-language-server/releases/download/v0.20.1/docker-language-server-linux-arm64-v0.20.1",
        sha256 = "bd56c7815e0a22cfb708669f3d5e817de91d9b54039ff7e52867142a132ad8d7",
      },
      ["x86_64-darwin"] = {
        url = "https://github.com/docker/docker-language-server/releases/download/v0.20.1/docker-language-server-darwin-amd64-v0.20.1",
        sha256 = "2dbaec15645e940d1e02092f5b5e10148531a6206225e71faab7bfe71130b457",
      },
      ["aarch64-darwin"] = {
        url = "https://github.com/docker/docker-language-server/releases/download/v0.20.1/docker-language-server-darwin-arm64-v0.20.1",
        sha256 = "5a9d48fd2b1334d7d20a62faf542e611cca32dc79a478553ad65c27437467fac",
      },
    },
  },

  -- Elixir. A burrito build: the BEAM is inside the binary. No
  -- version flag exists, so no smoke run either.
  expert = {
    version = "0.1.8",
    args = { "--stdio" },
    smoke = false,
    platforms = {
      ["x86_64-linux"] = {
        url = "https://github.com/elixir-lang/expert/releases/download/v0.1.8/expert_linux_amd64",
        sha256 = "caf0ded54e83f318cfe659e2ac3dd1f2d2e71a1c1a3c28ab3290475954fd9aee",
      },
      ["aarch64-linux"] = {
        url = "https://github.com/elixir-lang/expert/releases/download/v0.1.8/expert_linux_arm64",
        sha256 = "d3df648c7fed17a962878f95444e2fcdf1c64cfa807a2d5221b558f5c85d86af",
      },
      ["x86_64-darwin"] = {
        url = "https://github.com/elixir-lang/expert/releases/download/v0.1.8/expert_darwin_amd64",
        sha256 = "289bcb6e0405962ae21fdc625c3b31a3226981e3c801092b4232eec856fe0fd4",
      },
      ["aarch64-darwin"] = {
        url = "https://github.com/elixir-lang/expert/releases/download/v0.1.8/expert_darwin_arm64",
        sha256 = "65b574eb64cbf3ccb0f5c1e0d8147e5f67f71f087a7a93c05ebec757659d4d72",
      },
    },
  },

  -- Lua. The server needs its whole tree (main.lua, meta/) beside the
  -- executable, so the entry is the unpacked archive.
  lua_ls = {
    version = "3.18.2",
    bin = "bin/lua-language-server",
    args = {},
    platforms = {
      ["x86_64-linux"] = {
        url = "https://github.com/LuaLS/lua-language-server/releases/download/3.18.2/lua-language-server-3.18.2-linux-x64.tar.gz",
        sha256 = "ca71415dd19f19e30aaa35a4915aefca9fdb5fec31b98331cc3d77f778d539c5",
      },
      ["aarch64-linux"] = {
        url = "https://github.com/LuaLS/lua-language-server/releases/download/3.18.2/lua-language-server-3.18.2-linux-arm64.tar.gz",
        sha256 = "273af33f26f4a1143f27c96d9f9e1188aba619c71e0807042134f66b4bd27f24",
      },
      ["x86_64-darwin"] = {
        url = "https://github.com/LuaLS/lua-language-server/releases/download/3.18.2/lua-language-server-3.18.2-darwin-x64.tar.gz",
        sha256 = "e26cfefe423dd7326fc7c649539e4d4aaa4f35f34d2fefd8af2ed7090b72c556",
      },
      ["aarch64-darwin"] = {
        url = "https://github.com/LuaLS/lua-language-server/releases/download/3.18.2/lua-language-server-3.18.2-darwin-arm64.tar.gz",
        sha256 = "cec99d70b1f612acec4a10a79a03664e3aa0c229d4d8a586cb3f928ec37d509e",
      },
    },
  },

  -- Markdown. The macos asset is one universal binary, hence the same
  -- URL for both darwin platforms.
  marksman = {
    version = "2026-02-08",
    args = { "server" },
    platforms = {
      ["x86_64-linux"] = {
        url = "https://github.com/artempyanykh/marksman/releases/download/2026-02-08/marksman-linux-x64",
        sha256 = "be5098e8213219269c47fc0d916a66fa31ce0602ec967475c722260aabf26087",
      },
      ["aarch64-linux"] = {
        url = "https://github.com/artempyanykh/marksman/releases/download/2026-02-08/marksman-linux-arm64",
        sha256 = "db8e124527f7f8048e3e6c91821b9c52ef173d92c01e47d221bf1337afd962fb",
      },
      ["x86_64-darwin"] = {
        url = "https://github.com/artempyanykh/marksman/releases/download/2026-02-08/marksman-macos",
        sha256 = "6a801c17b5ac0dba69787c5282b3b3bd416e66c96253fae098d311c6bbd1833b",
      },
      ["aarch64-darwin"] = {
        url = "https://github.com/artempyanykh/marksman/releases/download/2026-02-08/marksman-macos",
        sha256 = "6a801c17b5ac0dba69787c5282b3b3bd416e66c96253fae098d311c6bbd1833b",
      },
    },
  },

  -- Rust.
  rust_analyzer = {
    version = "2026-07-27",
    binary = "rust-analyzer",
    args = {},
    platforms = {
      ["x86_64-linux"] = {
        url = "https://github.com/rust-lang/rust-analyzer/releases/download/2026-07-27/rust-analyzer-x86_64-unknown-linux-musl.gz",
        sha256 = "4793930e0fe32f18ed7e8e689df3ebb03b632f76c16625c44754fb42ce39fc72",
      },
      ["aarch64-linux"] = {
        url = "https://github.com/rust-lang/rust-analyzer/releases/download/2026-07-27/rust-analyzer-aarch64-unknown-linux-gnu.gz",
        sha256 = "4cb0ca4675608e8d73a7f4e43ef733d1f69600845d504c35d2f9d9f240bd3486",
      },
      ["x86_64-darwin"] = {
        url = "https://github.com/rust-lang/rust-analyzer/releases/download/2026-07-27/rust-analyzer-x86_64-apple-darwin.gz",
        sha256 = "9d1a60991ead6c27baa9d265fc8fd03bba9c39cf0ec2aaf389e37e6155af7cbb",
      },
      ["aarch64-darwin"] = {
        url = "https://github.com/rust-lang/rust-analyzer/releases/download/2026-07-27/rust-analyzer-aarch64-apple-darwin.gz",
        sha256 = "102215ae7e7a41c0dda8f24e910a01e757f58091204863e5e3e6696b743f7e97",
      },
    },
  },

  -- HTML.
  superhtml = {
    version = "0.7.0",
    args = { "lsp" },
    smoke = { "version" },
    platforms = {
      ["x86_64-linux"] = {
        url = "https://github.com/kristoff-it/superhtml/releases/download/v0.7.0/x86_64-linux-musl.tar.xz",
        sha256 = "b75c6eeef539416096eac38729ee54e5f3b248f039cab4f57660f29a88742f68",
      },
      ["aarch64-linux"] = {
        url = "https://github.com/kristoff-it/superhtml/releases/download/v0.7.0/aarch64-linux.tar.xz",
        sha256 = "9fa2ed1ec830464c38929531693e7129ae6df3ccb1bb3f01fec3322ed5759fc5",
      },
      ["x86_64-darwin"] = {
        url = "https://github.com/kristoff-it/superhtml/releases/download/v0.7.0/x86_64-macos.zip",
        sha256 = "f7f502ce26f8163ec5257d2428192e3224eb21866129a4c05421bd5b2ea709f1",
      },
      ["aarch64-darwin"] = {
        url = "https://github.com/kristoff-it/superhtml/releases/download/v0.7.0/aarch64-macos.zip",
        sha256 = "3846e475290f917dbf5cde8f35faff85c4402279f6ad8a8f95a861bc6523a154",
      },
    },
  },

  -- TOML.
  taplo = {
    version = "0.10.0",
    args = { "lsp", "stdio" },
    platforms = {
      ["x86_64-linux"] = {
        url = "https://github.com/tamasfe/taplo/releases/download/0.10.0/taplo-linux-x86_64.gz",
        sha256 = "8fe196b894ccf9072f98d4e1013a180306e17d244830b03986ee5e8eabeb6156",
      },
      ["aarch64-linux"] = {
        url = "https://github.com/tamasfe/taplo/releases/download/0.10.0/taplo-linux-aarch64.gz",
        sha256 = "033681d01eec8376c3fd38fa3703c79316f5e14bb013d859943b60a07bccdcc3",
      },
      ["x86_64-darwin"] = {
        url = "https://github.com/tamasfe/taplo/releases/download/0.10.0/taplo-darwin-x86_64.gz",
        sha256 = "898122cde3a0b1cd1cbc2d52d3624f23338218c91b5ddb71518236a4c2c10ef2",
      },
      ["aarch64-darwin"] = {
        url = "https://github.com/tamasfe/taplo/releases/download/0.10.0/taplo-darwin-aarch64.gz",
        sha256 = "713734314c3e71894b9e77513c5349835eefbd52908445a0d73b0c7dc469347d",
      },
    },
  },

  -- Go templ files.
  templ = {
    version = "0.3.1020",
    args = { "lsp" },
    smoke = { "version" },
    platforms = {
      ["x86_64-linux"] = {
        url = "https://github.com/a-h/templ/releases/download/v0.3.1020/templ_Linux_x86_64.tar.gz",
        sha256 = "d1e726e8e78a6cf7e1e72ce3746f30fd94ec0eba10be1abab02208a41efc9aa5",
      },
      ["aarch64-linux"] = {
        url = "https://github.com/a-h/templ/releases/download/v0.3.1020/templ_Linux_arm64.tar.gz",
        sha256 = "8d38728fa82c0ee568d2ae1ce0720963402d384dd59d4c76bcdbb38d581c815c",
      },
      ["x86_64-darwin"] = {
        url = "https://github.com/a-h/templ/releases/download/v0.3.1020/templ_Darwin_x86_64.tar.gz",
        sha256 = "f1522f2558081335584fd4fb67d329d02a9ae6e83dd88b14cae1ad84c770e5c0",
      },
      ["aarch64-darwin"] = {
        url = "https://github.com/a-h/templ/releases/download/v0.3.1020/templ_Darwin_arm64.tar.gz",
        sha256 = "f391943e3e49ece301f90c2283c7f9e629081f18b0b3ab6b48cb4b87ad94b206",
      },
    },
  },

  -- Terraform.
  terraformls = {
    version = "0.39.0",
    binary = "terraform-ls",
    args = { "serve" },
    smoke = { "version" },
    platforms = {
      ["x86_64-linux"] = {
        url = "https://releases.hashicorp.com/terraform-ls/0.39.0/terraform-ls_0.39.0_linux_amd64.zip",
        sha256 = "7750edc736845fd8c04ff0fc6332423c12d8275b358668c8c17e8aedc43ef971",
      },
      ["aarch64-linux"] = {
        url = "https://releases.hashicorp.com/terraform-ls/0.39.0/terraform-ls_0.39.0_linux_arm64.zip",
        sha256 = "62f32ea22cb78e5e5667ed638ad6e0fbde30ab59228d073c3c9bb249f89c7f5a",
      },
      ["x86_64-darwin"] = {
        url = "https://releases.hashicorp.com/terraform-ls/0.39.0/terraform-ls_0.39.0_darwin_amd64.zip",
        sha256 = "cc5bbc5b5a39d12d455c0d2b1e4b3a2c1f237d02d2cf819cf5252358f2d674de",
      },
      ["aarch64-darwin"] = {
        url = "https://releases.hashicorp.com/terraform-ls/0.39.0/terraform-ls_0.39.0_darwin_arm64.zip",
        sha256 = "6f80fe0b34af184175508f3d9135d8159f5dce4000d9b39540553eb1c267c54b",
      },
    },
  },

  -- TypeScript and JavaScript: the TypeScript 7 compiler with the LSP
  -- inside, one native binary named tsc, plus the lib.*.d.ts files it
  -- needs beside it, so the entry is the unpacked package.
  tsgo = {
    version = "7.0.2",
    bin = "package/lib/tsc",
    args = { "--lsp", "--stdio" },
    platforms = {
      ["x86_64-linux"] = {
        url = "https://github.com/microsoft/typescript-go/releases/download/typescript%2Fv7.0.2/typescript-linux-x64.tgz",
        sha256 = "7ecad6f67377e831856367ab062ef394f21506a611405bf8ac0ff039348637d3",
      },
      ["aarch64-linux"] = {
        url = "https://github.com/microsoft/typescript-go/releases/download/typescript%2Fv7.0.2/typescript-linux-arm64.tgz",
        sha256 = "c83d931ac9dd7549cde6e71246aa9d6a9812843023df3e277fe3b5dcf41dd0ea",
      },
      ["x86_64-darwin"] = {
        url = "https://github.com/microsoft/typescript-go/releases/download/typescript%2Fv7.0.2/typescript-darwin-x64.tgz",
        sha256 = "eba158cb54050f723d5ff781438f33de5640054440bb4f2bd170cfe9bc2eb551",
      },
      ["aarch64-darwin"] = {
        url = "https://github.com/microsoft/typescript-go/releases/download/typescript%2Fv7.0.2/typescript-darwin-arm64.tgz",
        sha256 = "902e2fe1cf0799198ef902c6b8c310a450fef629a6baba41d45641ef75c04ebd",
      },
    },
  },
}

M.manifest = SERVERS

--- The platform key for this host, or nil and the reason it has none.
function M.supported()
  local u = uv.os_uname()
  local arch = ({ x86_64 = "x86_64", arm64 = "aarch64", aarch64 = "aarch64" })[u.machine]
  local os_name = ({ Linux = "linux", Darwin = "darwin" })[u.sysname]

  if not arch then
    return nil, ("unsupported architecture %s"):format(u.machine)
  elseif not os_name then
    return nil, ("unsupported OS %s"):format(u.sysname)
  end

  return arch .. "-" .. os_name
end

--- How the asset at `url` unpacks.
local function kind_of(url)
  if url:match("%.tar%.[a-z]+$") or url:match("%.tgz$") then
    return "tar"
  elseif url:match("%.gz$") then
    return "gz"
  elseif url:match("%.zip$") then
    return "zip"
  end

  return "raw"
end

--- The store itself -----------------------------------------------------------

local root = vim.fs.joinpath(vim.fn.stdpath("data"), "servers")
local lock_path = vim.fs.joinpath(root, ".lock")
local staging_root = vim.fs.joinpath(root, ".staging")

local function entry_dir(name)
  return vim.fs.joinpath(root, name, "v" .. SERVERS[name].version)
end

--- The executable's path inside `name`'s entry.
local function bin_path(name)
  local spec = SERVERS[name]
  return vim.fs.joinpath(entry_dir(name), spec.bin or spec.binary or name)
end

--- The absolute argv for `name`, or nil while its pinned version is not in
--- the store. Nothing here consults PATH.
function M.resolve(name)
  local bin = bin_path(name)

  if not uv.fs_stat(bin) then
    return nil
  end

  local cmd = { bin }
  vim.list_extend(cmd, SERVERS[name].args or {})
  return cmd
end

--- Read a whole file, or nil when it cannot be read.
local function slurp(path)
  local file = io.open(path, "rb")
  if not file then
    return nil
  end

  local data = file:read("*a")
  file:close()
  return data
end

--- Dialog answers, one file per machine ---------------------------------------

-- stdpath("state") and not "data": the store's contents are reproducible
-- from the manifest, the user's answers are not.
local consent_path = vim.fs.joinpath(vim.fn.stdpath("state"), "lsp-consent.json")

local consent

local function load_consent()
  if not consent then
    local ok, decoded = pcall(vim.json.decode, slurp(consent_path) or "")
    consent = ok and type(decoded) == "table" and decoded or {}
  end

  return consent
end

--- The persisted dialog answer for `name`: true, false, or nil for never
--- answered.
function M.consent(name)
  return load_consent()[name]
end

--- Persist `value` (true, false, or nil to forget) as the answer for `name`.
function M.set_consent(name, value)
  load_consent()[name] = value

  vim.fn.mkdir(vim.fs.dirname(consent_path), "p")
  local file = assert(io.open(consent_path, "w"))
  file:write(vim.json.encode(consent), "\n")
  file:close()
end

--- The lock -------------------------------------------------------------------

--- Take the store lock, or return false and the PID holding it. "wx" is
--- O_CREAT|O_EXCL, so creation is the atomic test-and-set; a lock whose
--- owner no longer runs is taken over, once, so two racing takeovers
--- cannot chase each other.
local function try_lock(retrying)
  vim.fn.mkdir(root, "p")

  local fd = uv.fs_open(lock_path, "wx", 384)
  if fd then
    uv.fs_write(fd, tostring(uv.os_getpid()))
    uv.fs_close(fd)
    return true
  end

  local pid = tonumber(slurp(lock_path) or "")
  if pid and pid ~= uv.os_getpid() and uv.kill(pid, 0) == 0 then
    return false, pid
  end

  if retrying then
    return false, pid or 0
  end

  -- Unreadable, left over from a previous life of this PID, or a dead
  -- owner: take it over.
  uv.fs_unlink(lock_path)
  return try_lock(true)
end

local function unlock()
  uv.fs_unlink(lock_path)
end

--- Run `fn` with the store locked, waiting for another instance to finish
--- first when one is mid-install. The wait is polled, announced once, and
--- bounded; `fn` owns releasing the lock, `on_fail(msg)` runs if it was
--- never taken.
local function with_lock(fn, on_fail)
  local deadline = uv.now() + 120000
  local announced = false

  local function attempt()
    local ok, pid = try_lock()
    if ok then
      return fn()
    end

    if uv.now() > deadline then
      return on_fail(("the store is still locked by PID %d"):format(pid))
    end

    if not announced then
      announced = true
      vim.notify(("The server store is locked by another Neovim (PID %d); waiting for it."):format(pid))
    end

    vim.defer_fn(attempt, 2000)
  end

  attempt()
end

--- Sweeping -------------------------------------------------------------------

-- A week of grace between condemning and deleting: an on/off flip-flop
-- costs nothing, and a version bump ages out instead of being yanked.
local GRACE = 7 * 24 * 60 * 60

--- Whether the overrides and the dialog answers still want `name`: only an
--- explicit No, an off, or an escape hatch makes garbage. `true` in the
--- overrides outranks an old No.
local function wanted(name)
  if not SERVERS[name] then
    return false
  end

  local o = (require("mivn.overrides").lsp or {})[name]
  if o == false or (type(o) == "table" and o.path) then
    return false
  end

  -- Any other declared entry is consent by itself and outranks an old No.
  return o ~= nil or M.consent(name) ~= false
end

--- One pass over the store, lock already held. Returns how many entries
--- were condemned and how many deleted.
local function sweep_locked()
  local condemned, deleted = 0, 0
  local now = os.time()

  if not uv.fs_stat(root) then
    return condemned, deleted
  end

  -- Staging litter first: a child is <name>-<pid>, and a dead PID is a
  -- crashed install.
  if uv.fs_stat(staging_root) then
    for child in vim.fs.dir(staging_root) do
      local pid = tonumber(child:match("%-(%d+)$"))
      if not pid or (pid ~= uv.os_getpid() and uv.kill(pid, 0) ~= 0) then
        vim.fs.rm(vim.fs.joinpath(staging_root, child), { recursive = true, force = true })
      end
    end
  end

  for name, kind in vim.fs.dir(root) do
    if kind == "directory" and not name:match("^%.") then
      local server_dir = vim.fs.joinpath(root, name)
      local keep = SERVERS[name] and wanted(name) and ("v" .. SERVERS[name].version)

      local empty = true
      for version, vkind in vim.fs.dir(server_dir) do
        if vkind ~= "directory" then
          empty = false
        else
          local entry = vim.fs.joinpath(server_dir, version)
          local marker = vim.fs.joinpath(entry, ".condemned")

          if version == keep then
            uv.fs_unlink(marker) -- a reprieve, if it was condemned before
            empty = false
          else
            local since = tonumber(slurp(marker) or "")
            if since and now - since > GRACE then
              vim.fs.rm(entry, { recursive = true, force = true })
              deleted = deleted + 1
            else
              if not since then
                local file = io.open(marker, "w")
                if file then
                  file:write(tostring(now))
                  file:close()
                end
                condemned = condemned + 1
              end
              empty = false
            end
          end
        end
      end

      if empty then
        uv.fs_rmdir(server_dir)
      end
    end
  end

  return condemned, deleted
end

--- A sweep on demand, taking the lock itself. `cb(err, condemned, deleted)`
--- runs on the main loop.
function M.sweep(cb)
  with_lock(function()
    local ok, condemned, deleted = pcall(sweep_locked)
    unlock()

    vim.schedule(function()
      if not ok then
        cb(tostring(condemned))
      else
        cb(nil, condemned, deleted)
      end
    end)
  end, cb)
end

--- Installing -----------------------------------------------------------------

-- Which tools each unpacking kind needs, checked before anything downloads.
local TOOLS = {
  tar = { "curl", "tar" },
  gz = { "curl", "gzip" },
  zip = { "curl", "unzip" },
  raw = { "curl" },
}

local installing = {}

--- Download, verify, smoke-run and stage `name` at its pinned version, then
--- rename the entry into place and sweep. `cb(err)` runs on the main loop,
--- with nil for success; finding the entry already installed is success.
--- `opts.force` rebuilds an entry that already exists.
function M.install(name, cb, opts)
  local spec = assert(SERVERS[name], name .. " is not in the manifest")

  local target, why = M.supported()
  if not target then
    return cb(why)
  end

  local plat = spec.platforms[target]
  if not plat then
    return cb(("%s %s has no %s build"):format(name, spec.version, target))
  end

  local kind = kind_of(plat.url)
  for _, tool in ipairs(TOOLS[kind]) do
    if vim.fn.executable(tool) ~= 1 then
      return cb(("%s is not installed, and this download needs it"):format(tool))
    end
  end

  if installing[name] then
    return cb(name .. " is already being installed")
  end
  installing[name] = true

  local binary = spec.binary or name
  local dest = entry_dir(name)
  local staging = vim.fs.joinpath(staging_root, ("%s-%d"):format(name, uv.os_getpid()))
  local extracted = vim.fs.joinpath(staging, "extracted")
  local final = vim.fs.joinpath(staging, "final")

  -- A gzipped single binary keeps its .gz name so `gzip -d` strips it;
  -- everything else downloads as an opaque asset.
  local asset = vim.fs.joinpath(staging, kind == "gz" and (binary .. ".gz") or "asset")

  local function give_up(err)
    installing[name] = nil
    vim.schedule(function()
      cb(err)
    end)
  end

  with_lock(function()
    -- The lock is held from here on; finish() is the only way out.
    local function finish(err)
      vim.fs.rm(staging, { recursive = true, force = true })
      if not err then
        pcall(sweep_locked)
      end
      unlock()
      give_up(err)
    end

    if uv.fs_stat(dest) then
      if not (opts and opts.force) then
        return finish() -- someone else won the race, and that is success
      end
      vim.fs.rm(dest, { recursive = true, force = true })
    end

    vim.fn.mkdir(extracted, "p")
    vim.fn.mkdir(final, "p")

    -- The steps run as a callback chain; every vim.system result hops back
    -- to the main loop before the next step touches the API.

    --- Rename `from` (the finished entry's content) into the store.
    local function place(from)
      vim.fn.mkdir(vim.fs.dirname(dest), "p")
      local ok, err = uv.fs_rename(from, dest)
      if not ok then
        return finish(("could not move %s into the store: %s"):format(name, err))
      end
      finish()
    end

    --- Prove the staged executable runs, then hand back to `next_step`.
    local function smoke(bin, next_step)
      if spec.smoke == false then
        return next_step()
      end

      local cmd = { bin }
      vim.list_extend(cmd, spec.smoke or { "--version" })
      vim.system(cmd, { text = true, timeout = 10000 }, function(result)
        vim.schedule(function()
          if result.code ~= 0 then
            return finish(
              ("%s does not run on this host (exit %d): %s"):format(name, result.code, vim.trim(result.stderr or ""))
            )
          end
          next_step()
        end)
      end)
    end

    --- The archive is unpacked (or the download already is the binary at
    --- `raw_bin`): make the entry out of it.
    local function stage(raw_bin)
      if spec.bin then
        -- The whole tree is the entry; the executable lives inside it.
        local bin = vim.fs.joinpath(extracted, spec.bin)
        if not uv.fs_stat(bin) then
          return finish(("the %s archive holds no %s"):format(name, spec.bin))
        end

        uv.fs_chmod(bin, 493) -- 0755
        return smoke(bin, function()
          place(extracted)
        end)
      end

      -- The entry keeps one file, the executable, under its own name, so
      -- resolve() needs no knowledge of the archive's layout.
      local bin = raw_bin or vim.fs.find(binary, { path = extracted, type = "file", limit = 1 })[1]
      if not bin then
        return finish(("the %s archive holds no file named %s"):format(name, binary))
      end

      uv.fs_chmod(bin, 493) -- 0755; archives keep the bit, but belt and braces
      local ok, err = uv.fs_rename(bin, vim.fs.joinpath(final, binary))
      if not ok then
        return finish(("could not stage %s: %s"):format(name, err))
      end

      smoke(vim.fs.joinpath(final, binary), function()
        place(final)
      end)
    end

    --- Unpack `asset` according to its kind, then stage.
    local function unpack()
      if kind == "raw" then
        return stage(asset)
      end

      local commands = {
        tar = { "tar", "-xf", asset, "-C", extracted },
        gz = { "gzip", "-d", asset }, -- leaves staging/<binary>
        zip = { "unzip", "-o", "-q", asset, "-d", extracted },
      }

      vim.system(commands[kind], { text = true }, function(result)
        vim.schedule(function()
          if result.code ~= 0 then
            return finish(("could not unpack %s: %s"):format(name, vim.trim(result.stderr or "")))
          end
          stage(kind == "gz" and vim.fs.joinpath(staging, binary) or nil)
        end)
      end)
    end

    local function verify()
      local data = slurp(asset)
      if not data or vim.fn.sha256(data) ~= plat.sha256 then
        return finish(("the %s download does not match its pinned sha256"):format(name))
      end
      unpack()
    end

    vim.system(
      { "curl", "--fail", "--silent", "--show-error", "--location", "--retry", "3", "--output", asset, plat.url },
      { text = true },
      function(result)
        vim.schedule(function()
          if result.code ~= 0 then
            return finish(("downloading %s failed: %s"):format(name, vim.trim(result.stderr or "")))
          end
          verify()
        end)
      end
    )
  end, give_up)
end

return M
