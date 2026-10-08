# Implementation Plan SL-014: Global keybinding ownership and collision lint

Prose companion to `plan.toml`. Narrative only — no queried data lives here
(the storage rule); the phase list, criteria, verification, and links are
authored in the TOML. Use this for the plan's rationale and sequencing.
<!-- Cite entities by padded id (SL-020, REQ-059); phases as PHASE-01,
     criteria as EN-1/EX-1/VT-1/VA-1/VH-1. See glossary.md § reference forms. -->

## Overview

Three phases: build the lints, migrate the config under them, document.

```
PHASE-01 lints (fixtures only) ──► PHASE-02 gates red → migrate → green ──► PHASE-03 docs
```

## Sequencing & Rationale

- **Lints first.** The real-config L2/L3 gates are the migration's
  checklist: they go red with the exact list of writes to move, and green
  when the migration is complete. Building and testing the rules against
  fixtures first means PHASE-02 trusts the gate.
- **Gates land with the migration, not before.** Committing red gates would
  break `just check`, the commit gate. PHASE-01 commits only fixture tests and
  the L1 gate (green by construction once the allow-list is derived from
  naming). PHASE-02 adds the L2/L3 gates, sees them red locally, and commits
  them green alongside the migration.
- **One migration phase.** The edits are mechanical and the gate covers them
  all; splitting by directory adds ceremony without reducing risk. Commit in
  coherent groups within the phase (dl-keybind consolidation; package
  `:bind` moves; collision resolutions; deletions).
- **"Don't break anything"** is PHASE-02's main risk. Guards: the static
  gates (nothing written twice, nothing written by a stray form), an agent
  check in a fresh Emacs (keys resolve to the intended commands), and the
  user's smoke test after restart. `:bind (:map X)` into another package's
  map is the known trap (design § Risks).
- **Docs last** so they describe what shipped.

## Notes

- The disposable census lives in `research/census.md`; PHASE-02 can rerun the
  scratch script, but the gates are the authority.
- ISS-010's stale `C-=` / `C--` line is corrected at `/close`.
