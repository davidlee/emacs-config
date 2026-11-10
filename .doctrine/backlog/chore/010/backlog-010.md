# CHR-010: Dissolve lisp/ into domain directories; move shared tests to test/

<!-- Backlog item body — context, detail, links. The structured, queried fields
     live in the sister `backlog-NNN.toml`; this prose is free-form and is never
     structurally parsed (the storage rule). -->

## Why

`lisp/` reads as "miscellaneous": every other source directory names a domain
(`core`, `editing`, `completion`, `apps`, `org`, `dev`, `lang`). Its files each
have a natural home there. `lisp/test/` is not lisp/'s tests but the shared
test tree for every module, while `org/` colocates its tests — two conventions.

## Moves

| file | to | reason |
|---|---|---|
| `dl-keymap-shadow` | `core/` | key-precedence helper, beside `dl-keymap`/`dl-keybind` |
| `dl-secret` | `core/` | cross-cutting secret access |
| `dl-buffer-management`, `dl-window` | `core/` | buffer/window commands, beside `dl-interface`/`dl-popups` |
| `dl-file-ops` | `editing/` | file helpers, beside `dl-project`/`dl-persist` |
| `dl-insert-elisp-header` | `lang/` | elisp authoring, beside `dl-elisp` |
| `dl-llm-gateway` | `apps/` | gateway client for the `dl-gptel-*` family and minuet |
| `dl-sleipnir-doctor` | `apps/` | SATAN health checks, beside `dl-satan` |

(`dl-umbriel*` moves to `apps/` in SL-016, DEC-014.)

`lisp/test/` → top-level `test/` (decide whether `org/`'s colocated tests join it).

## Touch points

- `git mv` each file (flake builds see only tracked files, trap 1); `require`s are
  by feature name and need no change.
- `core/dl-path.el:3` — drop `"lisp"` from `my/lisp-dirs`.
- `dev/dl-test.el:35` — `dl-test-suite-dirs`.
- `Justfile:24` (`-L lisp -L lisp/test`) and `:63` (line-count find).
- `bin/elisp-locate-paren-error:9` (`-L "$repo_root/lisp"`).
- Delete stray `*.elc` in `lisp/test/`.
- `just check` green; `just clean-eln` after the switch.

Raised while designing SL-016 (2026-11-04).

## Decisions (2026-11-10)

- All tests go to top-level `test/`, `org/`'s colocated tests included
  (`dl-denote-journal-test`, `dl-denote-promote-test`, `dl-review-test`).
  `dl-test-suite-dirs` becomes `("test")`.
- Wait for CHR-013 to land: its `lisp/test/dl-lint-test.el` is untracked and
  `git mv` cannot move it.
- Done directly from this card, without a slice.
- **Single source of truth for the directory list** (folded in from the
  file-structure review). The list is now written by hand in five places:
  `core/dl-path.el:3`, `Justfile:24`/`:63`, `core/dl-policy-lint.el:273`,
  `bin/elisp-locate-paren-error:9`, plus the test dirs in `dev/dl-test.el:35`.
  Make `my/lisp-dirs` the only copy: the Justfile and the paren tool load
  `core/dl-path.el` instead of listing `-L` flags; policy-lint and `dl-test`
  read the variable. CHR-015 depends on this.

## Touch points the card missed

- `core/dl-policy-lint.el:273` lists `"lisp"`.
- `test/dl-umbriel-model-test.el:79`: relative `../../apps` becomes `../apps`.
- `bin/elisp-locate-paren-error:9`: `-L lisp` is stale (`lisp/` holds only a
  stray `.elc` for the tool, whose source is in `tools/`).
- `;; Run: … (dl-test scans lisp/test)` headers in each test file.
- `docs/KEYS.md:442,472` and `docs/emacs/secrets.md:24,70` cite `lisp/…`.
  Leave `docs/REVIEW.md` (historical; see CHR-014).
- Stray `lisp/dl-elisp-locate-paren-error.elc`, `lisp/dl-secret.elc`,
  `lisp/test/dl-secret-test.elc`.
