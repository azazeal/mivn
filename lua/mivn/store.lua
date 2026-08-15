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
-- either OS except unzip on minimal Linux; checksums prefer the platform's
-- sha256sum or shasum, which read the file off the main thread, and fall
-- back to vim.fn.sha256 when neither exists.

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

local held = false -- whether *this instance* holds the on-disk lock

--- Take the store lock, or return false and the PID holding it.
---
--- The lock is born with its owner's PID already inside: the PID goes into
--- a private file first, and hard-linking that into place is the atomic
--- test-and-set (the link fails when a lock exists), so no reader ever
--- sees a half-written lock. A lock whose owner is dead is claimed by
--- renaming it aside; a rename succeeds for exactly one claimant, so two
--- takeovers cannot both proceed, and the loser goes back to waiting.
---
--- `held` tells "this process owns the lock" apart from "a previous life
--- of this PID left it behind", which the file alone cannot; without it, a
--- second install in this instance would steal the first one's lock. One
--- edge stays open knowingly: kill(pid, 0) cannot tell a recycled PID from
--- the original owner, so a stale lock whose PID now names some unrelated
--- process waits out the bounded poll instead of being claimed.
local function try_lock()
  if held then
    return false, uv.os_getpid()
  end

  vim.fn.mkdir(root, "p")

  local temp = lock_path .. "." .. uv.os_getpid()
  local fd = uv.fs_open(temp, "w", 384)
  if not fd then
    return false, 0
  end
  uv.fs_write(fd, tostring(uv.os_getpid()))
  uv.fs_close(fd)

  local linked = uv.fs_link(temp, lock_path)
  uv.fs_unlink(temp)
  if linked then
    held = true
    return true
  end

  local pid = tonumber(slurp(lock_path) or "")
  if pid and pid ~= uv.os_getpid() and uv.kill(pid, 0) == 0 then
    return false, pid
  end

  -- A dead owner, or a previous life of this PID. Reap it; losing the
  -- rename means another instance is reaping it right now, and either way
  -- the next attempt finds the way clear.
  local reaped = lock_path .. ".reaped." .. uv.os_getpid()
  if uv.fs_rename(lock_path, reaped) then
    uv.fs_unlink(reaped)
  end

  return false, pid or 0
end

local function unlock()
  held = false
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
      vim.notify(("The server store is locked by an install in progress (PID %d); waiting for it."):format(pid))
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

  -- Lock litter next: `.lock.<pid>` temp files a crash left mid-take.
  for child, kind in vim.fs.dir(root) do
    local pid = tonumber(child:match("^%.lock%..*(%d+)$"))
    if kind == "file" and pid and pid ~= uv.os_getpid() and uv.kill(pid, 0) ~= 0 then
      uv.fs_unlink(vim.fs.joinpath(root, child))
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

-- Before this, sweeping only ever ran after a successful install, so a
-- stable config never even condemned the entries of a server turned off:
-- the grace week never started counting.
local stamp_path = vim.fs.joinpath(root, ".swept")

--- A sweep on its own schedule: at most one a day across all instances,
--- deferred well past startup so launching the editor stays instant.
--- Wired up by lua/mivn/lsp/managed.lua.
function M.autosweep()
  local last = tonumber(slurp(stamp_path) or "")
  if last and os.time() - last < 24 * 60 * 60 then
    return
  end

  vim.defer_fn(function()
    M.sweep(function(err)
      if err then
        return -- a locked store means another instance got there first
      end

      local file = io.open(stamp_path, "w")
      if file then
        file:write(tostring(os.time()))
        file:close()
      end
    end)
  end, 30000)
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

  -- tar hands .xz decompression to xz, which minimal hosts lack; better
  -- said here than found later in tar's stderr.
  if kind == "tar" and plat.url:match("%.xz$") and vim.fn.executable("xz") ~= 1 then
    return cb("xz is not installed, and this download needs it")
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
    -- The lock is held from here on; finish() is the only way out, the only
    -- place that releases it, and one-shot, so a straggling callback cannot
    -- release somebody else's turn.
    local finished = false
    local function finish(err)
      if finished then
        return
      end
      finished = true

      pcall(vim.fs.rm, staging, { recursive = true, force = true })
      if not err then
        pcall(sweep_locked)
      end
      unlock()
      give_up(err)
    end

    --- Every re-entry from the event loop runs through this: an error
    --- thrown anywhere in the chain must land in finish() and release the
    --- lock, not escape into the editor with the store wedged for every
    --- instance until this one exits.
    local function guarded(f)
      return function(...)
        local ok, err = pcall(f, ...)
        if not ok then
          finish(("installing %s died: %s"):format(name, err))
        end
      end
    end

    guarded(function()
      if uv.fs_stat(dest) then
        if not (opts and opts.force) then
          return finish() -- someone else won the race, and that is success
        end
        vim.fs.rm(dest, { recursive = true, force = true })
      end

      vim.fn.mkdir(extracted, "p")
      vim.fn.mkdir(final, "p")
    end)()

    if finished then
      return
    end

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

      -- A binary that cannot start at all fails in the spawn itself, not in
      -- the result, and that error would escape the callback chain with the
      -- lock still held. It is the same answer as a bad exit: not this host.
      -- The dynamically linked build published under a "musl" name is how
      -- this was found.
      local ok, err = pcall(vim.system, cmd, { text = true, timeout = 10000 }, function(result)
        vim.schedule(guarded(function()
          if result.code ~= 0 then
            return finish(
              ("%s does not run on this host (exit %d): %s"):format(name, result.code, vim.trim(result.stderr or ""))
            )
          end
          next_step()
        end))
      end)

      if not ok then
        finish(("%s does not run on this host: %s"):format(name, err))
      end
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
        vim.schedule(guarded(function()
          if result.code ~= 0 then
            return finish(("could not unpack %s: %s"):format(name, vim.trim(result.stderr or "")))
          end
          stage(kind == "gz" and vim.fs.joinpath(staging, binary) or nil)
        end))
      end)
    end

    --- Compare the download against its pinned sha256, then unpack.
    ---
    --- The platform's hashing tool reads the file itself, off the main
    --- thread; both OSes ship one. The fallback slurps the asset into a
    --- string for vim.fn.sha256, which stalls the editor for the biggest
    --- archives, so it is exactly that: the fallback.
    local function verify()
      local hasher
      if vim.fn.executable("sha256sum") == 1 then
        hasher = { "sha256sum", asset }
      elseif vim.fn.executable("shasum") == 1 then
        hasher = { "shasum", "-a", "256", asset }
      end

      if not hasher then
        local data = slurp(asset)
        if not data or vim.fn.sha256(data) ~= plat.sha256 then
          return finish(("the %s download does not match its pinned sha256"):format(name))
        end
        return unpack()
      end

      vim.system(hasher, { text = true }, function(result)
        vim.schedule(guarded(function()
          local sum = result.code == 0 and (result.stdout or ""):match("^%x+")
          if sum ~= plat.sha256 then
            return finish(("the %s download does not match its pinned sha256"):format(name))
          end
          unpack()
        end))
      end)
    end

    vim.system(
      { "curl", "--fail", "--silent", "--show-error", "--location", "--retry", "3", "--output", asset, plat.url },
      { text = true },
      function(result)
        vim.schedule(guarded(function()
          if result.code ~= 0 then
            return finish(("downloading %s failed: %s"):format(name, vim.trim(result.stderr or "")))
          end
          verify()
        end))
      end
    )
  end, give_up)
end

return M
