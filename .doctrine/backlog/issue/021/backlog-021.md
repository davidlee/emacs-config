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
