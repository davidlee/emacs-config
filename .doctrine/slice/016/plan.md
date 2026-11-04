# Implementation Plan SL-016: umbriel window and workspace control surface

Prose companion to `plan.toml`. Narrative only — no queried data lives here
(the storage rule); the phase list, criteria, verification, and links are
authored in the TOML. Use this for the plan's rationale and sequencing.
<!-- Reference forms: `lib:reference/glossary.md` § reference forms. -->

## Overview

Six phases, built bottom-up along the design's dependency direction
(client ← focus, client + model ← buffer). Each phase ends with `just check`
green, so every commit leaves a working config.

```text
PHASE-01 client: requests + transport ──┬─ focus moves onto it (same phase)
PHASE-02 client: stream + held state ───┤
PHASE-03 model (pure; needs only parse) ┤
PHASE-04 buffer: render + repaint ──────┘
PHASE-05 actions + keys
PHASE-06 docs + changelog + closing checks
```

## Sequencing & Rationale

- **Focus moves in PHASE-01, not later.** `git mv` of `lisp/dl-umbriel.el` and
  the removal of `call-process` would otherwise leave the `server-switch-hook`
  either broken or kept alive on dead code for a phase. The focus file is about
  thirty lines on `dl-umbriel-send`; folding it in keeps PHASE-01 one coherent,
  green commit and retires the stale argv test there.
- **Client split in two (01 requests, 02 stream).** The stream adds the only
  long-lived state; keeping it apart keeps PHASE-01 reviewable and lets the
  fake-transport helper settle before the stream reuses it.
- **Model in its own phase** although it depends only on the parse options: it
  is pure and could run in parallel with 02. Serial is the default.
- **Buffer split display (04) / actions (05).** 04 carries the repaint risk
  (throttle, point, folds, isolation); 05 carries addressing and the user's key
  map. Different risks, different reviewers.
- **Routed RV-018 findings** sit on the earliest phase that holds what they
  need: F-8 and F-9 (transport fake) in 01; F-7 (pure join) in 03; F-11
  (throttle) and F-14 (no live connection from tests) in 04, F-14 re-run over
  the full suite in 06; F-6 (pure plan, two outputs) in 05.

## Notes

**The compositor is reachable from the agent environment.** The slice and
design (Risks; § Verification) say it is not; on 2026-11-04 the user corrected
that, and `UMBRIEL_SOCKET` resolves and `umbriel windows --json` answers from
the agent shell. Live field names match the design's data shapes. The plan
uses this as follows:

- Read-only live probes (queries, subscribe, rendering the buffer) are agent
  checks (`VA`).
- Mutating actions (focus, switch, layout, kill) move the user's desktop and
  remain human checks (`VH`).
- F-14 is a live hazard here, not hypothetical: `just check` on this host
  resolves the socket. Tests must bind `process-environment`.
- Fixtures stay hand-written: the repo is public, live titles are private.

The design's prose is stale on this premise only; no decision depends on it.
Reconcile at `/reconcile` (design § Verification, slice Risks).

**User working-tree edits.** `lisp/test/dl-umbriel-test.el` (PHASE-01 rewrites
it) and `core/dl-keymap.el` (PHASE-05 edits it) carry uncommitted user edits;
both phases have an entrance criterion to settle that with the user first.
