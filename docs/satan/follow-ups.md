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

## Attribute layer observability (post-T-attr-1e snapshot, 2026-05-29)

Surfaced during a snapshot review showing all 8 attributes mostly
static — `curiosity=0`, `hunger=0.08`, `doubt=0.50`, `shame=0.50`,
`metamorphosis=0.27`, rest at 0.00 — for ~3 days.

- ~~**Curiosity cancels itself daily.**~~ Resolved 2026-05-29 via
  option (b) — `trace_marked` Curiosity delta reduced from −0.05
  to −0.025 (symmetric with Brooding).  Net daily delta now
  +0.025; Curiosity can accumulate from real signal.  See
  design-contract §6H footnote 6.  Per-segment backlog scaling
  (option (a)) deferred to `T-attr-1e-percept` as companion
  cross-source magnitude-scaling work.  Long-term ceiling
  problem remains — only T-attr-2 decay closes it.

- **Outcome pipeline cold — zero real classifications.**
  `satan_intervention_outcomes` is empty.  Only 2 production
  interventions ever (both `inbox`-kind, severity=medium,
  2026-05-24 and 2026-05-27); neither classified.  The 27
  `source=outcome` rows in `satan_attribute_events` all belong
  to one synthetic `morning-aaaaaa` fixture run, not real
  classifications.  Doubt + Shame are stuck at 0.50 because the
  fixture's one `harmful` outcome bumped them and nothing has
  moved them since.  T1.5b shipped a classifier but the observer
  is not producing positives in production.  Diagnosis pre-1d:
  is `dl-satan-observer-classify` wired into a hook that
  actually fires; does the classifier ever return non-null on
  real intervention shapes; should the manual `@satan-intervention-*`
  notes-directive be exercised as the smoke fallback while the
  observer warms up.

- **T-attr-1d capsule render is premature without signal.**
  Rendering a bar chart of 4 hard-zeros and 3 stuck-static values
  surfaces nothing to the model.  Pin the above two findings
  before 1d, otherwise 1d's first deliverable is a thermometer
  for ambient zero.

## Daemon contract pins (post-supervisor + WIP commit, 2026-05-29) — resolved

Captured into `design-contract.md` under T-attr-2a contract amend (2026-05-29).
Remaining work is daemon-side code, tracked on `~/dev/satan-attrd`.

- ~~**JSON null + empty-array render as `{}` in audit payload.**~~
  Contract pinned in §17.4 "Wire-shape requirements" — `null`/`[]`/`{}`
  semantically distinct, no `{}` substitution for the first two.  Daemon
  fix lands as a companion commit on `~/dev/satan-attrd`
  (`run_loop::build_audit_payload` + `rpc::enqueue_audit_event`).

- ~~**`satan-attrd rebuild` non-idempotent.**~~  Resolved by §10.5
  "Idempotence — from-zero replay": rebuild MUST zero the projection
  before replaying events.  Daemon fix lands alongside the JSON wire-shape
  cleanup on `~/dev/satan-attrd`.

## Mind-side items

(Live in `~/notes`, edited via the mind cadence.  Listed here only
because previous handovers tracked them — they're not mechanism
work.)

- _(none open at last sweep — Phase 6, 2026-05-23)_
