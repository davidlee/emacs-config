---
id: DR-010
slug: decouple_satan_perception_from_agent_run
name: Design Revision - Decouple SATAN perception from agent run
created: "2026-06-08"
updated: "2026-06-09"
status: accepted
kind: design_revision  # one of: audit | delta | design_revision | issue | memory | phase | plan | policy | problem | prod | requirement | risk | spec | standard | task | verification
aliases: []
owners:
  - name: David Lee
relations:
  - type: implements
    target: DE-010
delta_ref: DE-010
source_context:
  - ADR-001
  - ADR-002
  - ISSUE-001
  - IMPR-012
  - IMPR-013
  - POL-001
code_impacts:
  - path: satan/dl-satan-broker.el
    current: perceive runs inside --spawn, downstream of the budget gate
    target: perceive runs after run-dir creation, before the session/budget gates; both denial paths mirror :percept into bundle.json
  - path: satan/dl-satan-context.el
    current: assemble-context bundles percept+resonance+motive+sensor_status; probes charge in --spawn
    target: perceive = percept-build + persist + probe read-snapshot; consume = resonance/motive enrichment + probe commit
  - path: NEW per-source ingest cursor store
    current: none
    target: per-source frontier (focus/browser end_ts, content captured_at), advanced on consume, intra-day, exposes backlog depth
  - path: satan/dl-satan-broker.el --write-budget-denied-run + session-blocked branch
    current: slim bundle, no :percept
    target: mirror perceive's :percept into the bundle so observer/baseline consumers see it
verification_alignment:
  - id: VT-budget-denied-perceives
    impact: new
    note: budget-denied + session-blocked ticks write percept.json AND mirror :percept into bundle.json
  - id: VT-perceive-pure
    impact: new
    note: perceive starts no LLM/harness make-process, dispatches no tool, enqueues no attr event, advances no probe/ingest cursor; read-only git/bough call-process probes allowed
  - id: VT-probe-split
    impact: new
    note: probe read at perceive snapshots signal; commit at consume charges + advances the probe high-water mark; budget-denied loses no signal
  - id: VT-cursor-advance
    impact: new
    note: consume advances per-source cursors; perceive never does; doubled/late invocation idempotent within a day
  - id: VT-percept-golden
    impact: regression
    note: percept-build golden tests survive the assemble-context split
  - id: VT-mcp-bundle
    impact: regression
    note: MCP interactive-boot bundle byte-stable after perceive+enrichment recomposition
design_decisions:
  - DEC-perceive-boundary
  - DEC-probes-read-commit-split
  - DEC-cursor-per-source-intra-day
  - DEC-budget-denied-mirror-percept
  - DEC-defer-signal-promotion
  - DEC-spec-authority-stays-doc
open_questions:
  - cross-midnight backlog (per-source cursor is intra-day this delta)
  - perception replayability is NOT delivered here (awaits IMPR-013 promotion)
---

# DR-010 – Decouple SATAN perception from agent run

> **Revision note (2026-06-09).** An adversarial review (gpt-5.5, red verdict)
> showed the original draft conflated two changes: a clean *structural cut*
> (when/whether perception runs; who consumes) and a *signal-model promotion*
> (what perception reads) that carries fan-out into canon/observer/motives/
> alerts. This DR now scopes **only the structural cut**; the promotion is
> [[IMPR-013]]. Probe handling and the cursor are corrected per the review.

## 1. Executive Summary

- **Delta**: [DE-010](./DE-010.md)
- **Status**: accepted
- **Owners / Team**: David Lee
- **Last Updated**: 2026-06-09
- **Synopsis**: Cut the SATAN tick into **perceive** (the deterministic sensing
  pass, run unconditionally before the budget gate) and **consume** (the gated
  LLM run that carries all effects, attribute charges, and the consumption
  cursor). This fixes ISSUE-001 (budget-denied ticks no longer skip perception)
  and separates effects from sensing. It does **not** make perception replayable
  from a watermark — perception still reads present-tense state; closing that
  gap is [[IMPR-013]].

## 2. Problem & Constraints

### Current behaviour

As built (not as `perceptual-design.md` §S1 narrates it), the deterministic
sensing runs *inside* `dl-satan-broker--spawn` (`broker.el:695`), downstream of
the budget gate:

```
broker-run → session gate → budget gate → --spawn
                                             observer-process        (DB writes)
                                             assemble-context        (percept/resonance/motive/sensor_status; persists percept.json)
                                             sensor-alerts-check      (fires notify)
                                             curiosity/content/wpm    (charge attributes, advance probe watermarks; results discarded)
                                             context-fn → bundle.json
                                             make-process (LLM)
```

**ISSUE-001 (the driver).** `broker-run` (`broker.el:687`) diverts
budget-exceeded ticks to `--write-budget-denied-run` (`broker.el:622`), which
writes a slim bundle and **never calls `assemble-context`** → budget-denied ⇒
no percept. Sensing depends on whether the system can afford to think.

### Context — the signal-model gap (deferred, not solved here)

The percept is a fan-in over substrates with different sequencing keys —
replayable segment series vs. present-tense live reads (`current_window`,
`git_state`, `fs_state`) + a separate store (bough). ADR-001's "pure function
over the durable segment log" premise only holds for the replayable subset.
**This DR does not promote the live reads** — that is [[IMPR-013]], split out
because each promotion has downstream fan-out (canon rules, observer predicates,
motives, sensor-alerts). The consequence: after this delta, perception is
budget-independent and effect-separated, but **not yet replayable** — decoupled
late consumption (once [[ADR-002]]'s gate lands) would still fuse archaeology
with wrong-era live state until IMPR-013 closes it.

### Drivers / inputs

- ISSUE-001 — fixed at root here.
- ADR-001 (accepted) — this DR builds the cut and honestly amends the
  side-effect / per-tick-artifact language (§7, ADR-001 amendment).
- ADR-002 (proposed) — relies on this split; its "charge attributes every tick"
  premise is preserved by the probe read/commit split (DEC).
- IMPR-013 — the signal-model promotion (replayability), depends on this.
- POL-001 — perception stays in `.emacs.d` (editor-substrate sensing).

### Constraints / guardrails

- Parcels immutable + append-only; consumption tracked by a separate cursor,
  never by mutating a parcel.
- The capsule stays **recency-biased** (no backlog-spanning capsule).
- Perceive must not mutate consumption state or have user-visible effects; its
  only write is the perception-of-record artifact (see §3).

### Out of scope

- Signal-model promotion / replayability → [[IMPR-013]].
- Arrival gate / metabolic scheduling → [[ADR-002]] / [[IMPR-012]].
- Cross-midnight / multi-day backlog reads (cursor is intra-day this delta).
- Rich backlog accrual (the cursor advances the frontier; no per-segment replay
  pass).

## 3. Architecture Intent

### Target control flow

```
broker-run(name):
  prepare = broker--prepare(mode)          ; alloc run_id, freeze time_now
  mkdir run-dir
  prepare = perceive(prepare, mode, dir)   ; UNCONDITIONAL — no LLM, no effects, no consumption-state mutation
                                            ;   persists percept.json; on error → no-child terminal close, return
  if session-active   → write blocked  bundle MIRRORS :percept ; return
  if budget-exceeded  → write-denied   bundle MIRRORS :percept ; return   ← ISSUE-001 FIXED
  else consume(mode, prepare, dir)         ; effects + tokens + attribute charge + cursor advance + LLM
```

Perception is structurally upstream of every gate. **Transactional ordering:**
run-dir is created before perceive; perceive's only write is `percept.json`; a
perceive error must terminate through the **same no-child terminal path the
budget-denied/session-blocked runs use** — not an ad-hoc status. That path is
the existing convention in `--write-budget-denied-run`: open+close an audit
bundle, set a terminal status with a `:reason`, `.FAILED`-rename the run-dir,
repoint `most-recent`, announce-failure. Reuse it (factor a shared
`broker--write-no-child-run STATUS REASON` helper; budget-denied and
session-blocked become callers) with status `failed` + `:reason
"perceive_failed"`. `perceive-failed` is **not** introduced as a new accepted
status value — the audit status verifier already knows `failed`.

### The perceive / consume boundary

| step | side | rationale |
|---|---|---|
| `percept-build` (evidence → canon, incl. current present-tense reads) | **perceive** | the sensing; deterministic given frozen `time_now` + pinned inputs |
| persist `percept.json` | **perceive** | perception-of-record artifact; the only perceive write |
| probe **read-snapshot** (curiosity/content/wpm) | **perceive** | pure read at perceive-time; cached in `prepare`; **no** charge, **no** watermark advance |
| probe **commit** (charge + advance probe high-water mark) | **consume** | the mutation; charges from the perceive-time snapshot so the charge reflects the moment of perception |
| `observer-process` (outcome accrual, DB writes) | **consume** | effect; runs before motive so the snapshot sees matured `worked_count` |
| `resonance-derive`, `motive-read` | **consume** | prompt-prep — only needed when a model runs |
| `sensor-alerts-check` (fires `notify`) | **consume** | user-visible intervention |
| advance ingest cursor | **consume** | only a real run advances the consumption frontier |
| `context-fn` → `bundle.json`; `make-process` | **consume** | cognition |

**Probe read/commit split (DEC-probes-read-commit-split).** Today the probes'
only output is an attribute charge (their `--spawn` results are discarded). A
naive "probes on the perceive side" is wrong: probes advance *private
high-water marks* and enqueue attribute events — a budget-denied tick would
consume sensor backlog with no run. The split fixes it: perceive takes a pure
read-snapshot (frozen into `prepare`); consume commits the charge from that
snapshot and advances the probe watermark. Budget-denied → no commit → no
watermark advance → the next real run re-reads from the unchanged mark → no
signal lost. Charging cadence = consume cadence; [[ADR-002]] owns its own
cadence.

**Snapshot shape (not just a count).** Today the probe helpers return a charge
*magnitude* and internally advance to the broker `ts`; out-of-order rows behind
`ts` get skipped. So the perceive-side snapshot must carry each source's **native
high-water** — curiosity `end_ts`, content `captured_at`, wpm `last_state` — and
consume must advance the probe watermark to *that snapshot's* high-water, not to
wall-clock `ts`. Same out-of-order discipline as the ingest cursor (§ Cursor).

### Side-effect definition (ADR-001 amendment)

Perceive's only write is `percept.json` (the perception-of-record). All
*consumption-state mutation* (probe watermarks, ingest cursor) and all *effects*
(interventions, tokens, DB outcome writes) are consume-side. ADR-001's
"side-effect-free" is amended to this precise statement (it was already loosely
violated, since perception always wrote `percept.json`).

### Cursor / watermark (per-source, intra-day)

- **Per-source** frontiers, keyed on each source's native field: focus/browser
  on `end_ts`, content on `captured_at`. A single global `end_ts` is unsound —
  the sources use different timestamp fields and can arrive out of order, so a
  global mark would skip late rows behind an advanced frontier.
- **Git is excluded** — git rows key on `%cI` (backdatable via rebase/amend);
  git keeps its existing self-contained 24h look-back window (idempotent by
  re-scan).
- **Intra-day only this delta.** The evidence assembler reads one day-file from
  END; `(cursor, head]` cannot cross midnight today (observer already punts
  cross-midnight). Multi-day reads are deferred (§8).
- `consume` advances the cursors after a successful run; `perceive` never
  touches them. Backlog depth (`head − cursor`) is surfaced for the waybar
  widget and the future gate. Completeness guarantee is **negative** (nothing
  newer-than-cursor silently skipped, within a day); no positive per-segment
  replay pass is built.

## 4. Code Impact Summary

| Path | Current State | Target State |
| --- | --- | --- |
| `satan/dl-satan-broker.el` `broker-run` | budget gate → spawn; perceive inside spawn | mkdir run-dir, then `perceive` before session/budget gates; perceive error → terminal status |
| `satan/dl-satan-broker.el` `--write-budget-denied-run` + session-blocked branch | slim bundle, no `:percept`; budget-denied does `.FAILED` rename + most-recent repoint + announce | factor a shared `broker--write-no-child-run STATUS REASON` helper (budget-denied, session-blocked, **and perceive-failure** become callers); all mirror perceive's `:percept` into `bundle.json` (consumers read `bundle.json → :percept`, not the sidecar) |
| `satan/dl-satan-broker.el` `--spawn` → `consume` | observer + assemble + alerts + probe-charge + LLM | drop percept-build (now upstream); keep observer/resonance/motive/alerts; commit probes; advance cursors |
| `satan/dl-satan-context.el` `assemble-context` | percept + resonance + motive + sensor_status | split → `perceive` (percept + sensor_status + probe read-snapshot) and a consume-side resonance/motive enrichment; MCP boot calls both halves |
| NEW per-source ingest-cursor store | — | per-source frontier persisted; advance on consume; backlog depth |
| `satan/dl-satan-sensor-{curiosity,content,wpm}.el` | read + charge + advance-to-`ts` in one call | factor into pure read-snapshot (perceive) + commit (consume). Snapshot carries the source's native high-water (`end_ts`/`captured_at`/`last_state`); commit advances the watermark to *that*, not to broker `ts` (else out-of-order rows skipped) |
| `docs/satan/perceptual-design.md` | §S1 perceive-in-spawn | update to perceive/consume control flow (signal model unchanged here; note IMPR-013) |
| `.spec-driver/decisions/ADR-001` | side-effect / per-tick language | amend (precise side-effect definition; per-invocation perception-of-record; premise-gap fix deferred to IMPR-013) |

## 5. Verification Alignment

All rows are authored as named ERTs with explicit stubs / forbidden-call spies
(no hand-wave "VA").

| Verification | Impact | Notes |
| --- | --- | --- |
| VT-budget-denied-perceives | new | budget-denied + session-blocked ticks write `percept.json` **and** mirror `:percept` into `bundle.json` — headline ISSUE-001 regression |
| VT-perceive-pure | new | perceive starts no **LLM/harness** `make-process`, dispatches no tool, enqueues no attribute event, advances no probe/ingest cursor (spy harness spawn, `tool-dispatch`, attr-enqueue, cursor writes). Read-only local subprocess probes (`git`, bough via `call-process`) in percept-build are **allowed** — the invariant is "no cognition/effects/consumption-mutation", not "no subprocess" |
| VT-probe-split | new | perceive read-snapshot charges nothing; consume commit charges + advances the probe mark **to the snapshot's native high-water** (not wall-clock `ts` — out-of-order rows not skipped); budget-denied → mark unchanged → no signal lost |
| VT-cursor-advance | new | consume advances per-source cursors; perceive never does; doubled/late invocation idempotent within a day |
| VT-percept-golden | regression | percept-build golden tests survive the `assemble-context` split |
| VT-mcp-bundle | regression | MCP interactive-boot bundle byte-stable after perceive+enrichment recomposition |

## 6. Supporting Context

- ADR-001 (accepted, amended) — decouple perception from cognition.
- ADR-002 (proposed) — arrival gate; relies on this split + probe-charge cadence.
- ISSUE-001 — budget-denied runs skip percept (fixed at root).
- IMPR-013 — signal-model promotion / replayability (split out of this delta).
- DE-010 §7, notes.md — D1 (lazy-materialize), D2 (hybrid), time-locality.

## 7. Design Decisions & Trade-offs

- **DEC-perceive-boundary** — perceive = percept-build + persist + probe
  read-snapshot; consume = probe-commit/observer/resonance/motive/alerts/cursor/
  LLM. Perceive does the deterministic sensing; everything that mutates, acts,
  or only matters when a model runs is consume-side.
- **DEC-probes-read-commit-split** — split each probe into a pure read-snapshot
  (perceive) and a commit (consume). Preserves ADR-002 charge cadence while
  keeping perceive free of consumption-state mutation. Rejected: probes wholly
  perceive-side (budget-denied ticks would consume sensor backlog — the review's
  blocker).
- **DEC-cursor-per-source-intra-day** — per-source frontiers on native
  timestamps, git excluded, intra-day. Rejected: single global `end_ts`
  (unsound across sources / out-of-order rows).
- **DEC-budget-denied-mirror-percept** — denied/blocked bundles mirror
  `:percept` into `bundle.json`, because consumers read it there, not from the
  sidecar. Without this the ISSUE-001 fix is cosmetic.
- **DEC-defer-signal-promotion** — class B→A promotion (replayability) is
  [[IMPR-013]], not this delta. Each promotion has canon/observer/motive/alert
  fan-out; the structural cut is clean and independently valuable.
- **DEC-spec-authority-stays-doc** — perception loop stays doc-canon
  (`perceptual-design.md`, updated here); no SPEC graduation in this delta.

## 8. Open Questions

- [ ] **Cross-midnight backlog.** The per-source cursor is intra-day; `(cursor,
  head]` cannot span day-files today. Multi-day reads deferred — acceptable
  while consumer cadence is sub-daily, revisit if backlog can exceed a day.
- [ ] **Replayability is not delivered here.** Perception still reads
  present-tense state; decoupled late consumption stays semantically lossy until
  [[IMPR-013]]. The cut is still valuable standalone (budget independence, effect
  separation, consumption tracking), but the "archaeology is honest" property
  waits on IMPR-013.
- [ ] **MCP recomposition** — `context-interactive` calls `assemble-context` but
  not `observer-process`; after the split it must call perceive + enrichment in
  the same order to keep its bundle byte-stable (VT-mcp-bundle).

## 9. Rollout & Operational Notes

- **Migration**: no systemd perception timer re-enabled (D1=B). Consumer trigger
  stays manual / waybar until ADR-002's gate lands. Perception reads are
  unchanged this delta (live class-B reads stay).
- **Observability**: per-source backlog depth (`head − cursor`) is the new
  operational signal — surface on the waybar widget.
- **Recovery / rollback**: the cut is internal to broker control flow; reverting
  is restoring perceive into `--spawn` + the budget-denied early return. The
  cursor store is additive (missing/zero cursor = "consume from head").

## 10. References & Links

- `satan/dl-satan-broker.el` (`broker-run`, `--spawn`, `--write-budget-denied-run`, `--prepare`)
- `satan/dl-satan-context.el` (`assemble-context`, `context-interactive`)
- `satan/dl-satan-memory-evidence.el` (`assemble-with-bounds`, `:cue_only`, day-file selection)
- `satan/dl-satan-sensor-{curiosity,content,wpm}.el` (probe read + charge + watermark)
- `docs/satan/perceptual-design.md` §S1
- ADR-001, ADR-002, ISSUE-001, IMPR-012, IMPR-013, POL-001
