-- Whether a newer mivn is out.
--
-- The config directory is a git clone, so "newer" means a release tag the
-- remote has and this checkout does not. The whole check is one `git
-- ls-remote` against the repository's public https URL: it fetches nothing,
-- writes nothing into the repository, and takes the network at most once a
-- day, with the answer kept in a small file under stdpath("state").
--
-- Releases, not commits, on purpose. A commit on main means I pushed
-- something, which on my own config is most of the time; a tag means I decided
-- it was good, which is the only thing worth interrupting anyone about. It
-- also keeps this quiet on the machine I write mivn on, where HEAD is usually
-- ahead of the newest tag.
--
-- It must never touch an ssh key. A global gitconfig can rewrite the https
-- URL to ssh (url.<base>.insteadOf), and a background git on a machine whose
-- agent holds no key then hangs on a passphrase prompt nothing is drawing. So
-- GIT_CONFIG_GLOBAL=/dev/null drops the rewrite for these subprocesses alone,
-- and GIT_TERMINAL_PROMPT=0 turns any prompt that still finds a way through
-- into a failure instead of a hang. Never set either for the whole process:
-- :terminal must keep my real git config.
--
-- Nothing updates itself. The notice is the feature, and :MivnUpdate is me
-- saying yes to it: a fast-forward onto the release the notice named, refused
-- outright if this checkout has anything of its own in it, and never a
-- restart. Neovim is running the Lua it loaded at startup, so moving the files
-- under a live session changes nothing that is read again until :restart, and
-- the pins in plugins.lua move without the plugins moving with them. Both of
-- those are for me to do, once I am ready.

local M = {}

local CACHE = vim.fs.joinpath(vim.fn.stdpath("state"), "update.json")
local TTL = 24 * 60 * 60

--- git, with the environment that keeps it off ssh and off any prompt.
local function git(args, on_exit)
  return vim.system(args, {
    text = true,
    timeout = 10000,
    env = { GIT_CONFIG_GLOBAL = "/dev/null", GIT_TERMINAL_PROMPT = "0" },
  }, on_exit)
end

--- git inside the config directory, for the questions with local answers.
local function here(args)
  local out = git(vim.list_extend({ "git", "-C", vim.fn.stdpath("config") }, args)):wait(5000)
  if out.code ~= 0 then
    return nil
  end

  local value = vim.trim(out.stdout)
  return value ~= "" and value or nil
end

--- The release this checkout is on, or nil when it is not a clone, has no
--- tags, or sits on something no release describes.
---
--- `false` is the "asked once, got nothing" marker; nil alone would ask git
--- again on every dashboard render.
local installed
local function version()
  if installed == nil then
    installed = here({ "describe", "--tags", "--abbrev=0" }) or false
  end

  return installed or nil
end

--- The public https URL for origin, whatever form origin is written in.
---
--- ssh://git@github.com/o/r.git, git@github.com:o/r.git and the https URL all
--- name the same repository, and only the last of the three can be read
--- without a key.
local function url()
  local remote = here({ "remote", "get-url", "origin" })
  if not remote then
    return nil
  end

  local path = remote:match("github%.com[:/](.+)$")
  if not path then
    return nil
  end

  return ("https://github.com/%s"):format((path:gsub("%.git$", "")))
end

--- The newest of `names`, as a "v1.2.3" string.
---
--- Prereleases are skipped: I do not want to be told about an rc, and I do not
--- want to be moved onto one either. The remote's tags and this checkout's own
--- go through here alike, so both ends of the comparison agree on what the
--- newest release is.
local function newest(names)
  local best

  for _, name in ipairs(names) do
    local parsed = vim.version.parse(name)
    if parsed and not parsed.prerelease and (not best or vim.version.gt(parsed, best)) then
      best = parsed
    end
  end

  return best and ("v%s"):format(tostring(best)) or nil
end

--- The tag names in ls-remote output.
---
--- Annotated tags come back twice, the second as refs/tags/<name>^{} for the
--- commit they point at; the suffix comes off and the duplicate loses to
--- itself.
local function advertised(stdout)
  local names = {}

  for tag in stdout:gmatch("refs/tags/(%S+)") do
    names[#names + 1] = (tag:gsub("%^{}$", ""))
  end

  return names
end

local function read()
  local file = io.open(CACHE, "r")
  if not file then
    return {}
  end

  local raw = file:read("*a")
  file:close()

  local ok, data = pcall(vim.json.decode, raw)
  return (ok and type(data) == "table") and data or {}
end

local function write(data)
  local file = io.open(CACHE, "w")
  if not file then
    return
  end

  file:write(vim.json.encode(data))
  file:close()
end

local cached
local function state()
  if not cached then
    cached = read()
  end

  return cached
end

--- What is known right now, without asking anything: the release in use, the
--- newest release the last check saw, and when that check ran.
function M.report()
  local known = state()

  return {
    current = version(),
    latest = known.latest,
    checked = known.checked,
  }
end

--- The report, but only when there is something newer to say. nil otherwise,
--- which is what every caller draws nothing for.
function M.status()
  local report = M.report()
  if not (report.current and report.latest) then
    return nil
  end

  if not vim.version.gt(report.latest, report.current) then
    return nil
  end

  return report
end

--- Ask the remote, unless the last answer is still fresh.
---
--- Silent about failures on purpose: no network, no route, a repository that
--- moved. None of that is worth a message while I am trying to edit, and the
--- next session asks again.
local asking = false

function M.check(force)
  if asking then
    return
  end

  local known = state()
  if not force and known.checked and os.time() - known.checked < TTL then
    return
  end

  local remote = url()
  if not remote then
    return
  end

  asking = true
  git({ "git", "ls-remote", "--tags", remote, "refs/tags/*" }, function(out)
    asking = false
    if out.code ~= 0 then
      return
    end

    local latest = newest(advertised(out.stdout))

    vim.schedule(function()
      cached = { checked = os.time(), latest = latest }
      write(cached)

      -- Whoever is drawing the answer redraws it; this module knows about no
      -- window of its own.
      vim.api.nvim_exec_autocmds("User", { pattern = "MivnUpdate", modeline = false })
    end)
  end)
end

--- git in the config directory, keeping my own git config.
---
--- The opposite of the check above, and deliberately: this one is allowed to
--- use origin's real URL and my keys, because taking a release is exactly what
--- they are for. BatchMode is what stops a machine with no key loaded from
--- hanging on a passphrase prompt in a window with no way to answer it.
local function take(args, on_exit)
  return vim.system(vim.list_extend({ "git", "-C", vim.fn.stdpath("config") }, args), {
    text = true,
    timeout = 60000,
    env = { GIT_TERMINAL_PROMPT = "0", GIT_SSH_COMMAND = "ssh -o BatchMode=yes" },
  }, on_exit)
end

local function trouble(out)
  return vim.trim(out.stderr ~= "" and out.stderr or out.stdout)
end

--- Take the release the notice is about.
---
--- A fast-forward onto the newest release tag, and not a pull of the branch:
--- the branch moves on with every merge, so pulling it lands on whatever main
--- happens to be today, which is not the version the banner named and is not
--- a version I decided anything about. --ff-only means a checkout carrying
--- commits of its own stops instead of growing a merge; a dirty tree and a
--- detached HEAD stop earlier still.
local function pull()
  -- An origin is all this needs, unlike the check, which has to build a URL it
  -- can read without a key.
  if not here({ "remote", "get-url", "origin" }) then
    vim.notify("This config has no git remote to take anything from.", vim.log.levels.WARN)
    return
  end

  -- Nothing to fast-forward without a branch, and `git checkout <tag>` is the
  -- ordinary way into that state.
  if not here({ "symbolic-ref", "-q", "HEAD" }) then
    vim.notify("Your config is not on a branch. Run `git switch main` in it first.", vim.log.levels.WARN)
    return
  end

  if here({ "status", "--porcelain" }) then
    vim.notify("Your config has changes of its own, so nothing was taken.", vim.log.levels.WARN)
    return
  end

  vim.notify("Fetching...")

  take({ "fetch", "--tags", "origin" }, function(fetched)
    vim.schedule(function()
      if fetched.code ~= 0 then
        vim.notify("The fetch failed:\n" .. trouble(fetched), vim.log.levels.ERROR)
        return
      end

      local target = newest(vim.split(here({ "tag", "--list", "v*" }) or "", "\n", { trimempty = true }))
      if not target then
        vim.notify("There are no releases to move to.", vim.log.levels.WARN)
        return
      end

      -- Everything from here is local and immediate, so it runs in line rather
      -- than nesting another callback under this one.
      local before = here({ "rev-parse", "HEAD" })
      local merged = take({ "merge", "--ff-only", target }):wait(30000)
      if merged.code ~= 0 then
        vim.notify(("Moving to %s failed:\n%s"):format(target, trouble(merged)), vim.log.levels.ERROR)
        return
      end

      -- A fast-forward onto a release already behind this checkout is a
      -- no-op that still exits 0, so what moved is the only honest answer.
      if here({ "rev-parse", "HEAD" }) == before then
        vim.notify(("Already on %s, or past it."):format(target))
        return
      end

      -- The release moved, so the memo has to go; the banner asks again.
      installed = nil
      vim.api.nvim_exec_autocmds("User", { pattern = "MivnUpdate", modeline = false })

      local moved = here({ "diff", "--name-only", ("%s..HEAD"):format(before) }) or ""
      local told = ("Updated to %s. Run :restart to load it."):format(target)
      if moved:find("plugins.lua", 1, true) then
        told = told .. "\nPlugins moved too, so run :lua vim.pack.update() after that."
      end

      vim.notify(told)
    end)
  end)
end

vim.api.nvim_create_user_command("MivnUpdate", pull, {
  desc = "Pull the newest mivn, if this config has no changes of its own",
})

-- Once a session, a couple of seconds in, so a start that is already busy
-- cloning plugins is not also spawning this. Not headless: a boot in CI has
-- no one to tell, and the check would only be network the run does not need.
vim.api.nvim_create_autocmd("VimEnter", {
  group = vim.api.nvim_create_augroup("mivn.update", { clear = true }),
  callback = function()
    if #vim.api.nvim_list_uis() == 0 then
      return
    end

    vim.defer_fn(function()
      M.check()
    end, 2000)
  end,
})

return M
