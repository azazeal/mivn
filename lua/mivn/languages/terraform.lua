-- Terraform: terraform-ls.

return {
  servers = {
    terraformls = {
      binary = "terraform-ls",
      probe = { "version" },

      -- Opening one .tf file outside a Terraform directory is normal here,
      -- and terraform-ls says so every time in a message long enough to raise
      -- the hit-enter prompt, which stops everything until a key arrives. The
      -- server offers this switch for exactly that; nothing else about it
      -- changes.
      config = { init_options = { ignoreSingleFileWarning = true } },
    },
  },
}
