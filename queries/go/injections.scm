;; extends

;; SQL inside Go strings, marked by a /* sql */ comment right before the
;; string.
;;
;;   const q  = /* sql */ `SELECT 1`
;;   var   q  = /* sql */ `SELECT 1`
;;   q       := /* sql */ `SELECT 1`
;;   q        = /* sql */ `SELECT 1`
;;   db.Query( /* sql */ `SELECT 1`, arg)
;;
;; Two patterns, because the comment is not always the string's sibling. In a
;; call it sits directly beside the string; in any declaration or assignment
;; the grammar wraps the string in an `expression_list` and the comment sits
;; beside that instead. Matching the list without naming its parent covers
;; const, var, := and = at once. `:InspectTree` on a Go file shows the shapes.
;;
;; The capture lands on the *_content node rather than the literal, so the
;; backticks or quotes are never handed to the SQL parser and no offset
;; arithmetic is needed to trim them.
;;
;; The tag is matched loosely on case and inner spacing, so a `/*sql*/` typed
;; by someone else still lights up rather than silently doing nothing.
;;
;; If this ever stops working, check the `sql` grammar is installed before
;; suspecting the query. An injection whose target grammar is missing fails
;; silently: the string just renders as a plain string, with no error anywhere.
;; `:MivnInstallGrammars` installs it. The `;; extends` above matters too; it is
;; what adds these rules to nvim-treesitter's own Go injections (regex, printf)
;; rather than replacing them.
;;
;; The other way it goes quiet is a language server marking the whole literal
;; as a string: a semantic token is drawn above tree-sitter and paints over
;; every colour in here, so the SQL parses and still looks like a string.
;; colors/basalt.lua clears `@lsp.type.string` for that reason. `:Inspect` on a
;; keyword is what tells the two apart: it lists the tree-sitter capture and
;; the semantic token side by side, with the priority each is drawn at.

; db.Query( /* sql */ `...`, arg)
((comment) @_sqltag
  .
  [
    (raw_string_literal
      (raw_string_literal_content) @injection.content)
    (interpreted_string_literal
      (interpreted_string_literal_content) @injection.content)
  ]
  (#lua-match? @_sqltag "^/%*%s*[sS][qQ][lL]%s*%*/$")
  (#set! injection.language "sql"))

; const/var q = /* sql */ `...`   and   q := /* sql */ `...`   and   q = ...
((comment) @_sqltag
  .
  (expression_list
    [
      (raw_string_literal
        (raw_string_literal_content) @injection.content)
      (interpreted_string_literal
        (interpreted_string_literal_content) @injection.content)
    ])
  (#lua-match? @_sqltag "^/%*%s*[sS][qQ][lL]%s*%*/$")
  (#set! injection.language "sql"))
