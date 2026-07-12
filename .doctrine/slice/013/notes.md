# Notes SL-013: Note-system revival: subtree promotion + review views

Durable per-slice scratchpad — tracked in git. The place to lift anything from a
disposable phase sheet (`.doctrine/state/.../phase-NN.md`) that must survive
`rm -rf` before the slice close-out audit harvests it.

## PHASE-01 (2026-07-12)

Done. 5/5 VT green in old + new devshell env; `just check` green; f081cbb +
lock/doc edits (swept into user's a0872a3 "tidies").

Findings worth keeping:

- **Design A2 was wrong; AGENTS.md was wrong.** No use-package parsing exists.
  Package list is manual: `~/flakes/pub/emacs.nix` (`emacsWithPackages`).
  AGENTS.md corrected in-place this phase. Wiring a new package = 1 line there
  + `home-manager switch` + (for devshell/tests) `nix flake update pub` +
  `direnv reload`. Two emacsen, one list.
- home-manager switch initially failed on unrelated breakage: user's dirty
  nixpkgs bump removed `neofetch` (frivolity.nix). User chose swap→fastfetch
  (already listed; dead line deleted). Not slice scope; noted for audit.
- use-package `:commands` on a missing package: byte-compile emits
  "Cannot load denote-org" **info** message, not a warning — compiles clean
  under error-on-warn, loads fine, autoload fires when package appears. The
  lazy-wiring pattern from design D4 works as intended.
- Concurrent repo activity mid-phase (SL-012 close, satan/ deletion, user
  "tidies" commits) — SL-013 commits verified ancestors, no conflicts.

## PHASE-02 — behaviour pin (OQ-1)

`denote-org-extract-org-subtree` present in new env (`fboundp` → t). First
red test must pin: return value, current buffer after call, front-matter of
created file.
