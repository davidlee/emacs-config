# IMP-027: Keys for minuet: show, minibuffer complete, accept, cycle, dismiss

<!-- Backlog item body — context, detail, links. The structured, queried fields
     live in the sister `backlog-NNN.toml`; this prose is free-form and is never
     structurally parsed (the storage rule). -->

## Problem

minuet (LLM code completion, `apps/dl-minuet.el`; through the local LLM
gateway since SL-015) has no keys. Resolved live (2026-10-18) in an
`emacs-lisp-mode` buffer: these reach only `M-x`, and
`minuet-active-mode-map` (active while ghost text shows) is empty:

- `minuet-complete-with-minibuffer`, `minuet-show-suggestion`
- `minuet-accept-suggestion`, `minuet-accept-suggestion-line`
- `minuet-next-suggestion`, `minuet-previous-suggestion`
- `minuet-dismiss-suggestion`
- `minuet-auto-suggestion-mode` (toggle)

Going through `M-x` while ghost text is up can clear the suggestion, so
the overlay workflow is barely usable.

## Want

Two maps, per SL-014 rule R1 (`:bind` on the owning `use-package`):

- Trigger keys (global or `prog-mode-map`): minibuffer complete, show
  suggestion. minuet's README suggests `M-y` / `M-i`; live, `M-y` is
  `consult-yank-pop` and `M-i` is `tab-to-tab-stop`, so pick elsewhere,
  or under `C-c L` (the LLM family in `docs/KEYS.md`). A toggle for
  `minuet-auto-suggestion-mode` fits `C-c t`.
- `minuet-active-mode-map` (only while a suggestion shows): accept /
  accept line / next / previous / dismiss. README: `M-A` / `M-a` /
  `M-n` / `M-p` / `M-e`. Shadowing `M-a` / `M-e` (sentence motion) only
  while ghost text is up is cheap. `M-n` / `M-p` are unbound globally
  but flymake may claim them (IMP-021); check for overlap.

Document the keys in `docs/KEYS.md` and `CHANGELOG.md`.
