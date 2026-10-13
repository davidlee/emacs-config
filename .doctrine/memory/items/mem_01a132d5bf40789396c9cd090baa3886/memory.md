On Emacs 30+, flycheck's `emacs-lisp` checker is enabled only for files in
`trusted-content` (CVE-2024-53920 mitigation). This config trusts its own
source dirs (`core/dl-path.el`), so the checker *would* run on config files
and duplicate Flymake's `elisp-flymake-byte-compile` — hence
`flycheck-disabled-checkers` in `dev/dl-diagnostics.el`.

Tests asserting on it from temp files must bind `trusted-content` to
`:all`, or they pass vacuously (the checker is never usable).
