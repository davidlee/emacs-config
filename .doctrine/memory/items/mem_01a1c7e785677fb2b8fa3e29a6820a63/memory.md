`emacs --batch --eval '(let ((byte-compile-current-file t)) (require ...))'`
does not make `byte-compile-current-file` visible to the code it calls.
`--eval` is read with lexical binding, and if `bytecomp` is not loaded yet the
variable has no special declaration. So `(bound-and-true-p
byte-compile-current-file)` in the callee is nil. The SL-018 smoke test
wrote 5 `.elc` files into the umbriel checkout until the guard was fixed.

**How to apply:** in subprocess forms, declare the variable first:
`(defvar byte-compile-current-file t)` at top level (see
`test/dl-umbriel-keys-test.el`), or `(setq ...)` after a `defvar`. Pair it
with a negative control that checks no file was written.
