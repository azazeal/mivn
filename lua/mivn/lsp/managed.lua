-- Managed language servers: the wiring between the store
-- (lua/mivn/store.lua) and the built-in LSP client. Nothing is forked. Two
-- stock behaviors carry the design: repeated vim.lsp.config() calls merge
-- with list values replaced whole, which is how a server's PATH-relative
-- cmd becomes the store's absolute argv while nvim-lspconfig keeps owning
-- the filetypes and root markers; and vim.lsp.enable() fires for buffers
-- that are already open, which is how the buffer that raised the install
-- dialog attaches the moment the install lands.
--
-- For the servers in the store's manifest, the `lsp` overrides in local.lua
-- decide the mode: `false` is off, a table with `path` is the escape hatch
-- (an executable resolved in the user's own environment), and anything
-- else declared (`true`, or a table of knobs) is managed with install
-- consent pre-given, outranking an old No from the dialog. Nothing set
-- means managed, behind a one-time dialog whose answer persists per
-- machine. :MivnLsp is where to review and reverse all of it.

local store = require("mivn.store")
local sandbox = require("mivn.sandbox")

local lsp = require("mivn.overrides").lsp or {}
local supported = store.supported()

--- What each manifest server is doing right now, as a short user-facing
--- phrase. lua/mivn/health.lua prints it too.
local function state_of(name)
  local o = lsp[name]
  local path = type(o) == "table" and o.path or nil

  if o == false then
    return "off, from local.lua"
  elseif path then
    local found = vim.fn.executable(path) == 1 and "found" or "not found"
    return ("hatched to %s (%s on your PATH)"):format(path, found)
  elseif store.resolve(name) then
    return ("%s, managed"):format(store.manifest[name].version)
  elseif not supported then
    local _, why = store.supported()
    return why
  elseif o == nil and store.consent(name) == false then
    -- Only an undeclared server can be declined; a declared one outranks
    -- its old No.
    return "declined"
  end

  return "not installed"
end

--- Point `name` at the store and enable it, installing first if needed;
--- enabling attaches whatever covered buffers are already open.
local function install_and_enable(name)
  local version = store.manifest[name].version

  if store.resolve(name) then
    vim.lsp.config(name, { cmd = sandbox.wrap(name, store.resolve(name)) })
    vim.lsp.enable(name)
    return
  end

  vim.notify(("Installing %s %s in the background."):format(name, version))
  store.install(name, function(err)
    if err then
      vim.notify(("Installing %s failed: %s"):format(name, err), vim.log.levels.ERROR)
      return
    end

    vim.lsp.config(name, { cmd = sandbox.wrap(name, store.resolve(name)) })
    vim.lsp.enable(name)
    vim.notify(("%s %s is installed and on."):format(name, version))
  end)
end

--- Boot: enable what resolves, note what does not ----------------------------

-- Not yet installed, and still eligible this session: "install" means
-- consent already exists and the first covered file triggers the download,
-- "ask" means the dialog goes up first.
local pending = {}

local enable = {}
for name, spec in pairs(store.manifest) do
  local o = lsp[name]
  local path = type(o) == "table" and o.path or nil

  if o == false then
    -- Off. The sweep reads the same key, so its files age out on their own.
  elseif path then
    -- The escape hatch: the user's executable, the manifest's argv tail.
    local cmd = { path }
    vim.list_extend(cmd, spec.args or {})
    vim.lsp.config(name, { cmd = sandbox.wrap(name, cmd) })

    if vim.fn.executable(path) == 1 then
      enable[#enable + 1] = name
    end
  elseif store.resolve(name) then
    vim.lsp.config(name, { cmd = sandbox.wrap(name, store.resolve(name)) })
    enable[#enable + 1] = name
  elseif supported then
    -- Any declared entry is consent by itself; only the undeclared go
    -- through the dialog, and an old No there keeps the rest quiet.
    if o ~= nil or store.consent(name) == true then
      pending[name] = "install"
    elseif store.consent(name) == nil then
      pending[name] = "ask"
    end
  end
end

table.sort(enable)
vim.lsp.enable(enable)

--- The install dialog ---------------------------------------------------------

if next(pending) then
  -- Filetype to the pending servers covering it, read off the resolved
  -- configs so nvim-lspconfig stays the source of truth.
  local covers = {}
  for name in pairs(pending) do
    for _, ft in ipairs((vim.lsp.config[name] or {}).filetypes or {}) do
      covers[ft] = covers[ft] or {}
      table.insert(covers[ft], name)
    end
  end

  local group = vim.api.nvim_create_augroup("mivn.managed", { clear = true })
  local asking = false

  --- Whether anything is drawing this session. False under `--headless`
  --- until a remote UI attaches, which is how the tests drive it.
  local function has_ui()
    return #vim.api.nvim_list_uis() > 0
  end

  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    desc = "Offer to install the language servers that cover this file",
    callback = function(ev)
      local ask = {}
      for _, name in ipairs(covers[ev.match] or {}) do
        if pending[name] == "install" then
          pending[name] = nil
          install_and_enable(name)
        elseif pending[name] == "ask" then
          ask[#ask + 1] = name
        end
      end

      -- A session with no UI has nobody to answer, so the question waits for
      -- one; the answer is per machine and keeps until then. Skipping it is
      -- not just politeness: the dialog is a mini.pick window, and opening
      -- one in `nvim --headless` blocks the session for good.
      if #ask == 0 or asking or not has_ui() then
        return
      end
      asking = true
      table.sort(ask)

      local what = {}
      for _, name in ipairs(ask) do
        what[#what + 1] = ("%s %s"):format(name, store.manifest[name].version)
      end

      -- Scheduled: FileType can fire mid-batch (doautoall, sessions), and
      -- the dialog draws windows. The gap is what the second check is for: a
      -- quit can start in between, and a window opened after VimLeave takes
      -- the exit back and leaves the session running with nothing on screen.
      vim.schedule(function()
        if not has_ui() or vim.v.exiting ~= vim.NIL then
          asking = false
          return
        end

        vim.ui.select({ "Yes", "No, and do not ask again", "Ask me later" }, {
          prompt = ("Install %s for %s?"):format(table.concat(what, " and "), ev.match),
        }, function(_, idx)
          asking = false

          for _, name in ipairs(ask) do
            if idx == 1 then
              store.set_consent(name, true)
              install_and_enable(name)
            elseif idx == 2 then
              store.set_consent(name, false)
            end
            -- Ask me later, or the dialog dismissed: nothing persists, and
            -- clearing `pending` below keeps this session quiet about it.
            pending[name] = nil
          end
        end)
      end)
    end,
  })
end

--- :MivnLsp, the review surface -----------------------------------------------

--- The context actions for one managed server; nil when local.lua owns it,
--- which any declared entry does.
local function actions_for(name)
  if lsp[name] ~= nil then
    return nil
  end

  local actions = {}

  if store.resolve(name) then
    actions[#actions + 1] = {
      label = "Turn it off (its files age out in a later sweep)",
      run = function()
        store.set_consent(name, false)
        vim.lsp.enable(name, false)
      end,
    }
    actions[#actions + 1] = {
      label = "Reinstall it",
      run = function()
        local version = store.manifest[name].version
        vim.notify(("Reinstalling %s %s in the background."):format(name, version))
        store.install(name, function(err)
          if err then
            vim.notify(("Reinstalling %s failed: %s"):format(name, err), vim.log.levels.ERROR)
          else
            vim.notify(("%s %s is reinstalled; running clients restart on :restart."):format(name, version))
          end
        end, { force = true })
      end,
    }
  else
    actions[#actions + 1] = {
      label = "Install it and turn it on",
      run = function()
        store.set_consent(name, true)
        install_and_enable(name)
      end,
    }

    if store.consent(name) ~= nil then
      actions[#actions + 1] = {
        label = "Forget my answer (the dialog may ask again)",
        run = function()
          store.set_consent(name, nil)
        end,
      }
    end
  end

  return actions
end

--- The listing. A local function rather than the command body so the
--- action dialog can come back to it: Esc there cancels the action, not
--- the review.
local function review()
  local items = {}

  for name in vim.spairs(store.manifest) do
    items[#items + 1] = {
      label = ("%-24s %s"):format(name, state_of(name)),
      pick = function()
        local actions = actions_for(name)
        if not actions then
          vim.notify(("%s is set by the lsp overrides in local.lua; edit it there."):format(name))
          return
        end

        vim.ui.select(actions, {
          prompt = name,
          format_item = function(action)
            return action.label
          end,
        }, function(action)
          if action then
            action.run()
          else
            -- Backing out returns to the listing, rebuilt so it shows the
            -- current state. Scheduled: the picker is still tearing down.
            vim.schedule(review)
          end
        end)
      end,
    }
  end

  -- The servers still expected on PATH, from lua/mivn/lsp.lua.
  for name, binary in vim.spairs(require("mivn.lsp").servers) do
    local path = vim.fn.exepath(binary)
    local status = path ~= "" and path or ("off; %s is not on PATH"):format(binary)

    items[#items + 1] = {
      label = ("%-24s %s"):format(name, status),
      pick = function()
        vim.notify(("%s is installed outside mivn; %s"):format(name, status))
      end,
    }
  end

  items[#items + 1] = {
    label = "(store) sweep now",
    pick = function()
      store.sweep(function(err, condemned, deleted)
        if err then
          vim.notify(("The sweep failed: %s"):format(err), vim.log.levels.ERROR)
        else
          vim.notify(("Swept the store: %d newly condemned, %d deleted."):format(condemned, deleted))
        end
      end)
    end,
  }

  vim.ui.select(items, {
    prompt = "Language servers",
    format_item = function(item)
      return item.label
    end,
  }, function(item)
    if item then
      item.pick()
    end
  end)
end

vim.api.nvim_create_user_command("MivnLsp", review, {
  desc = "Review the language servers: managed, on PATH, off",
})

-- The daily reclamation pass; without it, a server turned off would keep
-- its files forever. The store throttles and defers it itself.
store.autosweep()

return { state = state_of }
