-- Rust: rust-analyzer, which compiles the crate to answer questions about it,
-- build scripts and proc macros included.

return {
  servers = {
    rust_analyzer = {
      binary = "rust-analyzer",

      config = {
        settings = {
          -- The hyphen is rust-analyzer's own spelling of its settings root,
          -- so the key has to be quoted.
          ["rust-analyzer"] = {
            -- Clippy rather than `cargo check`: same compiler front end plus
            -- several hundred extra lints. No `checkOnSave` beside it, since
            -- that defaults to true.
            --
            -- The cost: clippy and `cargo check` do not share a build cache,
            -- so the first save in a session recompiles the dependency graph
            -- under clippy's flags.
            check = { command = "clippy" },

            -- Rust doc comments link with rustdoc's own `[`Type`]` shorthand,
            -- and rust-analyzer expands each one into a full docs.rs URL
            -- before sending the hover. Neovim then conceals the URL but
            -- still measures the line with it, so one link makes the float a
            -- hundred columns wider than its text and wraps the sentence in
            -- the middle of itself. Off, the link text stays and the URL
            -- never arrives.
            hover = { links = { enable = false } },
          },
        },
      },
    },
  },
}
