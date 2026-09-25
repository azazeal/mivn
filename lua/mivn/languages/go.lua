-- Go: gopls for the language, golangci-lint beside it for the linters, and
-- gci after the write to group the imports.
--
-- The import groups come from $GOIMPORTPREFIXES, a name of my own: a
-- comma-separated list of the module prefixes that count as ours, which land
-- in a block of their own between third party and this module's. It is set
-- per organisation by whatever prepares the environment. Unset is fine: gci
-- still splits standard from third party from local.
--
-- $GOIMPORTNOGCI, a yes or a no, turns the gci pass off and leaves the
-- imports as gopls grouped them. It is for a gci older than the Go in use:
-- gci carries its own list of the standard library, fixed at its release, so
-- a newer package is moved out of the standard block on every save. gci
-- v0.14.0 does that to `uuid`, added in go1.27, whatever Go builds it.

--- $GOIMPORTPREFIXES as a list, in the order it was written, without
--- duplicates or empties. The dedupe matters: handed the same section twice,
--- gci empties the import block and exits 0.
local function prefixes()
  local seen, list = {}, {}

  for prefix in (vim.env.GOIMPORTPREFIXES or ""):gmatch("[^,%s]+") do
    if not seen[prefix] then
      seen[prefix] = true
      list[#list + 1] = prefix
    end
  end

  return list
end

local import_prefixes = prefixes()

-- `go env GOVERSION`, asked once. "unknown" when `go` cannot say, which is a
-- name no working toolchain's daemon has.
local version
local function go_version()
  if version == nil then
    local ok, result = pcall(function()
      return vim.system({ "go", "env", "GOVERSION" }, { text = true }):wait(5000)
    end)

    version = ok and result.code == 0 and vim.trim(result.stdout or "") or ""
    if version == "" then
      version = "unknown"
    end
  end

  return version
end

--- gopls' command, as a function so that `go env` is asked at the first
--- client start rather than at startup. Neovim calls it once per client and
--- wants the RPC object back. The options are Neovim 0.12.5's own, except
--- that `cwd` falls back to `root_dir`.
---
--- `-remote` puts the work in a daemon shared by every window on the same
--- toolchain, so a project is parsed once rather than once per window. The
--- daemon outlives its last window by a minute.
---
--- NOTE: The daemon's name after `auto;` carries the Go version. One daemon
--- for all would serve everything with whichever toolchain reached it first,
--- and read every other project against the wrong standard library
--- (https://github.com/golang/go/issues/50991).
local function gopls_cmd(dispatchers, config)
  local cmd = { "gopls", ("-remote=auto;%s"):format(go_version()) }

  return vim.lsp.rpc.start(cmd, dispatchers, {
    cwd = config.cmd_cwd or config.root_dir,
    env = config.cmd_env,
    detached = config.detached,
  })
end

-- gci's import blocks, in order: standard library, everything else, then a
-- block per prefix. `localmodule`, this module's own packages, is added per
-- file, since not every file is in a module.
local sections = { "standard", "default" }
for _, prefix in ipairs(import_prefixes) do
  sections[#sections + 1] = ("Prefix(%s)"):format(prefix)
end

-- The workspace those sections were built for, pinned at startup so a later
-- :cd cannot put another checkout under this one's blocks. Resolved through
-- symlinks because the check against it compares text, and a symlinked cwd
-- would read every file as outside.
local workspace = vim.uv.fs_realpath(vim.fn.getcwd()) or vim.fn.getcwd()

--- Where to run gci for `path`, and what to tell it, so that `localmodule`
--- resolves to the module the file is actually in. nil when it is in none.
---
--- gci finds the module from its working directory alone: `go.work` there,
--- the go.mod `$GOMOD` names, or `./go.mod`, and it never walks up (v0.14).
--- A subprocess starts where the session did, so without this walk gci exits
--- 1 with "could not find module path" whenever the editor was started
--- anywhere but a module root.
---
--- go.work wins over go.mod and is looked for from the file: a workspace
--- makes every module it names local, and it sits above them, so the nearest
--- one up answers for all of them.
local function go_context(path)
  local dir = vim.fs.dirname(path)

  local work = vim.fs.find("go.work", { path = dir, upward = true, type = "file" })[1]
  if work then
    return { cwd = vim.fs.dirname(work) }
  end

  local mod = vim.fs.find("go.mod", { path = dir, upward = true, type = "file" })[1]
  if mod then
    -- $GOMOD is the one hook gci honors, so the module is named outright
    return { cwd = dir, env = { GOMOD = mod } }
  end

  return nil
end

-- The ways of saying no to a yes-or-no switch. Anything else is a yes: a
-- variable set to a word nobody reads as no was set to turn something off.
local NO = { [""] = true, ["0"] = true, ["false"] = true, no = true, off = true }

--- Whether $GOIMPORTNOGCI turns the gci pass off. Asked per save, so
--- `:let $GOIMPORTNOGCI = 1` takes hold in a running editor.
local function gci_off()
  return not NO[vim.trim((vim.env.GOIMPORTNOGCI or ""):lower())]
end

-- Each warning is said once per session.
local warned_outside = false
local warned_failure = false

--- Re-split a saved Go file's imports with gci, in place.
---
--- Runs after the write, because gci is pointed at the file on disk. The
--- result is spliced into the buffer rather than reloaded, so it joins the
--- undo history instead of clearing it.
local function gci_format(buf)
  if gci_off() then
    return
  end

  -- the same trust gate as the rest of the save chain
  local trust = require("mivn.trust")
  if not trust.allows(trust.workspace()) then
    return
  end

  if vim.fn.executable("gci") ~= 1 then
    return
  end

  local path = vim.api.nvim_buf_get_name(buf)

  -- NOTE: One session is one workspace, and the sections were built for it.
  -- A file from another checkout would get this one's "ours" block, which is
  -- churn in a repository that never asked for it, so it is skipped with a
  -- warning. gopls has already organised its imports; only the grouping is
  -- missing.
  if vim.fs.relpath(workspace, vim.uv.fs_realpath(path) or path) == nil then
    if not warned_outside then
      warned_outside = true
      vim.notify(
        "gci skipped: this file is outside the workspace this session started in, "
          .. "and its import blocks are not the ones configured here.",
        vim.log.levels.WARN
      )
    end

    return
  end

  local context = go_context(path)

  local cmd = { "gci", "write", "--skip-generated", "--custom-order" }
  for _, section in ipairs(sections) do
    cmd[#cmd + 1] = "-s"
    cmd[#cmd + 1] = section
  end

  -- NOTE: Only when there is a module to be local to. Asking for
  -- `localmodule` without one is not a no-op: gci refuses the whole file.
  if context then
    cmd[#cmd + 1] = "-s"
    cmd[#cmd + 1] = "localmodule"
  end

  cmd[#cmd + 1] = path

  -- NOTE: The buffer matches the disk now, just after the write. If it no
  -- longer does when gci answers, I typed in between, and splicing the file
  -- in would throw those keystrokes away. The changedtick guards that.
  local tick = vim.api.nvim_buf_get_changedtick(buf)

  vim.system(cmd, {
    text = true,
    cwd = context and context.cwd or nil,
    env = context and context.env or nil,
  }, function(result)
    -- said, since a failed pass leaves nothing on screen otherwise
    if result.code ~= 0 then
      if not warned_failure then
        warned_failure = true

        local said = vim.trim((result.stderr or ""):gsub("\n.*", ""))
        vim.schedule(function()
          vim.notify(("gci: %s"):format(said ~= "" and said or ("exited %d"):format(result.code)), vim.log.levels.WARN)
        end)
      end

      return
    end

    vim.schedule(function()
      if not vim.api.nvim_buf_is_valid(buf) or vim.api.nvim_buf_get_changedtick(buf) ~= tick then
        return
      end

      local file = io.open(path, "r")
      if not file then
        return
      end
      local content = file:read("*a")
      file:close()

      local new = vim.split(content, "\n")
      if new[#new] == "" then
        table.remove(new)
      end

      if not vim.deep_equal(new, vim.api.nvim_buf_get_lines(buf, 0, -1, false)) then
        require("mivn.format").replace(buf, new)
        vim.bo[buf].modified = false
      end
    end)
  end)
end

-- gopls has run gofmt and organised the imports by the time this fires; gci
-- only re-splits them into the blocks above.
vim.api.nvim_create_autocmd("BufWritePost", {
  group = vim.api.nvim_create_augroup("mivn.languages.go", { clear = true }),
  pattern = "*.go",
  callback = function(ev)
    gci_format(ev.buf)
  end,
})

--- The Go language version named anywhere in `text`, patch dropped, or nil.
--- Both `go version` and gopls answer with a `go1.26.5` somewhere in a line.
local function go_language_version(text)
  local found = (text or ""):match("go(%d+%.%d+)")
  return found and vim.version.parse(found, { strict = false }) or nil
end

--- Reports to :checkhealth whether gopls can read the toolchain it is
--- pointed at.
---
--- gopls type-checks with the go/types compiled into it, so the Go that built
--- it caps the language version, whatever the project asks for. A gopls
--- behind its toolchain reports errors on code that builds and says nothing
--- about why: built with go1.24, it calls `new(42)` "42 is not a type" in a
--- go 1.26 module. gopls itself only warns about a Go that is too old.
---
--- The other direction is fine, since go/types applies the version in
--- go.mod, so only the minors are compared.
local function check_gopls_toolchain()
  local health = vim.health

  if vim.fn.exepath("gopls") == "" or vim.fn.exepath("go") == "" then
    return
  end

  --- What `cmd` printed, or nil unless it ran and succeeded.
  local function output(cmd)
    local ok, result = pcall(function()
      return vim.system(cmd, { text = true }):wait(5000)
    end)

    return ok and result.code == 0 and result.stdout or nil
  end

  -- gopls reports the Go it was built with; the workspace's is the `go` on PATH
  local reported = output({ "gopls", "version", "-json" })
  local decoded = reported and select(2, pcall(vim.json.decode, reported))

  local built = type(decoded) == "table" and go_language_version(decoded.GoVersion)
  local using = go_language_version(output({ "go", "version" }))

  if not built or not using then
    return
  end

  if vim.version.lt(built, using) then
    health.warn(
      ("gopls was built with Go %d.%d and this workspace runs %d.%d"):format(
        built.major,
        built.minor,
        using.major,
        using.minor
      ),
      "It cannot type-check the newer language, and the errors it invents blame your code. Rebuild it against this toolchain."
    )
  else
    health.info(
      ("gopls was built with Go %d.%d, and this workspace runs %d.%d"):format(
        built.major,
        built.minor,
        using.major,
        using.minor
      )
    )
  end
end

--- What :checkhealth mivn says under "go": whether gopls can read this
--- toolchain, and whether the gci pass can run. gci is optional, since gopls
--- already formats and organises the imports.
local function health()
  check_gopls_toolchain()

  if gci_off() then
    vim.health.info("gci: off (turned off by $GOIMPORTNOGCI)")
  else
    require("mivn.health").binary("gci", "gci")
  end
end

return {
  health = health,

  servers = {
    gopls = {
      binary = "gopls",
      cmd = gopls_cmd,
      probe = { "version" },

      config = {
        -- GOMEMLIMIT is a target for the collector, not a wall: it works
        -- harder as the heap nears it. It covers the whole daemon, i.e. every
        -- window sharing it, so if things drag it may need raising rather
        -- than lowering.
        cmd_env = { GOMEMLIMIT = "2GiB" },

        settings = {
          gopls = {
            -- Our prefixes, in one block ahead of the module's own. gci
            -- re-splits the file afterwards, so this matters mostly when gci
            -- is not installed.
            ["local"] = table.concat(import_prefixes, ","),

            -- golangci-lint runs staticcheck already, and two copies of the
            -- same finding on one line is one copy too many.
            staticcheck = false,

            analyses = {
              -- Structs whose fields would take less memory in another order.
              -- Off in golangci-lint, where it would fail a build over a
              -- layout that is fine; here it is something to notice while I
              -- am in the file, with the reordering as a code action.
              fieldalignment = true,
            },

            -- The lenses I use.
            codelenses = {
              generate = true,
              regenerate_cgo = true,
              test = true,
              tidy = true,
              upgrade_dependency = true,
              vendor = true,
              vulncheck = true,
            },

            -- All eight kinds: facts the compiler knew that I do not have to.
            -- ignoredError is worth the most: it marks a statement whose error
            -- goes nowhere, which the compiler knows and never says.
            hints = {
              assignVariableTypes = true,
              compositeLiteralFields = true,
              compositeLiteralTypes = true,
              constantValues = true,
              functionTypeParameters = true,
              ignoredError = true,
              parameterNames = true,
              rangeVariableTypes = true,
            },

            -- Off for the reason rust.lua gives for its hover links.
            linksInHover = false,

            -- What colors a package qualifier in call position, since
            -- tree-sitter cannot tell `pkg.Exec(...)` from a variable. gopls
            -- stopped advertising semantic tokens in v0.22, so they have to
            -- be asked for; nvim-lspconfig asks too, but that default lives
            -- in someone else's file. colors/basalt.lua clears the string
            -- token, which would paint over the SQL queries/go/injections.scm
            -- injects.
            semanticTokens = true,
          },
        },
      },
    },

    golangci_lint_ls = {
      binary = "golangci-lint-langserver",
      probe = false,

      config = {
        -- NOTE: No .golangci.yml, which nvim-lspconfig puts first. Markers
        -- are read in order, not nearest first, so one shared config above
        -- many checkouts (mine sits in ~) would root every Go file under it
        -- there. Nothing is lost: the server runs golangci-lint in the file's
        -- module, and golangci-lint walks up from there to find its config.
        root_markers = { "go.work", "go.mod", ".git" },
      },
    },
  },
}
