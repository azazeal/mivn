-- Auto-closing pairs: `(` inserts `()` with the cursor between them, typing
-- the closing character walks over the one already there, and Backspace inside
-- an empty pair deletes both halves. Defaults untouched.
--
-- Enter is deliberately not claimed here: complete.lua owns the Insert-mode
-- <CR> mapping and calls MiniPairs.cr() on its newline path. The plugin maps
-- <CR> itself only when nothing else has.
require("mini.pairs").setup()
