# ISS-021: Lint children resolve config dirs against ~/.config/emacs, not the checkout

<!-- Backlog item body — context, detail, links. The structured, queried fields
     live in the sister `backlog-NNN.toml`; this prose is free-form and is never
     structurally parsed (the storage rule). -->

## Observed (2026-11-11, during CHR-010)

`bin/elisp-lint` runs `emacs -Q` with no `--init-directory`, so
`user-emacs-directory` is `~/.config/emacs/` whatever the checkout.
`dl-dirs-load-path` (and before it `dl-path-config-load-path`) expands
against that. In a worktree of an older commit, `just lint` loaded modules
from the main tree: `dl-org-iw-test.el: Cannot open load file …
dl-denote-journal-test`, a file that exists in the worktree but had moved in
the main tree.

`just check` passes `--init-directory={{justfile_directory()}}` and is not
affected.

## Effect

A lint run in a worktree (`/dispatch` workers, a baseline check) tests the
worktree's file against the main tree's dependencies.

## Fix sketch

Pass `--init-directory="$root"` in `bin/elisp-lint` (check it does not break
`bin/elisp-compile-child`'s use by Flymake), or root `dl-dirs` at its own
location.

## Resolution (2026-11-11)

Rooted tracked directories at the checkout, not `--init-directory`:
`--init-directory=$root` would also move `package-user-dir` to the
worktree's `elpa/`, which is untracked and so absent — every `:vc` package
(project-x, lambda-line, ...) would go missing and lint would fail in any
worktree.

- `core/dl-dirs.el`: `dl-dirs-root` is the checkout holding dl-dirs.el.
  `dl-dirs-config` / `dl-dirs-tests` resolve against it;
  `dl-dirs-checkouts` (installed: elpa/org-timeblock, ~/dev/satan) against
  `user-emacs-directory`. Live, the two roots coincide.
- `dev/dl-lint.el`: dropped its own `dl-lint--root` for `dl-dirs-root`.
- Tests: `test/dl-dirs-test.el` states the split and the root rule.
- Verified on a copy of the tracked tree in a scratch dir with a module
  present only there: old dl-dirs fails (`Cannot open load file`), new
  passes; `editing/dl-project.el` (elpa deps) stays clean there.

Not covered: live Flymake in the daemon editing a worktree file still gets
the main tree's dirs (the daemon loaded dl-dirs from ~/.config/emacs).
