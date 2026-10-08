# SL-014 implementation notes

## PHASE-01 — Key policy lints (2026-10-08)

Done. `core/dl-policy-lint.el` now holds L1–L3; `lisp/test/dl-policy-lint-test.el`
(27 tests) runs in `just check`.

- **L1 (D2).** `my-policy-lint-family-maps` deleted. A `C-c <letter>` keymap
  passes iff some bound `my-…-map` variable holds it (one `mapatoms` pass per
  scan, `my-policy-lint--family-maps`). `my-policy-lint-scan` takes an optional
  map for fixtures. `C-c i` (`my-org-iw-map`) is clean by construction; the
  real-config gate (`l1-real-config`, `require 'dl-keymap`) is green.
- **Records.** `my-policy-lint-form-records` walks every subform except
  `quote` data. Positional writers are table-driven (`my-policy-lint--writers`:
  map arg or fixed map, key arg, key syntax, command arg). Three key syntaxes:
  `raw` (define-key / global-*-key strings are event strings, not kbd),
  `kbd` (`:bind`, `bind-keys`, `my/bind`), `keymap` (`keymap-set`,
  `keymap-global-set`). `(kbd "…")` and vectors accepted everywhere.
  Positional map must be a symbol (a call like `(foo)` is non-literal); a
  `:map` list in `:bind` means several maps.
- **Files.** `my-policy-lint-file-records` reads with
  `forward-comment` + `read`; any read error re-signals naming file:line.
  `:file` is relative to `user-emacs-directory`. `my-policy-lint-config-files`:
  `init.el` + top level of the 8 config dirs, minus tests and dotfiles
  (`.#` lock files). Test-file predicate duplicates `dl-test--file-p`
  (dev runner; requiring it from a runtime module would invert the dependency).
- **L2.** `forbidden-form` for the six raw writers, minus R3 family prefixes
  (shape + `core/dl-keymap.el`); `my-bind-foreign-map` for `my/bind` into a
  map not named `my-…-map`.
- **L3.** `seq-group-by` on (map . key); allow-list
  `my-policy-lint-duplicate-allow-list` (empty).

### Dry run on the real config (not committed as a gate — PHASE-02)

371 records (by form: `my/bind` 214, `:bind` 79, `global-set-key` 41,
`define-key` 23, `keymap-global-set` 8, `keymap-set` 5, `global-unset-key` 1);
64 L2 violations; 3 L3 duplicates (`C-z`, `C-:`, ``C-M-` ``). Identical to
`research/census.md`, and `core/dl-theme.el` (lost by the census prototype) now
reads.

### Incidental

- `plan.toml`: the first `[[phase]]` header was commented out
  (`# One [[phase]]`), so PHASE-01 parsed as top-level keys and
  `doctrine slice phases` reported "up to date" without a phase-01 sheet.
  Fixed the header.
- `docs/KEYS.md`: stale "keep family-maps in sync" sentence replaced (rest of
  the docs is PHASE-03).
