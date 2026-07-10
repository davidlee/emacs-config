# Notes SL-012: Extract SATAN to standalone Elisp package

Durable per-slice scratchpad — tracked in git. The place to lift anything from a
disposable phase sheet (`.doctrine/state/.../phase-NN.md`) that must survive
`rm -rf` before the slice close-out audit harvests it.

## 2026-07-10 — design + plan locked, external review integrated

- Design adversarial pass (internal): 9 findings integrated (coupling facts,
  .emacs.d flake teardown, test-runner behaviour, hook symlink, SL-011 ordering
  → D9, memory staleness follow-up).
- Plan: 4 phases, copy-then-cutover (rationale in plan.md).
- External codex review on **RV-010**: 8 findings (1 blocker — Justfile `-L
  satan` hardcode; 5 major; 2 minor), all disposed `fixed`, all verified by
  raiser; ledger `done`. Key deltas: consumer-based decouple scope (13+2
  files), runner anchored off `user-emacs-directory`, git-add-before-flake-eval
  gate, EN-1 waiver requires explicit user /consult approval, PHASE-04 EX-8
  (Justfile), PHASE-02 EX-6 (timeout(1) dep).
- Workflow memory recorded: `mem.pattern.doctrine.codex-external-review`.
- SL-011 status at plan time: `ready` (not closed) — PHASE-01 EN-1 gates on it.
