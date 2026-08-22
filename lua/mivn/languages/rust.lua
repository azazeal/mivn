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

            -- Two hints the server keeps off that are worth having on. Most
            -- of its list is already on by default and stays as it is; the
            -- ones left off are noise for me, being restatements of what the
            -- line beside them says.
            --
            -- bindingModeHints is the exception, and it is not a restatement:
            -- match ergonomics inserts `ref` and `ref mut` that are nowhere
            -- in the text, so this is the only way to read what a pattern
            -- actually bound. `with_block` keeps the closure return type to
            -- closures that have a body to hang it off.
            inlayHints = {
              bindingModeHints = { enable = true },
              closureReturnTypeHints = { enable = "with_block" },
            },

            -- A .rs file that belongs to no crate is a thing I open on
            -- purpose, to read someone's code, and being told about it every
            -- time helps with nothing. The same trade as terraform-ls's
            -- ignoreSingleFileWarning.
            diagnostics = {
              disabled = { "unlinked-file" },
            },
          },
        },
      },
    },
  },
}
