# IMP-021: Keys for diagnostics and LSP actions: flymake next/prev, consult-flymake, eglot rename/code actions

<!-- Backlog item body — context, detail, links. The structured, queried fields
     live in the sister `backlog-NNN.toml`; this prose is free-form and is never
     structurally parsed (the storage rule). -->

## Problem

The check-and-fix half of the edit / check / fix loop has no keys.
Resolved live (2026-10-08) in an `emacs-lisp-mode` buffer with
`flymake-mode`, and in `eglot-mode-map`: these reach only the menu bar
or `M-x`:

- `flymake-goto-next-error`, `flymake-goto-prev-error`
- `consult-flymake`
- `eglot-rename`, `eglot-code-actions`

The navigate half is bound: `M-.` (`embark-dwim` → xref), `M-,`,
`M-?`, `M-g n` (`next-error`), `C-c p c` (`project-compile`).

## Want

Bind them in the mode maps (`flymake-mode-map`, `eglot-mode-map`),
not `global-map`, so they appear only when the mode is active. Write
them as `:bind (:map flymake-mode-map …)` / `(:map eglot-mode-map …)`
on the owning `use-package` (SL-014 rule R1). SL-014's lints cover mode
maps too: L2 rejects `define-key` / `keymap-set`, and L3 fails on any
(map, key) written twice. Sequenced after SL-014. Candidates to weigh:
`M-g` family for diagnostics nav (beside `M-g n` / `M-g p`), a
`C-c` family letter for eglot actions per `docs/KEYS.md`. Consider
whether flymake should feed `next-error` instead of new keys.

Name the keys in `CHANGELOG.md` when done.
