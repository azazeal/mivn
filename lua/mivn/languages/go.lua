-- Go: gopls for the language, golangci-lint beside it for the linters, and
-- gci after the write to group the imports.
--
-- The import groups come from $GOIMPORTPREFIXES, a name of my own that the
-- Go tool knows nothing about: a comma-separated list of the module prefixes
-- that count as ours, so they land in a block of their own between the third
-- party and this module's. It is set per organisation, a directory above each
-- checkout, by whatever prepares the environment, which is why nothing about
-- it appears here.
-- Unset is fine: gci still splits standard from third party from local.

--- $GOIMPORTPREFIXES as a list, in the order it was written, without
--- duplicates or empties. gci hands the same section twice by emptying the
--- import block and exiting 0, so the dedupe is not cosmetic.
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

--- gopls' command, built on first use.
---
--- `-remote` puts the work in a daemon and leaves the process Neovim talks to
--- as a thin client, so every window on the same toolchain parses a project
--- once instead of once each. The daemon outlives the window that started it
--- by a minute and drops that window's state as the window goes.
---
--- The name after `auto;` decides who shares with whom, and it carries the Go
--- version because a single daemon would otherwise serve everything with
--- whichever toolchain reached it first, leaving every project on another
--- version read against the wrong standard library
--- (https://github.com/golang/go/issues/50991). The fallback keeps a broken
--- `go` out of a name other windows share rather than letting it land there.
---
--- A cmd function rather than a list, so `go env` is asked at the first
--- client start rather than on the way to the dashboard. Neovim calls this
--- once per client and wants the RPC object back; what it has to reproduce is
--- copied from Neovim's own default (`vim.lsp.client`).
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

local function gopls_cmd(dispatchers, config)
  local cmd = { "gopls", ("-remote=auto;%s"):format(go_version()) }

  return vim.lsp.rpc.start(cmd, dispatchers, {
    cwd = config.cmd_cwd or config.root_dir,
    env = config.cmd_env,
    detached = config.detached,
  })
end

--- Re-split a saved Go file's imports with gci, in place.
---
--- Runs after the write, not before, because gci is pointed at the file on
--- disk. Spliced back with nvim_buf_set_lines rather than reloaded, so the
--- change joins the undo history instead of clearing it.

-- gci's import blocks, in output order: standard library, everything else,
-- then a block per prefix. This module's own packages, `localmodule`, are
-- appended per file below, since only some files have such a thing. gopls
-- runs first, gci owns the end.
local sections = { "standard", "default" }
for _, prefix in ipairs(import_prefixes) do
  sections[#sections + 1] = ("Prefix(%s)"):format(prefix)
end

-- The workspace those sections were built for: pinned at startup, so a
-- mid-session :cd cannot bring another checkout under this one's blocks. Resolved through symlinks
-- because the relpath check below is textual, and a symlinked cwd against a
-- resolved file path would read as "outside".
local workspace = vim.uv.fs_realpath(vim.fn.getcwd()) or vim.fn.getcwd()

--- Where to run gci for `path`, and what to tell it, so that `localmodule`
--- resolves to the module the file is actually in. nil when it is in none.
---
--- gci reads that from its working directory and nowhere else: `go.work`
--- there, or the go.mod that `$GOMOD` names, or `./go.mod`, and it never walks
--- up (v0.14, pkg/section/local_module.go). Neovim starts a subprocess in the
--- directory the session started in, so opening the editor inside a package,
--- or at the root of a repository whose modules sit a level down, made gci
--- exit 1 with "could not find module path" on every save. That failure was
--- silent, so the import blocks simply stopped happening (measured
--- 2026-08-16). Hence the walk, which is the editor's to do.
---
--- go.work wins over go.mod, and is looked for from the file rather than from
--- the module root: a workspace makes every module it names local, and it sits
--- above the modules it uses, so the nearest one up is the answer for all of
--- them.
local function go_context(path)
  local dir = vim.fs.dirname(path)

  local work = vim.fs.find("go.work", { path = dir, upward = true, type = "file" })[1]
  if work then
    return { cwd = vim.fs.dirname(work) }
  end

  local mod = vim.fs.find("go.mod", { path = dir, upward = true, type = "file" })[1]
  if mod then
    -- $GOMOD is the one hook gci honors, so the run stays in the file's own
    -- directory and the module is named outright.
    return { cwd = dir, env = { GOMOD = mod } }
  end

  return nil
end

--- Said once each, when a Go file from outside this workspace is saved, and
--- when gci itself refuses.
local warned_outside = false
local warned_failure = false

local function gci_format(buf)
  if vim.fn.executable("gci") ~= 1 then
    return
  end

  local path = vim.api.nvim_buf_get_name(buf)

  -- One Neovim is one workspace, and the sections above were built for this
  -- one. A file from another checkout, reached by a picker rather than by
  -- opening an editor there, would be regrouped against the wrong prefixes:
  -- measured 2026-08-15, a smallstep file saved from a session started in
  -- ~/projects/azazeal gets `github.com/azazeal/` as its "ours" block, which
  -- is silent churn in someone else's repository. The language servers are
  -- unaffected, since each roots itself from the file.
  --
  -- So nothing happens instead, and it says so once. gopls has already
  -- formatted and organised the imports by then; only the grouping is
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

  -- Only when there is a module to be local to. Asking for the section
  -- without one is not a no-op: gci refuses the whole file.
  if context then
    cmd[#cmd + 1] = "-s"
    cmd[#cmd + 1] = "localmodule"
  end

  cmd[#cmd + 1] = path

  -- The buffer matches the disk right now, just after the write. If it does
  -- not by the time gci's result comes back, I typed in the window in
  -- between, and splicing the file over the buffer would throw those
  -- keystrokes away; the changedtick is the guard against exactly that.
  local tick = vim.api.nvim_buf_get_changedtick(buf)

  vim.system(cmd, {
    text = true,
    cwd = context and context.cwd or nil,
    env = context and context.env or nil,
  }, function(result)
    -- Said once, and not swallowed: gci writes the file itself, so a failure
    -- leaves the imports as gopls grouped them with nothing on screen to say
    -- the second pass never ran.
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
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, new)
        vim.bo[buf].modified = false
      end
    end)
  end)
end

-- gopls has already run gofmt and organised the imports by the time this
-- fires; gci only re-splits them into the blocks above.
vim.api.nvim_create_autocmd("BufWritePost", {
  group = vim.api.nvim_create_augroup("mivn.languages.go", { clear = true }),
  pattern = "*.go",
  callback = function(ev)
    gci_format(ev.buf)
  end,
})

return {
  servers = {
    gopls = {
      binary = "gopls",
      cmd = gopls_cmd,
      probe = { "version" },

      config = {
        -- GOMEMLIMIT is a ceiling the collector aims for, not a wall: it works
        -- harder as the heap climbs towards it instead of the process
        -- growing. It covers the daemon whole, i.e. every window sharing it,
        -- so it may need raising rather than lowering if things start to
        -- drag.
        cmd_env = { GOMEMLIMIT = "2GiB" },

        settings = {
          gopls = {
            -- Quoted because `local` is a Lua keyword and cannot be a bare
            -- key. It groups our prefixes into one block ahead of the
            -- module's own; gci re-splits the file afterwards and owns the
            -- final layout, so this mostly matters when gci is not
            -- installed.
            ["local"] = table.concat(import_prefixes, ","),

            -- golangci-lint runs staticcheck already, and two copies of the
            -- same finding on one line is one copy too many.
            staticcheck = false,

            -- The codelenses are the ones I use.
            codelenses = {
              generate = true,
              regenerate_cgo = true,
              test = true,
              tidy = true,
              upgrade_dependency = true,
              vendor = true,
              vulncheck = true,
            },

            -- All seven kinds. They read as facts the compiler already knew
            -- and I did not have to; how loud they are is the LspInlayHint
            -- highlight group's business, in colors/basalt.lua.
            hints = {
              assignVariableTypes = true,
              compositeLiteralFields = true,
              compositeLiteralTypes = true,
              constantValues = true,
              functionTypeParameters = true,
              parameterNames = true,
              rangeVariableTypes = true,
            },

            -- What colors a package qualifier in call position: tree-sitter
            -- cannot tell `pkg.Exec(...)` from a variable. gopls stopped
            -- advertising semantic tokens in v0.22, so they have to be asked
            -- for. nvim-lspconfig asks too; this says it anyway rather than
            -- resting on a default that lives in someone else's file.
            semanticTokens = true,
          },
        },
      },
    },

    golangci_lint_ls = {
      binary = "golangci-lint-langserver",
      probe = false,

      config = {
        -- nvim-lspconfig puts .golangci.yml at the head of this list, and a
        -- marker list is read in order rather than nearest-first, so a single
        -- shared config above a tree of checkouts roots every file in them at
        -- that directory. Mine sits in ~, which rooted this server at ~ for
        -- every Go file with no nearer config.
        --
        -- Nothing is lost by dropping it. The language server finds the module
        -- from the file it was asked about and runs golangci-lint there,
        -- ignoring this root entirely, and golangci-lint walks up from that
        -- module on its own to find the config. A root is a workspace, and the
        -- workspace is the module.
        root_markers = { "go.work", "go.mod", ".git" },
      },
    },
  },
}
