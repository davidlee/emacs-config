---
name: satan-refactor-T-attr-1
description: Attribute layer design contract + outcome-driven Shame dispatcher implementation
metadata:
  type: refactor-theme
  topic: satan-refactor
  status: in-progress
  blocked_by: [T1.5]
  updated_at: 2026-05-23
---

# Theme T-attr-1 — Attribute layer (state + event log + Shame dispatcher)

**Impact:** High. **Effort:** L (design + implementation). **Risk:** M. **Reversibility:** Soft (`dl-satan-attribute-updates-enabled` disable switch + projection-rebuild from event log).

`T-attr-1a` (design) blocks the rest. `T-attr-1b` (state + event log) blocks `T-attr-1c` (Shame dispatcher). `T-attr-1d` (capsule render) and `T-attr-1e` (percept/sensor inputs) follow.

This is the first theme in the [attributes core tranche] that `refactor/plan.md` marked out of scope until T1.5b landed. T1.5b's outcome verdicts now exist across the full vocabulary; T-attr-1 is the **attribute-side** consumer. The parallel **pattern-records-side** consumer (per-pattern counters, scars, cooldowns) is a separate theme, governed by [`docs/satan/attributes/patterns_attributes.design_note.md`](../attributes/patterns_attributes.design_note.md) — outcomes feed both, but the two structures live independently. T-attr-1 does NOT block on pattern records; the attribute layer is fully usable without them.

## Current shape

No attribute storage exists in code. The brief (`attributes.brief.md` §0–§6) describes 8 attributes with `[0,1]` values, two SQL tables (`satan_attributes` + `satan_attribute_events`), per-source update rules (§3.3), and a capsule render (§4). None of this is wired. T1.5b's `intervention.outcome_classified` / `outcome_revised` events feed nothing.

## Why it hurts

Brief §7 acceptance criteria 6–8 require Shame to increase on `ignored`/`contradicted`/`harmful` outcomes and suppress Cruelty/raise Doubt. Without the attribute layer:

- Outcome verdicts are recorded but never bias future behaviour. The whole motivation for `outcome-semantics.md` ("mechanically driven Shame deltas") is unrealised.
- Cruelty has no cap → the model is one mis-classified outcome away from escalating friction unbounded.
- The capsule the model sees does not surface attribute pressure → decisions about intervention strength, downgrades, abstention are made on prompt-shape alone, not on the evidence base T1.5b built.
- Operators have no rollback switch for attribute behaviour (refactor/plan.md §6 Q9 promised `dl-satan-attribute-updates-enabled`).

Dropping the Shame dispatcher in as a single PR understates the design (storage schema, event shape, cap semantics, rebuild path all need locking down first). Hence the a/b split mirroring T1.5.

## Target shape

Split into a *design contract* (T-attr-1a, no code) and an *implementation* (T-attr-1b..1e, code in PR-sized increments).

T-attr-1a's deliverable is [`docs/satan/attributes/design-contract.md`](../attributes/design-contract.md) defining: vocabulary (8 attrs, internal `:friction` / public Cruelty), scope (`global` only in v1), storage (`satan_attributes` + `satan_attribute_events` per brief §5), event schema (`attribute.delta_applied` in audit transcript), update rules (per-source delta tables; `:outcome` source maps `worked|ignored|contradicted|harmful|neutral` × `:low|:medium|:high` confidence to the brief §3.3 magnitudes), caps (`friction_cap` per brief §1 Cruelty invariant `friction ≤ 1 - doubt - shame`; `range_clamp` to `[0,1]`), disable switch (`dl-satan-attribute-updates-enabled`), rebuild semantics (projection derivable from event-log replay), A3 boundary (inherits T1.5b's break, no new break), and an explicit list of what is NOT in v1 (per-scope storage, automatic decay, cross-attribute cascade rules, repeated-neutral micro-Shame, model-side attribute read tool).

The contract pins down (post-review):

- **Confidence weighting.** `:low` → 0.5×, `:medium` → 1.0×, `:high` → 1.5×; **upper-bound clamp only** (`0.30`) — `:low` is allowed to produce sub-`small` deltas. Operator-tunable via `dl-satan-attribute-confidence-weights` defcustom.
- **Reduced outcome magnitudes for global scope.** `worked shame` = −0.025 (not −0.05; Shame is durable wrongness memory). `contradicted suspicion` = −0.05 (not −0.15; global Suspicion is ambient by architecture — per-pattern contradiction lives in the pattern record's `contradicted_count`/scar fields, not in scoped attributes). `harmful suspicion` = 0 (verdict alone does not distinguish wrong-suspicion from wrong-timing — pattern-record's `harmful_count` carries the cue-specific consequence).
- **Revision handling.** `intervention.outcome_revised` emits a delta computed against the **actually logged** prior delta (not theoretical), via `evidence_json->>'intervention_id'` lookup. Caps may have reduced the prior delta below its table value; a theoretical-minus-theoretical net would over- or under-reverse. Migration adds an expression index on `(evidence_json->>'intervention_id')`. Revision chains sum prior actual deltas across the chain.
- **Multi-attribute event semantics.** Caps within a single source event use a **pre-dispatch snapshot** of `(doubt, shame)` — per-attribute application order does not affect cap outputs, replay is deterministic.
- **Disable behaviour.** `t` → emit event + UPSERT. `nil` → emit event with `disabled: true`, skip UPSERT, **capsule renders "Attributes: disabled" (NOT the frozen projection)** — stale values would be semantically indistinguishable from "low" attribute pressure.
- **Rebuild modes.** Default-replay skips disabled events (reconstructs actual history). `--include-disabled` replays them (reconstructs hypothetical post-rollback catch-up state). Replay order is `(ts, run_id, seq)` — `seq INTEGER` not lexicographic `id`.
- **Event-log schema.** Adds `seq INTEGER NOT NULL` with `(run_id, seq)` UNIQUE for deterministic intra-run ordering; adds `disabled BOOLEAN` for replay-filter; replay-order index on `(ts, run_id, seq)`.
- **Source reservation vs implementation.** Six source names reserved in the closed enum; only `outcome` IMPLEMENTED in T-attr-1c; validator rejects reserved-but-unimplemented sources. T-attr-1e widens the validator per source it implements.
- **Audit validator widening.** `attribute.delta_applied` accepted with: closed-set `source` against reserved list; per-source `reason` enum (NOT a global pool); `(source, reason)` pairing enforced; `[0,1]` range on `old`/`new`; delta = `new - old` coherence; 8-name enforcement on `name`; `caps_applied` against closed set (`friction_cap`, `range_clamp`); for `source=outcome`, required `evidence.confidence` + `evidence.intervention_id` + `evidence.classification`.
- **Future-scope evidence preservation.** For `source=outcome` events, `evidence_json` carries `intervention_id`, `intervention_kind`, `related_motive_id`, `cue_handles`, `related_trace_ids` so T-attr-2's scoped-Shame migration can replay the event log filtered by cue dimensions.

T-attr-1b's implementation lands the substrate: migration `0007_attributes.sql`, `dl-satan-attribute-store.el` (UPSERT + insert-event + counter + lookup APIs), audit validator widening, no dispatcher yet.

T-attr-1c lands the dispatcher: `dl-satan-attribute-dispatcher.el` consumes `intervention.outcome_classified` / `outcome_revised` via a hook registered into `dl-satan-intervention-classify`'s post-emit path. Applies §6 delta table + §7 caps + §9 disable switch.

T-attr-1d lands capsule render: brief §4 ASCII bar block + one-line derived pressure summary, threaded into the existing capsule registry.

T-attr-1e wires additional sources (`:percept` / `:sensor` / `:resonance` / `:tool_error`) per brief §1 per-attribute "Raises when" sections.

## Migration sketch

- T-attr-1a (this theme): one PR, two documents (contract + this theme doc). No code.
- T-attr-1b: one PR — migration + store + audit-validator widening + store ert.
- T-attr-1c: one PR — dispatcher + outcome-hook + delta-table ert (golden 15-case + cap + disable + revision).
- T-attr-1d: one PR — capsule render.
- T-attr-1e: one PR per source (likely 3–4 PRs).

Order is firm for 1a → 1b → 1c (substrate before consumer). 1d may land before or after 1e — capsule render is decoupled from new sources.

## Considered and rejected

- **Single-PR dispatcher with no contract.** Would lock storage shape + delta magnitudes + cap semantics into code without review. T1.5b's PR 4 follow-up handover already wanted `outcome:*` grammar handles deferred for similar reasons — speculative storage choices are expensive to walk back.
- **Skip the projection table; replay events on every read.** Live capsule render fires every tick; full event replay would dominate broker prepare time within weeks. Projection + rebuild driver matches `satan_intervention_outcomes` precedent.
- **Decay in v1.** A daily idle-decay rule is a behaviour change worth its own contract pass; baking it in pre-observation risks tuning friction down to zero in quiet days. Deferred to T-attr-2 per contract §8.
- **Per-scope storage in v1.** Brief allows `episode | motive:<id> | hypothesis:<id>` but no v1 consumer queries at that resolution. Deferred per contract §13.
- **Audit event named `shame.applied`.** Specific to one attribute. `attribute.delta_applied` covers all 8 + future sources (sensor freshness raises Doubt, not Shame).

## First concrete step

Write [`docs/satan/attributes/design-contract.md`](../attributes/design-contract.md) (delivered in T-attr-1a). The contract feeds T-attr-1b's migration shape + store API surface + audit validator widening.

## Open questions

Carried into the contract's §15 for visibility:

- Confidence weighting magnitudes (Q1).
- Decay schedule (Q2 — deferred to T-attr-2).
- Per-scope storage scope (Q3).
- Event-source vs upsert authority (Q4).
- Repeated-neutral micro-Shame (Q5).
- `evidence_json` shape vs denormalised `intervention_id` column (Q6).

These do not block 1b. 1c may surface tuning open questions on the delta magnitudes once observed.

## PR log

- [ ] T-attr-1a — [`docs/satan/attributes/design-contract.md`](../attributes/design-contract.md) + this theme doc (doc only). Resolves: vocabulary; scope = `global` (with explicit ambient-not-pattern-specific caution per §3.1); storage shapes (with `seq INTEGER` for deterministic replay + `disabled BOOLEAN` for filter); `attribute.delta_applied` event schema; outcome→delta table per brief §3.3 (with global-scope magnitude reductions: `worked shame` −0.025, `contradicted suspicion` −0.05); confidence weighting (upper-bound clamp only); revision net-delta semantics; multi-attribute pre-dispatch snapshot; friction_cap (forward-compat) + range_clamp; disable switch (capsule renders "disabled" not stale values); rebuild from event log with default-skip-disabled vs `--include-disabled` modes; replay-order rule `(ts, run_id, seq)`; source reservation vs implementation distinction; validator widening for `(source, reason)` pairing + required `evidence.confidence` for outcome; A3 boundary; v1 non-inferables. Patched 2026-05-23 from external review (disposition recorded in contract §16). Open questions punted to 1b+: confidence-weight magnitudes (Q1); decay schedule (Q2); per-scope (Q3); event-source-vs-upsert authority (Q4); repeated-neutral (Q5); evidence-json shape (Q6).
- [ ] T-attr-1b — state + event log substrate (no dispatcher).
- [ ] T-attr-1c — Shame dispatcher (outcome → delta).
- [ ] T-attr-1d — capsule render.
- [ ] T-attr-1e — percept / sensor / resonance / tool_error sources.
