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

### Done (2026-07-12)

`my/denote-promote-subtree` implemented, TDD red→green. Promote suite 7/7
green (2 new wrapper tests + 5 pre-existing pure ones). Wired: init.el require
after dl-denote-journal, `C-c n p` on `my-notes-map`.

Findings worth keeping:

- **OQ-1 held as pinned.** Extract leaves the new note buffer current + often
  unsaved (`denote-save-buffers` nil) → wrapper `save-buffer`s and takes the
  title from the pre-call heading, ID from the new file name. Tags → keywords,
  subheadings carried, note lands in let-bound `denote-directory`. A1 clean.
- **`should-error :type 'quit` does not catch `quit`** (not an `error`
  subtype) — the signal escapes ert. Use explicit `condition-case ... (quit)`.
- **`just check` was fully dead (SL-012 satan-extraction fallout).** Orphan
  `lisp/test/dl-sleipnir-doctor-test.el` hard-required the deleted
  `satan-memory-evidence`; one LOADERR aborts the whole harness at 0 tests.
  Removed the orphan (user-approved quarantine). Gate now scans an *empty*
  `lisp/test/` → vacuous `PASS 0/0`; the org suites (journal, promote) were
  never in `dl-test-suite-dirs`. Full write-up + fix path in **ISS-007**.
- Pre-existing unrelated red: `dl-denote-journal/personal-daily-nav` (jail
  path `/workspace/notes` vs test's hardcoded `~/notes/`). Not SL-013.

### VH-1 handoff (user's live e2e — PENDING)

Verify in live Emacs (not batch):
1. Open a real journal file, put point on a subtree with a heading + tags.
2. `C-c n p` → pick a class dir (e.g. `slips`) at the prompt.
3. Assert: new denote note created in that dir; subtree replaced by a
   level-preserving stub `*… → [[denote:ID][heading]]`; `C-c n b`
   (`denote-backlinks`) from the new note resolves back to the stub link.
4. Quit the prompt with `C-g` on another subtree → buffer untouched.
5. which-key shows "promote subtree" on `C-c n p`.
Nix note: the new `dl-denote-promote.el` + init require need `home-manager
switch` (+ `nix flake update pub` / `direnv reload` for the devshell emacs)
to load at runtime in the real editor — see PHASE-01 wiring findings above.
