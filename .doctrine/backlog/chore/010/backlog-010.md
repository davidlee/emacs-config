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
