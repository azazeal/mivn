;; extends

;; SQL inside Go strings, marked by a /* sql */ comment right before the
;; string, loose on case and inner spacing.
;;
;;   db.Query( /* sql */ `SELECT 1`, arg)
;;   q := /* sql */ `SELECT 1`
;;   {body: /* sql */ `SELECT 1`}
;;
;; Three shapes, because the comment is not always the string's sibling: in a
;; declaration or assignment the string sits inside an `expression_list`, and
;; in a struct, map or slice literal inside a `literal_element`. `:InspectTree`
;; shows them. The capture is the *_content node, so the quotes never reach
;; the SQL parser.
;;
;; `;; extends` adds these to nvim-treesitter's own Go injections rather than
;; replacing them.
;;
;; When it goes quiet, check the `sql` grammar first (`:MivnInstallGrammars`),
;; since a missing target grammar fails without a word. Then look for a semantic
;; token painting over it: `:Inspect` on a keyword shows both side by side, and
;; colors/basalt.lua clears `@lsp.type.string` for this.

((comment) @_sqltag
  .
  [
    ; db.Query( /* sql */ `...`, arg)
    (raw_string_literal
      (raw_string_literal_content) @injection.content)
    (interpreted_string_literal
      (interpreted_string_literal_content) @injection.content)
    ; q := /* sql */ `...`, and const, var and = the same way. Only the
    ; first value: a later one needs a tag of its own, which the bare shape
    ; above finds, before its comma or after it where gofmt moves it.
    (expression_list
      .
      [
        (raw_string_literal
          (raw_string_literal_content) @injection.content)
        (interpreted_string_literal
          (interpreted_string_literal_content) @injection.content)
      ])
    ; {body: /* sql */ `...`} in a struct, map or slice literal
    (literal_element
      [
        (raw_string_literal
          (raw_string_literal_content) @injection.content)
        (interpreted_string_literal
          (interpreted_string_literal_content) @injection.content)
      ])
  ]
  (#lua-match? @_sqltag "^/%*%s*[sS][qQ][lL]%s*%*/$")
  (#set! injection.language "sql"))
