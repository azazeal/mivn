-- Whether a newer mivn is out, and `:MivnUpdate` to take it.
--
-- The config directory is a git clone, so "newer" means a release tag the
-- remote has and this checkout does not. The check is one `git ls-remote`
-- against the repository's public https URL, at most once a day, with the
-- answer kept under stdpath("state"); it fetches nothing and writes nothing
-- into the repository.
--
-- Releases and not commits, since a tag is me deciding a version is good. It
-- also keeps this quiet where I write mivn, as HEAD there is usually past the
-- newest tag.
--
-- Nothing updates itself: `:MivnUpdate` is me saying yes to the notice. It
-- moves onto the release the notice named, refuses if this checkout has
-- anything of its own, and never restarts. Neovim runs the Lua it loaded at
-- startup, so the new files count from `:restart`, and moved plugin pins from
-- `vim.pack.update()`; both are mine to run.

local M = {}

local CACHE = vim.fs.joinpath(vim.fn.stdpath("state"), "update.json")
local TTL = 24 * 60 * 60

--- git, kept off ssh and off any prompt.
---
--- NOTE: a global gitconfig can rewrite an https URL to ssh
--- (url.<base>.insteadOf), and a git in the background on a machine whose agent
--- holds no key then hangs on a passphrase prompt nothing is drawing.
--- GIT_CONFIG_GLOBAL=/dev/null drops the rewrite for this subprocess alone, and
--- GIT_TERMINAL_PROMPT=0 turns any prompt that still gets through into a
--- failure. Neither may be set for the whole process, since `:terminal` has to
--- keep my real git config.
local function git(args, on_exit)
  return vim.system(args, {
    text = true,
    timeout = 10000,
    env = { GIT_CONFIG_GLOBAL = "/dev/null", GIT_TERMINAL_PROMPT = "0" },
  }, on_exit)
end

local function ask(args)
  local out = git(vim.list_extend({ "git", "-C", vim.fn.stdpath("config") }, args)):wait(5000)
  if out.code ~= 0 then
    return nil
  end

  local value = vim.trim(out.stdout)
  return value ~= "" and value or nil
end

--- git's trimmed answer inside the config directory, or nil when git fails,
--- says nothing, or the directory is not a checkout of its own.
---
--- NOTE: the `.git` check is the point. git searches upwards from -C, so a
--- config directory inside some other repository (a dotfiles repo holding all
--- of ~/.config, say) would answer with that repository's tags and origin.
local rooted
local function here(args)
  if rooted == nil then
    rooted = vim.uv.fs_stat(vim.fs.joinpath(vim.fn.stdpath("config"), ".git")) ~= nil
  end

  if not rooted then
    return nil
  end

  return ask(args)
end

--- `git describe --tags` for HEAD, asked once: `v0.2.1` on a release and
--- `v0.2.1-7-gabc1234` past one, nil when it is not a clone or has no tags.
--- `false` in the memo is "asked, got nothing", so a miss is not asked again.
local described
local function describe()
  if described == nil then
    described = here({ "describe", "--tags" }) or false
  end

  return described or nil
end

--- The release this checkout is on or past, for comparing with the newest.
local function version()
  local tag = describe()
  return tag and (tag:gsub("%-%d+%-g%x+$", "")) or nil
end

--- The release this checkout is on, for showing: `v0.2.1` on the tag and
--- `v0.2.1+7` past it (the shape of the pins in plugins.lua), so a checkout
--- ahead of a release never claims to be it. nil when there is no tag. The
--- working tree is left out, since I dirty this config all day.
function M.running()
  local tag = describe()
  return tag and (tag:gsub("%-(%d+)%-g%x+$", "+%1")) or nil
end

--- The public https URL for origin, which can be read without a key whether
--- origin is written as ssh or https. nil when origin is not on GitHub.
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

--- The newest release among `names`, as "v1.2.3", or nil when there is none.
--- Prereleases do not count. The remote's tags and the local ones both go
--- through here, so the two ends of a comparison agree on what a release is.
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

--- The tag names in ls-remote output. An annotated tag comes back twice, once
--- more as `<name>^{}`; without the suffix the copy changes nothing.
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

--- The report when a newer release is out, nil otherwise.
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

local asking = false

--- Ask the remote in the background, unless the last answer is still fresh, and
--- fire `User MivnUpdate` once it answers. A failure says nothing, since the
--- next session asks again.
function M.check()
  if asking then
    return
  end

  local known = state()
  if known.checked and os.time() - known.checked < TTL then
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

      -- whoever draws the answer redraws on this
      vim.api.nvim_exec_autocmds("User", { pattern = "MivnUpdate", modeline = false })
    end)
  end)
end

--- git in the config directory with my own git config, so with origin's real
--- URL and my keys.
---
--- NOTE: not git() above. Taking a release is what my keys are for, so the
--- global config stays, and BatchMode is what stops a machine with no key
--- loaded from hanging on a passphrase prompt nothing can answer.
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

--- Take the release the notice is about: the newest release tag, and not the
--- branch, which moves on with every merge.
---
--- On a branch the move is a fast-forward. Detached, which is where a clone of
--- a release tag lands, it is a checkout of the new tag. Neither may drop work:
--- a dirty tree stops before the fetch, and a HEAD the release does not carry
--- stops after it. The fetch comes before the question, so the question can say
--- what the release carries, and an answer of no changes nothing.
local function pull()
  -- origin as it is; only the check needs a URL that works without a key
  if not here({ "remote", "get-url", "origin" }) then
    vim.notify("This config has no git remote to take anything from.", vim.log.levels.WARN)
    return
  end

  if here({ "status", "--porcelain" }) then
    vim.notify("Your config has changes of its own, so nothing was taken.", vim.log.levels.WARN)
    return
  end

  -- nil when HEAD is detached, which picks the move below
  local branch = here({ "symbolic-ref", "-q", "HEAD" })

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

      -- on the release or past it, so a move would do nothing
      if take({ "merge-base", "--is-ancestor", target, "HEAD" }):wait(5000).code == 0 then
        vim.notify(("Already on %s, or past it."):format(target))
        return
      end

      -- NOTE: this check is what keeps a detached checkout's own commits.
      -- `merge --ff-only` refuses on its own, but only after the question has
      -- been answered; `checkout` does not refuse at all, and would leave the
      -- commits to the reflog. So the release has to carry every commit here.
      if take({ "merge-base", "--is-ancestor", "HEAD", target }):wait(5000).code ~= 0 then
        vim.notify("Your config has commits of its own, so nothing was taken.", vim.log.levels.WARN)
        return
      end

      local span = ("HEAD..%s"):format(target)
      local commits = #vim.split(here({ "log", "--oneline", span }) or "", "\n", { trimempty = true })
      local plugins = (here({ "diff", "--name-only", span }) or ""):find("plugins.lua", 1, true) ~= nil

      vim.ui.select({ "Take it", "Not now" }, {
        prompt = ("%s is out: %d commit%s%s. Take it?"):format(
          target,
          commits,
          commits == 1 and "" or "s",
          plugins and ", plugins included" or ""
        ),
      }, function(_, idx)
        if idx ~= 1 then
          return
        end

        -- a branch moves with the release, a detached HEAD stays detached
        local move = branch and { "merge", "--ff-only", target } or { "checkout", "--detach", target }

        local moved = take(move):wait(30000)
        if moved.code ~= 0 then
          vim.notify(("Moving to %s failed:\n%s"):format(target, trouble(moved)), vim.log.levels.ERROR)
          return
        end

        -- HEAD moved, so describe() has to ask again
        described = nil
        vim.api.nvim_exec_autocmds("User", { pattern = "MivnUpdate", modeline = false })

        local told = ("Updated to %s. Run :restart to load it."):format(target)
        if plugins then
          told = told .. "\nPlugins moved too, so run :lua vim.pack.update() after that."
        end

        vim.notify(told)
      end)
    end)
  end)
end

vim.api.nvim_create_user_command("MivnUpdate", pull, {
  desc = "Pull the newest mivn, if this config has no changes of its own",
})

-- Checked once a session, two seconds in, so a start busy cloning plugins is
-- not also spawning this. Never headless, where there is no one to tell.
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
