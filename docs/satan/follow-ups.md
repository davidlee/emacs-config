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

- ~~**Collapse `dl-satan-tools-activity--read-jsonl` onto
  `dl-satan-jsonl-read-file`.**~~  Done 2026-05-30 — private helper
  deleted, four call sites (activity ×2, evidence ×2) redirected to
  the public `dl-satan-jsonl-read-file`; explicit `(require
  'dl-satan-jsonl)` added to both consumers.  Bodies were
  byte-identical; no behaviour change.

- ~~**Drop dead `(when … nil)` defensive branch in
  `dl-satan-motive-validate-for-write`.**~~  Done 2026-05-30 —
  unreachable `dormant`/`dormant_reason` lockstep branch removed.
  `dl-satan-motive.el` now byte-compiles clean.

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

- ~~**Outcome pipeline cold — zero real classifications.**~~
  **Root-caused + fixed 2026-05-29.**  `satan_intervention_outcomes`
  was empty not because the classifier was unwired (it runs every
  tick via `dl-satan-broker--spawn` → `dl-satan-observer-process`,
  ~30 min cadence) but because of a **timestamp parse bug**:
  `dl-satan-intervention-pending` dumps the `ts` `timestamptz` via
  `psql -A` as the space-separated `YYYY-MM-DD HH:MM:SS+00` form,
  which `date-to-time` cannot parse (the space defeats
  `parse-time-string`, which drops the time-of-day and mis-shifts
  the date ~1.5 days earlier).  Every intervention therefore read
  `:stale` in `dl-satan-observer--maturity-state` → `classify-for-
  motives` returned nil → `observer-process` recorded
  `:skipped :stale` and **persisted no outcome row**.  With no
  outcome row, the (correct, Postgres-side) pending SQL kept
  re-surfacing the same row every tick until its own 24 h window
  closed, then orphaned it.  Diagnostic evidence:
  `~/notes/satan/runs/2026-05-29/…T180333…/actions.json` showed an
  8.5 h-old intervention skipped as stale while SQL reported it
  in-window.  **Fix:** normalize the cell at the DB-row boundary
  (`dl-satan-intervention--normalize-pg-timestamp`, applied in
  `--row-to-intervention` + `--row-to-outcome`).  The classifier
  and `@satan-intervention-*` manual fallback were never the
  problem — the wiring was sound, the input was malformed.
  Regression tests lock the realistic psql wire shape
  (`dl-satan-intervention/row-to-intervention-ts-parses`,
  `dl-satan-observer/process-classifies-hours-after-emit`).
  The two pre-fix orphans (05-24, 05-27) are SQL-stale and left
  unrecovered (clean break); the two 05-29 rows were still
  in-window and classify on the next tick.

- **T-attr-1d capsule render — unblocked once signal accumulates.**
  The parse fix above re-opens the classification path, but
  `satan_intervention_outcomes` still needs to fill from real ticks
  before 1d renders anything meaningful (and Doubt/Shame begin
  drifting off the fixture-pinned 0.50 as decay + real outcomes
  interact — the T-attr-2 acceptance gate).  Watch for ≥1 real
  outcome row + attribute movement over the following days, then 1d
  is sensible.

## Daemon contract pins (post-supervisor + WIP commit, 2026-05-29) — code-resolved

Both items contract-amended under T-attr-2a (`design-contract.md` §10.5
+ §17.4) and fixed in code 2026-05-29.

- ~~**JSON null + empty-array render as `{}` in audit payload.**~~
  Contract: §17.4 "Wire-shape requirements" + "Locus".
  Diagnostic correction during fix: daemon-side constructors were
  already correct (`null` / `[]` as expected); the offender was the
  **broker** parse in `dl-satan-attribute-listener--claim-row`.
  Fix in broker commit `c263444` — listener parse switched to
  `:array-type 'array :null-object :null`; validator widened.

- ~~**`satan-attrd rebuild` non-idempotent.**~~  Contract: §10.5
  "Idempotence — from-zero replay".  Fix in daemon commit `fb2b33d`
  (`~/dev/satan-attrd`) — `rebuild_projection` wraps in a transaction
  that zeros every `satan_attributes` row before replaying events.
  Tests: `rebuild_is_from_zero_when_event_log_is_empty_for_scope`
  proves the smoke-purge scenario yields zero projection without
  manual operator UPDATE.

## Mind-side items

(Live in `~/notes`, edited via the mind cadence.  Listed here only
because previous handovers tracked them — they're not mechanism
work.)

- _(none open at last sweep — Phase 6, 2026-05-23)_
