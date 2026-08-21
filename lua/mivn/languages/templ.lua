-- templ: Go templates with a type checker, whose server proxies to gopls.

return {
  servers = {
    templ = { binary = "templ", probe = { "version" } },
  },
}
