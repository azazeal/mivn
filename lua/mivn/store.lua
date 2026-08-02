-- The language-server store: mivn downloads, verifies and spawns its own
-- server binaries instead of expecting them on PATH.
--
-- One entry is one immutable directory, `servers/<name>/v<version>` under
-- stdpath("data"), holding the executable under its own name. An install
-- builds the entry in a staging directory on the same filesystem and
-- renames it into place, so a crash leaves staging litter but never a half
-- entry, and two instances racing at worst find the entry already there
-- and call that success. A version bump changes the directory name, so old
-- and new coexist until the sweep gets to the old one.
--
-- Installs and sweeps serialize across Neovim instances through one coarse
-- lock file created with O_CREAT|O_EXCL, the owner's PID inside; a lock
-- whose owner is dead is taken over. Reclamation is lazy on purpose:
-- turning a server off deletes nothing, the next sweep marks the unwanted
-- entry condemned, and only a sweep a week later deletes it. That makes
-- on/off flip-flops free and keeps an instance still running yesterday's
-- version from having its binary swept mid-session.
--
-- Linux and macOS, x86_64 and arm64. Downloads need curl and tar, both on
-- stock installs of either OS; checksums go through vim.fn.sha256, so no
-- platform hashing tool is involved. The Linux assets are the musl builds:
-- static, so the host's libc cannot disagree.

local M = {}

local uv = vim.uv

--- The manifest ---------------------------------------------------------------

-- Pinned the way plugins.lua pins plugins: an exact version, and a sha256
-- per platform, keyed by the target triple the release names its assets
-- after. `url` receives the triple; `args` is the argv after the binary.
-- One opinionated server per language. The weekly repin workflow will grow
-- a job that bumps these pins.
local SERVERS = {
  -- Python: types, completion, navigation.
  ty = {
    version = "0.0.65",
    url = "https://github.com/astral-sh/ty/releases/download/0.0.65/ty-%s.tar.gz",
    args = { "server" },
    sha256 = {
      ["aarch64-apple-darwin"] = "528f0eb7564ac42dded760762c94ee48d107752874c5697af2f7a49e3db244ba",
      ["x86_64-apple-darwin"] = "17f5eabf61e2cf9973a2fd6807367d491e4a684cb3566802d151713f65ca429a",
      ["aarch64-unknown-linux-musl"] = "1f8b79699a6639b1aaad31a86941482064d5390236271b6188144e2ddf981ab0",
      ["x86_64-unknown-linux-musl"] = "5f90d8da23f1d9ab54baafa3abf4c70c947e0e925440da3b84afd2d0d515d969",
    },
  },

  -- Python: linting and formatting, beside ty.
  ruff = {
    version = "0.16.1",
    url = "https://github.com/astral-sh/ruff/releases/download/0.16.1/ruff-%s.tar.gz",
    args = { "server" },
    sha256 = {
      ["aarch64-apple-darwin"] = "a8df4e8e9f22e3b0ae0b9f165ddaafb7e34df692197a6c1a361e7426f90681d5",
      ["x86_64-apple-darwin"] = "00396fb9db4cb04e07ad277e6b10d845e6767f0a2aae67e1a57aa65fa01334f0",
      ["aarch64-unknown-linux-musl"] = "5929d9f37fc518a3825f33a76ad8092c0555ca045ca1dbf5e680038a402c840c",
      ["x86_64-unknown-linux-musl"] = "23469683052cd2db1589f15032dd1751b2a3f212062e9fc901b0776d25fb36bc",
    },
  },
}

M.manifest = SERVERS

--- The target triple for this host, or nil and the reason it has none.
function M.supported()
  local u = uv.os_uname()
  local arch = ({ x86_64 = "x86_64", arm64 = "aarch64", aarch64 = "aarch64" })[u.machine]

  if not arch then
    return nil, ("unsupported architecture %s"):format(u.machine)
  elseif u.sysname == "Darwin" then
    return arch .. "-apple-darwin"
  elseif u.sysname == "Linux" then
    return arch .. "-unknown-linux-musl"
  end

  return nil, ("unsupported OS %s"):format(u.sysname)
end

--- The store itself -----------------------------------------------------------

local root = vim.fs.joinpath(vim.fn.stdpath("data"), "servers")
local lock_path = vim.fs.joinpath(root, ".lock")
local staging_root = vim.fs.joinpath(root, ".staging")

local function entry_dir(name)
  return vim.fs.joinpath(root, name, "v" .. SERVERS[name].version)
end

--- The absolute argv for `name`, or nil while its pinned version is not in
--- the store. Nothing here consults PATH.
function M.resolve(name)
  local spec = SERVERS[name]
  local bin = vim.fs.joinpath(entry_dir(name), name)

  if not uv.fs_stat(bin) then
    return nil
  end

  local cmd = { bin }
  vim.list_extend(cmd, spec.args or {})
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

  local sha = spec.sha256[target]
  if not sha then
    return cb(("%s %s has no %s build"):format(name, spec.version, target))
  end

  for _, tool in ipairs({ "curl", "tar" }) do
    if vim.fn.executable(tool) ~= 1 then
      return cb(tool .. " is not installed, and downloading needs it")
    end
  end

  if installing[name] then
    return cb(name .. " is already being installed")
  end
  installing[name] = true

  local dest = entry_dir(name)
  local staging = vim.fs.joinpath(staging_root, ("%s-%d"):format(name, uv.os_getpid()))
  local archive = vim.fs.joinpath(staging, "archive.tar.gz")
  local extracted = vim.fs.joinpath(staging, "extracted")
  local final = vim.fs.joinpath(staging, "final")

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

    local function place()
      vim.fn.mkdir(vim.fs.dirname(dest), "p")
      local ok, err = uv.fs_rename(final, dest)
      if not ok then
        return finish(("could not move %s into the store: %s"):format(name, err))
      end
      finish()
    end

    local function smoke()
      local bin = vim.fs.joinpath(final, name)
      vim.system({ bin, "--version" }, { text = true, timeout = 10000 }, function(result)
        vim.schedule(function()
          if result.code ~= 0 then
            return finish(
              ("%s does not run on this host (exit %d): %s"):format(name, result.code, vim.trim(result.stderr or ""))
            )
          end
          place()
        end)
      end)
    end

    local function stage()
      -- The entry keeps one file, the executable, renamed to the server's
      -- own name so resolve() needs no knowledge of the archive's layout.
      local bin = vim.fs.find(name, { path = extracted, type = "file", limit = 1 })[1]
      if not bin then
        return finish(("the %s archive holds no file named %s"):format(name, name))
      end

      uv.fs_chmod(bin, 493) -- 0755; tar keeps the bit, but belt and braces
      local ok, err = uv.fs_rename(bin, vim.fs.joinpath(final, name))
      if not ok then
        return finish(("could not stage %s: %s"):format(name, err))
      end
      smoke()
    end

    local function extract()
      vim.system({ "tar", "-xzf", archive, "-C", extracted }, { text = true }, function(result)
        vim.schedule(function()
          if result.code ~= 0 then
            return finish(("could not unpack %s: %s"):format(name, vim.trim(result.stderr or "")))
          end
          stage()
        end)
      end)
    end

    local function verify()
      local data = slurp(archive)
      if not data or vim.fn.sha256(data) ~= sha then
        return finish(("the %s download does not match its pinned sha256"):format(name))
      end
      extract()
    end

    local url = spec.url:format(target)
    vim.system(
      { "curl", "--fail", "--silent", "--show-error", "--location", "--retry", "3", "--output", archive, url },
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
