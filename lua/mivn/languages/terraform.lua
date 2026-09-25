-- Terraform: terraform-ls.

return {
  servers = {
    terraformls = {
      binary = "terraform-ls",
      probe = { "version" },

      -- Opening one .tf file outside a Terraform directory is normal for me,
      -- and terraform-ls warns about it every time, in a message long enough
      -- to raise the hit-enter prompt. This switch silences that warning and
      -- nothing else.
      config = { init_options = { ignoreSingleFileWarning = true } },
    },
  },
}
