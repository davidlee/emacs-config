---
name: satan-follow-ups
description: SATAN follow-ups — durable cleanup/audit items deferred during perceptual-layer v0 phases
metadata:
  type: tracking
  topic: satan
  status: living
---

# SATAN follow-ups

Lasting cleanup, audit, and consistency items surfaced during the
perceptual-layer v0 build (Phases 0–6).  These are not v0 scope cuts
(see `perceptual-design.md` §3 for those) — they are real items with
no urgent owner.  Tick off and remove when shipped.

## Code cleanup

- **Capability migration for inbox / hippocampus / memory tool-specs.**
  Phase 0.2 laid the dispatcher rail (a mode declares `:capabilities`
  and the dispatcher enforces it).  Phase 3 (`motive-write`) and
  Phase 4 (`notify`) added users, but inbox / hippocampus / memory
  tool-specs still guard handler-side.  Mechanical migration: replace
  handler-side gates with `:capability` declarations on the tool spec.

- **Collapse `dl-satan-tools-activity--read-jsonl` onto
  `dl-satan-jsonl-read-file`.**  Phase 5.2 lifted the public
  `dl-satan-jsonl-read-file` out of the activity helper but did not
  delete the original.  Both decoders agree on shape — single-line
  rename + call-site update.

- **Drop dead `(when … nil)` defensive branch in
  `dl-satan-motive-validate-for-write`.**  One-line cleanup; pre-dates
  Phase 5.  Currently the only byte-compile warning in
  `dl-satan-motive.el`.

## Functional extensions

- **Enrich the resonance block with per-match payload text.**
  Phase 2 shipped resonance with `trace_id` + score + matched handles
  only.  Pulling the trace's payload text via `memory_show_trace`
  would let the model recognise the recalled context without an extra
  tool call.

## Consistency

- **A1 strict reading: every run writes `percept.json`.**  Phase 1
  still skips the write on budget-denied runs; Phase 4 also skips
  `pre_spawn` on budget-denied.  Either A1 should be tightened
  (always write) or the design should explicitly carve out the
  budget-denied case.

## Audit verifier extensions

- **A16 one-to-one — `notified.json` ↔ `actions.json.pre_spawn`.**
  Phase 4.4 test asserts the invariant at the producer.  The audit
  verifier (`dl-satan-audit.el`'s `--p/pre-spawn-shape`) does not
  yet cross-check the two artefacts.  Add once a fixture corpus
  exists.

- **A13 one-to-one — `observer.json` ↔ intervention transcripts.**
  Same pattern.  After Phase 5.8 landed, the observer's dedup state
  file is the canonical record of classified interventions; the
  audit verifier should cross-check it against each run's
  `transcript.jsonl`.  Add once observer fixtures exist.

## Mind-side items

(Live in `~/notes`, edited via the mind cadence.  Listed here only
because previous handovers tracked them — they're not mechanism
work.)

- _(none open at last sweep — Phase 6, 2026-05-23)_
