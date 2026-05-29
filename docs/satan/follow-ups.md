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

- ~~**Capability migration for inbox / hippocampus / memory tool-specs.**~~
  Done 2026-05-30.  `:capability` added to 6 specs (`inbox_append`,
  `hippocampus_{write,overwrite,delete,rename}`, `memory_mark`); the 5
  handler-side `(memq … caps)` gates removed (the `hippocampus-write`
  handler keeps its `caps` binding for the *separate* `memory-write`
  cross-ref check, §10.7).  **`memory_mark` had no gate at all** —
  `memory-write` was declared on modes but enforced nowhere; the spec
  `:capability` closes that latent hole.  Enforcement now single-point
  in the dispatcher (`dl-satan-tool--capability-denied-p`); error text
  shifts `"mode lacks capability X"` → `"capability denied: tool T
  requires X"`.  Cap checks now run *before* arg-schema validation
  (dispatcher order) — coarser gate first.  All 5 modes verified to
  declare the needed capability wherever the tool is allowed (no
  access regression).  Capability-required tests rerouted handler→
  dispatch; new `memory/mark-capability-required` locks the closed
  hole.  Also fixed a string-vs-symbol bug in the memory test ctx
  (`:capabilities ("memory-write")` → `(memory-write)`) that only
  surfaced once the gate existed.  Suites green (inbox+hippo+memory+
  dispatcher 86/86); `dl-satan-mode-check-tool-references` passes.

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

- ~~**`vcs_log` never reached the model — absent from the cadence
  modes.**~~  Fixed 2026-05-30.  The git-activity sensor commit added
  `vcs_log` to the five hand-written modes (`morning`, `motd`,
  `ruminate`, `self-edit-mech`, `self-edit-mind`) but **not** to the
  two tick modes that actually run on the ~30 min cadence —
  `tick-pulse` (tick defaults, `dl-satan-tick.el`) and `tick-agent`
  (override, `dl-satan-tools-atsatan.el`).  Both run
  `dl-satan-context-tick`, which surfaces the sensor's
  `project:<slug>` handles — so the model saw "repo X is active" but
  had no `vcs_log` to drill in: the percept→tool loop the sensor was
  built for was open.  Added `"vcs_log"` to both tick tool lists
  (read-risk, no capability).  Verified live: `tick-pulse`,
  `tick-agent`, `morning` all expose it.

- ~~**Broker manifest tests red on `vcs_log` description (test-only).**~~
  Fixed 2026-05-30.  `dl-satan-broker/manifest-tools-shape` and
  `…/refuses-spawn-when-budget-exceeded` both build the `morning`
  manifest, which now lists `vcs_log`; `dl-satan-tool--description`
  errors on a missing `.md` (by design).  The runtime file was always
  present (`~/notes/satan/tools/vcs_log.md`) — only the broker test's
  `--with-tool-descriptions` fixture alists lacked the stub.  Added a
  `vcs_log` entry to both alists.  Broker suite 20/20 green.

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
