-- :restart, refused when the window is not on this machine.
--
-- :restart spawns the new Neovim on the machine the *server* runs on and
-- hands every UI that server's listen address (:h :restart). With the window
-- on another machine (Neovide over ssh), that address names a socket on the
-- wrong filesystem: the window dies trying to connect, and the new server
-- lingers headless with nothing ever attaching. Both halves are measured,
-- not assumed: gui.txt documents the same-system limit, and a UI-less
-- :restart observably leaves a dangling `nvim --embed --headless` behind.
-- Nothing running inside Neovim can relaunch a UI on another machine, so
-- refusing loudly is the whole feature.
--
-- Remote is declared, or failing that sniffed. $MIVN_REMOTE_UI set to
-- anything nonempty is the supported knob for launchers (README.md).
-- The fallback recognizes Neovide's remote clipboard bridge: it registers
-- g:clipboard with name "neovide" exactly when its remote flag is on, which
-- its --wsl and --server modes both set. The sniff breaks if
-- g:neovide_no_custom_clipboard disables the bridge, which is what the
-- explicit variable is for. Checked when a restart is attempted rather than
-- at startup, since Neovide wires its clipboard around config-load time.

local MESSAGE = "This editor runs on another machine, and :restart cannot reattach a remote window. "
  .. "Close the window and open the project again."

local function remote_ui()
  if (vim.env.MIVN_REMOTE_UI or "") ~= "" then
    return true
  end

  return (vim.g.clipboard or {}).name == "neovide"
end

vim.api.nvim_create_user_command("MivnRestartRemote", function()
  vim.notify(MESSAGE, vim.log.levels.WARN)
end, { desc = "What :restart becomes when the window is remote" })

-- The same rewrite the tree's :bd guard uses: a user command cannot shadow a
-- built-in, so the command line is changed the moment before it runs. `rest`
-- is the shortest spelling that resolves to :restart (`res` is :resize;
-- measured with fullcommand()), and whatever follows the word is :restart's
-- own [+cmd][command] tail, refused along with it.
vim.api.nvim_create_autocmd("CmdlineLeavePre", {
  group = vim.api.nvim_create_augroup("mivn.restart", { clear = true }),
  desc = "Refuse :restart when the window is on another machine",
  callback = function()
    if vim.fn.getcmdtype() ~= ":" or not remote_ui() then
      return
    end

    local word = vim.fn.getcmdline():match("^%s*(%l+)")
    if word and #word >= 4 and ("restart"):find(word, 1, true) == 1 then
      vim.fn.setcmdline("MivnRestartRemote")
    end
  end,
})

-- ZR is :restart's Normal-mode spelling. It is a built-in, not a mapping, so
-- one mapping shadows it; the local case feeds the real ZR back through with
-- mappings skipped.
vim.keymap.set("n", "ZR", function()
  if remote_ui() then
    vim.notify(MESSAGE, vim.log.levels.WARN)
    return
  end

  vim.api.nvim_feedkeys("ZR", "n", false)
end, { desc = "Restart, unless the window is on another machine" })
