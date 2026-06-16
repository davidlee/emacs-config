# SL-009: SATAN pattern records and scars - outcome-linked pattern-local learning

# DE-009 – SATAN pattern records and scars - outcome-linked pattern-local learning

```yaml supekku:delta.relationships@v1
schema: supekku.delta.relationships
version: 1
delta: DE-009
revision_links:
  introduces: []
  supersedes: []
specs:
  primary: []
  collaborators: []
requirements:
  implements: []
  updates: []
  verifies: []
phases: []
```

```yaml supekku:delta.context_inputs@v1
schema: supekku.delta.context_inputs
version: 1
entries:
  - type: note
    ref: ~/notes/intake/20260519T003129--satan__agent_emacs_project.org
    summary: >-
      SATAN vision synthesis §7 (patterns/scars) + §3 (missing pieces). Specifies
      pattern record shape, scar semantics, and the outcome→{global,pattern}
      dual-update rule.
  - type: doc
    ref: docs/satan/attributes/patterns_attributes.design_note.md
    summary: >-
      Normative design note. Global attributes vs pattern-local scars; rules out
      pattern-specific attribute vectors; gives canonical pattern record shape and
      what-updates-what.
  - type: doc
    ref: docs/satan/epistemics-roadmap.md
    summary: Gap analysis + 3-step sequencing (patterns/scars → probe → hypothesis). This delta is step 1.
  - type: policy
    ref: POL-001
    summary: >-
      Extraction test. Pattern store is pure DB-backed logic (no editor primitives)
      — an incidental elisp tenant. Co-locate with attribute/memory layers for v1;
      flag as future extraction candidate, do not extract now.
```

```yaml supekku:delta.risk_register@v1
schema: supekku.delta.risk_register
version: 1
risks:
  - id: R1
    title: "Pattern-creation source undefined"
    summary: >-
      Pattern-creation source undefined. Doc says patterns form from "repeated
      resonance, model insight, or user concern" — auto-mining vs curated seed is a
      DR decision. Wrong choice risks pattern sprawl or a dead empty store.
    mitigation: >-
      v1 = curated/seeded registry + explicit creation only; defer auto-mining from
      recurrence to a later delta. Resolve in DR-009.
    likelihood: medium
    impact: medium
  - id: R2
    title: "Ceiling/cooldown fields recorded but unread"
    summary: >-
      intrusion_ceiling / cooldown_until are recorded on pattern records but no
      action gate reads them yet (action selection still attribute-driven).
    mitigation: >-
      v1 records + maintains these fields; enforcement at the action gate is a
      named follow-up, not in scope. Avoid implying the gate honours them.
    likelihood: high
    impact: low
  - id: R3
    title: "Coupling to outcome observer regresses attributes"
    summary: >-
      Coupling to outcome observer. Extending the classified-outcome path risks
      regressing the existing global-attribute update (DE attribute layer).
    mitigation: >-
      RESOLVED in DR-009 §3.2. Patterns are a derived SQL projection rebuilt at the
      END of the observer tick, after classification + global enqueue commit, behind
      a guard that swallows rebuild/load/migration failures. The global path is never
      on the pattern code path. Non-regression is structural, not asserted
      (VT-rebuild-guard + VT-global-attr-regression).
    likelihood: low
    impact: medium
  - id: R4
    title: "Attribution input must be audited + deterministic"
    summary: >-
      External adversarial review (codex): matching against the mutable percept.json
      side-artifact makes rebuild non-deterministic (history depends on filesystem
      state) and blames co-present context rather than what the intervention fired on.
    mitigation: >-
      RESOLVED in DR-009 DEC-4. Snapshot the run's percept handles onto the
      intervention.created audit event (new immutable satan_interventions.
      percept_handles_json). Attribution is a pure JSONB-containment SQL join over
      audited, immutable data — deterministic and rebuildable.
    likelihood: low
    impact: high
```

## 1. Summary & Context

- **Technical Spec(s)**: none — project is delta-first, no tech-spec artefacts on disk.
- **Implementation Plan**: [IP-009](./IP-009.md) – not yet planned (DR pending).
- **Change Drivers**: intake note `20260519T003129` (SATAN vision §3/§7); design note `patterns_attributes`; gap analysis in `docs/satan/epistemics-roadmap.md`.

## 2. Motivation

SATAN's outcome observer already classifies matured interventions (worked / ignored
/ neutral / contradicted / harmful) and the attribute-listener turns those verdicts
into **global** attribute deltas (Shame, Doubt, Brooding, …). That is the *metabolism*
half of learning. The *epistemic* half is unbuilt: nothing accrues against the
recurring context-shape that the intervention acted on.

The `patterns_attributes` design note mandates that each outcome update **both** global
attributes **and** the implicated pattern record. Only the global half exists, so:

- no `pattern.contradicted_count` / scars accrue → no pattern-local learning;
- no per-pattern cooldown or intrusion ceiling can form;
- "scar when wrong" (vision §16) has no substrate.

This delta builds the missing half. It is the cheapest, highest-leverage step
(extends an existing mechanism rather than greenfield) and is a prerequisite for the
later probe and hypothesis layers (epistemics-roadmap steps 2–3).

## 3. Scope & Objectives

- **Primary Outcomes**:
  - Persistent **pattern definitions** (`satan_patterns`) keyed by a conjunctive
    `cue_handles` shape, with: `default_intervention`, `intrusion_ceiling` (recorded,
    not enforced), `priority`, `enabled`, `notes`. Curated in a checked-in
    `satan/patterns.eld`, synced idempotently with grammar validation.
  - Each intervention carries an **immutable audited snapshot** of its run's percept
    handles (`satan_interventions.percept_handles_json`, stamped at `intervention.created`).
  - **Derived attribution projection** (`satan_pattern_outcomes`): each mature,
    non-`unknown` outcome attributed to every pattern whose `cue_handles ⊆` the
    intervention's snapshot (JSONB containment). Counters + scars + `last_tested_at`
    + `last_outcome` exposed via `satan_pattern_stats`; scars =
    contradicted/harmful rows (narrative in `outcome.evidence_json`).
  - Rebuilt as a guarded, advisory-locked SQL projection at the **end** of the observer
    tick — derive-don't-push; no change to the global-attribute path.
- **Operational Constraints**: structural non-regression of the global-attribute path
  (R3); audited/immutable attribution inputs (R4); DB-backed (psql via `dl-satan-db`);
  forward-only migration alongside memory/attribute tables.
- **Dependencies**: none must land first; rides existing observer + interventions projection.

## 4. Out of Scope

- **Action-gate enforcement** of `intrusion_ceiling` / `cooldown_until` (R2) — and
  **`cooldown_until` derivation itself**: belongs with the action gate, deferred.
- **`last_seen_at`** (cue-shape present in any percept, not just outcome-bearing runs) —
  needs a percept scan; belongs with the live read/match path.
- **Auto-mining** patterns from recurrence/resonance — v1 is curated `patterns.eld` (R1).
- **Live read/match path** into the percept loop (matched-pattern ids surfaced to a run).
- **Probe surface** and **hypothesis board** — roadmap steps 2–3, separate deltas.
- **Habitat rendering** of matched patterns/scars into the tank/capsule — follow-up.
- Module **extraction** (POL-001) — co-locate for v1; flag as candidate only.

## 5. Approach Overview

- **System Touchpoints**:
  - new `satan/dl-satan-pattern.el` — parse/sync `patterns.eld` (grammar-validated),
    `satan-pattern-rebuild` (SQL projection), read accessors;
  - new `satan/patterns.eld` — curated definitions (data);
  - new `satan/memory/migrations/0007_patterns.sql` — `ALTER satan_interventions ADD
    percept_handles_json`; `satan_patterns`; `satan_pattern_outcomes`;
    `satan_pattern_stats` view; GIN index;
  - `satan/dl-satan-intervention.el` — stamp `percept_handles_json` at `intervention.created`;
  - `satan/dl-satan-broker.el` + `dl-satan-run.el` — thread `:percept-handles` into tool-ctx;
  - `satan/dl-satan-observer.el` — guarded/isolated `satan-pattern-rebuild` at tick end.
- **Key Changes**: percept-handle snapshot on interventions; pattern definitions + sync;
  containment-based rebuild projection.
- **Migration / Rollout Notes**: forward-only; `ADD COLUMN DEFAULT '[]'` backfills
  harmlessly; empty `patterns.eld` is a valid cold start; rebuild idempotent + advisory-locked.

## 6. Verification Strategy

- **Acceptance Criteria** (detail in DR-009 §5):
  - A mature `contradicted`/`harmful` outcome whose intervention snapshot ⊇ pattern P's
    handles yields a P scar + counter bump (ERT, seeded DB).
  - `intervention.created` stamps `percept_handles_json` from ctx; nil percept → `[]`.
  - Immature/`unknown` outcomes excluded; a revised-away outcome drops (head-only).
  - Rebuild/load/migration failure is swallowed; classification + `satan_attribute_events`
    intact (structural non-regression).
- **Planned Artefacts**: ERT VTs (containment, sync, snapshot, rebuild, guard, regression);
  VA on a seeded mature outcome + real rebuild. IDs assigned at plan time.

## 7. Follow-ups & Tracking

- **Future Phases / Deltas**: action-gate reads `cooldown_until`/`intrusion_ceiling`
  (+ derives them); live read/match path (+ `last_seen_at`); probe surface (roadmap
  step 2); hypothesis board (step 3); habitat rendering of patterns/scars.
- **Resolved in DR-009**: creation source (R1 → `patterns.eld`); coupling (R3 → derived
  projection, structural isolation); attribution soundness/determinism (R4 → audited
  percept snapshot); scar shape (structured edge, narrative in `evidence_json`).

## 8. Implementation Notes

- Verification: `just check`. Elisp paren check `bin/elisp-locate-paren-error FILE`
  after every `.el` edit (AGENTS.md). New `.el` files must be `git add`-ed for the Nix
  parser to see them, then `home-manager switch`.
- Mirror `0006_interventions.sql` for the projection + tx-wrapped rebuild idiom, and
  `dl-satan-intervention.el` for the audit-payload-stamp + insert shape — do not invent
  a parallel pattern. (No listener: this is a derived projection, not a queue consumer.)
