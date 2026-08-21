-- Ruby: ruby-lsp.
--
-- It builds a bundle of its own under `.ruby-lsp/` inside the checkout and
-- runs the project's Gemfile through bundler to do it, which is worth knowing
-- before opening someone else's repository.

return {
  servers = {
    ruby_lsp = { binary = "ruby-lsp" },
  },
}
