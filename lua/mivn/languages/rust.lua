-- Rust: rust-analyzer, which compiles the crate to answer questions about it,
-- build scripts and proc macros included.

return {
  servers = {
    rust_analyzer = {
      binary = "rust-analyzer",

      config = {
        settings = {
          ["rust-analyzer"] = {
            -- Clippy rather than `cargo check`: the same front end plus
            -- several hundred more lints, on save by default. The cost is
            -- that the two share no build cache, so the first save in a
            -- session rebuilds the dependencies under clippy's flags.
            check = { command = "clippy" },

            -- rust-analyzer expands every rustdoc link in a hover into a full
            -- docs.rs URL. Neovim conceals the URL but still measures the
            -- line with it, so one link makes the float far wider than its
            -- text. Off, the link text stays and the URL never arrives.
            hover = { links = { enable = false } },

            -- The defaults stay; most hints the server keeps off restate the
            -- line beside them. bindingModeHints does not: it shows the `ref`
            -- and `ref mut` that match ergonomics inserts and the text never
            -- says. `with_block` shows return types only on closures with a
            -- block body.
            inlayHints = {
              bindingModeHints = { enable = true },
              closureReturnTypeHints = { enable = "with_block" },
            },

            -- A .rs file that belongs to no crate is one I opened on purpose,
            -- to read, and being told about it every time helps with nothing.
            diagnostics = {
              disabled = { "unlinked-file" },
            },
          },
        },
      },
    },
  },
}
