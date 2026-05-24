---
name: attributes-design-contract
description: Design contract — attribute layer vocabulary, storage, event schema, update rules, caps, and rebuild semantics for SATAN
metadata:
  type: design-contract
  topic: attributes
  status: merged
  feeds: [T-attr-1b, T-attr-1c, T-attr-1d, T-attr-1e]
  authority: blocking
  updated_at: 2026-05-24
---

# Attribute layer — design contract (T-attr-1a)

> **Status.** This is the **contract**, not the implementation. The implementation lands in T-attr-1b..1e (state + event log, Shame dispatcher, capsule render, percept/sensor inputs). Where this document conflicts with code at any point, this document wins — amend the contract first.

> **Document hierarchy.** `attributes.brief.md` defines conceptual intent. This design contract is normative for T-attr-1 implementation; where it differs from the brief, the contract intentionally narrows v1. Where the contract differs from code, the contract wins — amend the contract first.

This document defines the attribute layer: what an *attribute* is, where it lives, what updates it, how updates are clamped + capped, what the audit event for an update looks like, and what v1 deliberately refuses to model.

It exists because the attribute layer is the central bias surface for the agent (`attributes.brief` §4: "Attribute state should enter the prompt capsule compactly"). A noisy attribute layer biases every downstream decision; a layer without caps lets one signal drown the rest; a layer without an event log makes outcome attribution impossible after the fact. The boundary between "what the layer infers" and "what the model interprets" must be drawn before code lands.

---

## 1. Goals + invariants

Attributes are **visible metabolic control variables that bias behaviour** (`attributes.brief` §0). They are not moods. They are not free-form. They are deterministic functions of evidence the layer can cite.

Hard invariants (lifted from `attributes.brief` §0 + per-attribute §1 sections; this contract is normative):

```text
1. Attributes bias behaviour; they never expand permissions.
2. Every attribute update carries (old, new, delta, reason, evidence).
3. Every value clamps to [0, 1].
4. Suspicion without matched handles or explicit current evidence is invalid.
5. Cruelty (friction) is capped by Doubt + Shame.
6. Shame requires negative, contradicted, ignored, or harmful evidence —
   absence of success is not Shame.
7. The model never edits attribute values directly; only the dispatcher does.
```

Goal: make Shame, Doubt, Cruelty, and Metamorphosis mechanically driven by the outcome verdicts T1.5b already produces (`§3.3`), so the capsule the model sees is a function of evidence rather than vibes.

Invariant 1 ("Attributes bias behaviour; they never expand permissions") plus invariant 7 ("The model never edits attribute values directly; only the dispatcher does") together mean: the **dispatcher** is deterministic. Source events may themselves originate from model/tool decisions (e.g. a `:tool_error` source recording a model-issued tool call that failed), but the dispatcher's deterministic mapping of source-event → attribute delta is what this contract pins down.

---

## 2. Vocabulary

Eight attributes per `attributes.brief` §0. Internal names (snake-case keywords) and public labels (the capsule renders public):

| Internal       | Public         | Meaning                                       |
|---             |---             |---                                             |
| `:curiosity`   | Curiosity      | seek evidence / inspect further                |
| `:hunger`      | Hunger         | demand contact, artifact, decision, progress   |
| `:suspicion`   | Suspicion      | prosecute recurrence from handle resonance     |
| `:doubt`       | Doubt          | inhibit certainty and downgrade action         |
| `:friction`    | Cruelty        | bounded adversarial sharpness                  |
| `:shame`       | Shame          | durable wrongness memory                       |
| `:brooding`    | Brooding       | private analysis / rumination / digestion      |
| `:metamorphosis` | Metamorphosis | self-edit pressure                             |

Internal `:friction` / public Cruelty per brief §0 recommendation. The brief is the authority on attribute semantics; this contract does not re-derive them.

---

## 3. Scope

Attributes are **global by design**, not by v1 narrowing.

See [`patterns_attributes.design_note.md`](patterns_attributes.design_note.md):

```text
Global attributes are the animal's metabolism.
Patterns are its prey-shapes.
Scars are where the prey bit back.
```

The brief §5 storage table includes a `scope` column that allows `episode | motive:<id> | hypothesis:<id>`. **The attribute layer does not support `pattern:<id>` or `hypothesis:<id>` scopes — ever.** The contract supplies the column only for possible future global-vs-episode/motive *additive overlays* (small scalars layered onto global values while a motive is active, per `patterns_attributes.design_note.md` §"Optional later: motive-local bias"). V1 writes only `scope = "global"`. Pattern-specific consequences (cooldowns, success/ignored/contradicted/harmful counters, scars, intrusion ceilings) live in **pattern records** — a separate, parallel structure governed by its own theme. Outcomes update **both** the global attribute layer (this contract) **and** the pattern record(s) implicated by the outcome (pattern-records theme, not this one).

Storage shape §4 retains `scope` as a column for the brief-compat reason above, but the dispatcher writes `"global"` for every event in v1; T-attr-1c's tests assert this.

### 3.1 Ambient-not-pattern-specific reading

Because attributes are intentionally global, three of them are **ambient pressures**, not pattern-specific confidence values:

- **Shame.** Global Shame is **ambient wrongness pressure** — durable memory that SATAN has been wrong recently, biasing every future move toward humility. The pattern-specific "this kind of move hurt before" lives in the implicated pattern record's scar list + `harmful_count` / `contradicted_count`, not in a scoped Shame value.
- **Suspicion.** Global Suspicion is **ambient suspicion-pressure** — how predisposed SATAN currently is to prosecute hypotheses in general. Pattern-specific suspicion (this cue matches this pattern's prior traces) lives in the resonance + pattern-record paths, not in the attribute layer. Magnitudes in §6 reflect this (contradicted → `:suspicion -0.05`, not `-0.15` — global ambience changes more slowly than per-pattern confidence would).
- **Doubt.** Global Doubt is **ambient certainty inhibition**. Per-sensor / per-cue doubt lives in sensor freshness + pattern-record fields, not in the attribute layer.

Capsule render (T-attr-1d) MUST surface this — the line "Attributes:" is the organism's metabolism, not its view of any specific prey-shape. The model should never read "Shame moderate" as "the current cue is shame-inducing"; it means "SATAN is currently being humble across the board".

For each outcome event, `evidence_json` carries cue-dimension fields (`intervention_kind`, `related_motive_id`, `cue_handles`, `related_trace_ids`) — **not** for a future scoped-attribute migration (that migration is explicitly off the table per the design note), but so the pattern-records theme can replay outcome events to (re)build pattern records without re-deriving from the audit transcript.

---

## 4. Storage

Two Postgres tables in the existing SATAN database (the same database the broker's memory substrate connects to), introduced by migration `0007_attributes.sql`. Migration is owned by the attribute daemon (`satan-attrd`) — runs explicitly via `satan-attrd migrate`, not on broker start.

### 4.1 `satan_attributes` — current state

```sql
CREATE TABLE satan_attributes (
  scope            TEXT NOT NULL,
  name             TEXT NOT NULL,
  value            DOUBLE PRECISION NOT NULL CHECK (value >= 0 AND value <= 1),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  evidence_json    JSONB NOT NULL DEFAULT '{}'::jsonb,
  PRIMARY KEY (scope, name)
);
```

Shape per brief §5. `value` is the **current** clamp; `evidence_json` carries the **last update's** evidence plist only — it is NOT the full provenance of the current value. For full attribute history, query `satan_attribute_events` (§4.2). Capsule render (T-attr-1d) must not present `satan_attributes.evidence_json` as if it explains the whole accumulated value.

Seed at migration time: insert all 8 attributes with `(scope='global', value=0.0, evidence_json='{}')` so every attribute is queryable from the moment the layer is enabled — no `null` semantics.

### 4.2 `satan_attribute_events` — append-only event log

```sql
CREATE TABLE satan_attribute_events (
  id               TEXT PRIMARY KEY,
  ts               TIMESTAMPTZ NOT NULL,
  run_id           TEXT NOT NULL,
  seq              INTEGER NOT NULL,
  scope            TEXT NOT NULL,
  name             TEXT NOT NULL,
  old_value        DOUBLE PRECISION NOT NULL,
  new_value        DOUBLE PRECISION NOT NULL,
  delta            DOUBLE PRECISION NOT NULL,
  source           TEXT NOT NULL,
  reason           TEXT NOT NULL,
  evidence_json    JSONB NOT NULL DEFAULT '{}'::jsonb,
  caps_applied     JSONB NOT NULL DEFAULT '[]'::jsonb,
  disabled         BOOLEAN NOT NULL DEFAULT false,
  UNIQUE (run_id, seq)
);

CREATE INDEX satan_attribute_events_run_idx ON satan_attribute_events (run_id, seq);
CREATE INDEX satan_attribute_events_name_idx ON satan_attribute_events (scope, name, ts DESC);
CREATE INDEX satan_attribute_events_replay_idx ON satan_attribute_events (ts, run_id, seq);
```

Append-only. `run_id` is **globally unique** across SATAN runs (the broker mints `<UTC-timestamp>-<mode>-<entropy>` ids; collision is not a concern). The `id` shape mirrors intervention id: `<run-id>.attr<NNN>` via a per-run counter (maintained inside the attribute daemon, reset between runs); the `NNN` portion is the human-readable rendering of `seq` and is **not** used for ordering. The `seq` column is the authoritative ordering key within a run; `(ts, run_id, seq)` is the authoritative global replay order (§10).

Test fixtures reset both counter + seq between cases.

`caps_applied` is a JSONB array of cap-name strings whose application reduced the delta (empty `[]` = uncapped; `["friction_cap"]` = friction's `doubt+shame` cap kicked in; see §7).

`disabled` is `true` for events emitted while the broker's `attribute-updates-enabled` switch is off (§9). Rebuild defaults to skipping disabled events (§10).

### 4.3 No outcome columns

The brief §5 also sketches `satan_interventions` + `satan_intervention_outcomes`. Those tables exist already (migration `0006_interventions.sql`, shipped in T7) and remain broker-owned. The attribute daemon **reads** outcomes via the broker's intervention-outcome event stream (§17.2); it does not duplicate the intervention substrate.

---

## 5. Update event — audit transcript shape

Every attribute write emits one `attribute.delta_applied` event into the current run's `transcript.jsonl`. The transcript write is owned by the broker (it is the audit-truth surface — see §17.1); the daemon RPCs the event back to the broker after writing the `satan_attribute_events` row so the projection write, the event-log row, and the transcript line are all in agreement. The event is the canonical wire record; the projection rows in §4 are derivable from replaying this event stream (see §10).

```text
{
  "ts": "<ISO8601>",
  "dir": "broker",
  "event": "attribute.delta_applied",
  "payload": {
    "id":              "<run-id>.attr007",
    "scope":           "global",
    "name":            "shame",
    "old":             0.10,
    "new":             0.25,
    "delta":           0.15,
    "source":          "outcome",
    "reason":          "contradicted",
    "evidence":        {"intervention_id": "<run-id>.iv003",
                        "classification":  "contradicted",
                        "confidence":      "medium"},
    "caps_applied":    [],
    "disabled":        false
  }
}
```

Required payload keys: `id`, `scope`, `name`, `old`, `new`, `delta`, `source`, `reason`, `evidence`, `caps_applied`, `disabled`.

`source` reserves the following closed enum (the source-name space is fixed by this contract so future PRs cannot collide):

```text
outcome       ; intervention verdict (T1.5b feed — IMPLEMENTED in T-attr-1c)
hippocampus   ; hippocampus tool-call signal (IMPLEMENTED in T-attr-1d-hc)
percept       ; percept block produces evidence (reserved; deferred to T-attr-1e)
resonance     ; memory_resonate hit (reserved; deferred to T-attr-1e)
sensor        ; sensor freshness / stale (reserved; deferred to T-attr-1e)
tool_error    ; tool execution failed (reserved; deferred to T-attr-1e)
manual        ; interactive command / notes directive (reserved; deferred; out of T-attr-1)
```

A source name is **reserved** at the contract level but only **implemented** when its `reason` enum is defined in this contract and the dispatcher emits it. The validator rejects events for **unimplemented** sources (§5.1) — reservation alone does not unlock the validator.

`reason` is a closed enum **per implemented source** (see §6 for the `outcome` source's reasons). Validator enforces `(source, reason)` pairing — `source=percept reason=worked` is invalid even when both keys are individually in their enums.

`disabled: true` is emitted when the broker's `attribute-updates-enabled` switch is off — the event is recorded, but the projection is NOT updated (§9).

### 5.1 Audit validator

The broker's existing audit-record validator gains `attribute.delta_applied` as an accepted event with required-key validation against the payload shape above. Validator stays broker-side (it guards transcript-write integrity, which the broker owns). Validator must reject:

- unknown `source` (closed-set enforcement against the reserved list)
- **unimplemented** source (in the reserved list but no `reason` enum defined in this contract)
- unknown `reason` for the source (per-source closed enum, NOT a global pool)
- `old`/`new` outside `[0, 1]`
- `delta` that does not equal `new - old` (sign + magnitude coherence)
- `name` outside the 8 internal names from §2
- `caps_applied` containing unknown cap names (closed-set: `friction_cap`, `range_clamp` in v1)
- for `source=outcome`: missing or invalid `evidence.confidence` (must be `low|medium|high`); missing `evidence.intervention_id`; missing `evidence.classification`

T-attr-1b's broker-side PR ships the validator widening with the `outcome` source + the §6 reasons enum + the required-keys check above. T-attr-1e PRs widen the validator (broker-side) each time they implement a reserved source.

---

## 6. Outcome → attribute delta map (T-attr-1c)

Source `outcome`. Reasons map 1:1 to the five outcome classifications from `outcome-semantics.md` §2 plus `worked`. The dispatcher consumes `intervention.outcome_classified` and `intervention.outcome_revised` events.

Base deltas per `attributes.brief` §3.3, magnitudes per brief §6. **All deltas are reduced from the brief-conceptual magnitudes where the global-only scope (§3.1) would make a per-cue signal accumulate too aggressively.** Notes below the table mark every deliberate v1 narrowing.

| Reason         | Δ friction | Δ shame  | Δ doubt | Δ hunger | Δ suspicion | Δ brooding | Δ metamorphosis |
|---             |---:        |---:      |---:     |---:      |---:         |---:        |---:             |
| `worked`       | 0          | −0.025 ⁽¹⁾| −0.05   | −0.05    | 0           | +0.05      | 0               |
| `neutral`      | 0          | 0        | 0       | 0        | 0           | 0          | 0               |
| `ignored`      | −0.05      | +0.05    | +0.05   | 0        | 0           | +0.05      | 0               |
| `contradicted` | −0.15      | +0.15    | +0.15   | 0        | −0.05 ⁽²⁾   | 0          | +0.05           |
| `harmful`      | −0.30      | +0.30    | +0.30   | 0        | 0 ⁽³⁾       | 0          | +0.15           |

Magnitudes: small = 0.05, medium = 0.15, high = 0.30 (brief §6). The `worked` Shame delta is below `small` at −0.025; this is a deliberate exception (footnote 1) and is permitted to bypass the §6.1 magnitude envelope.

**Column order matters.** The columns are: `friction, shame, doubt, hunger, suspicion, brooding, metamorphosis`. In particular, `contradicted hunger = 0` (column 4 = 0), not `+0.15` — `+0.15` appears in columns 2 (shame) and 3 (doubt). Renderers / readers must not skip column 1 (`friction`) when comparing rows.

**Footnotes:**

1. **`worked` shame is −0.025, not −0.05.** Shame is durable wrongness memory (brief §1); a single positive outcome should not easily wash it away. Halved from `small` to keep Shame from drifting to zero on any successful prompt response. Reviewer flagged: "a single success should not easily wash it away" — patched.
2. **`contradicted` suspicion is −0.05, not −0.15.** Global Suspicion is ambient (§3.1) — the brief's `-0.15` was framed for a per-hypothesis Suspicion that the attribute layer deliberately does not implement (see [`patterns_attributes.design_note.md`](patterns_attributes.design_note.md)). Per-pattern contradiction decrements live in the pattern record (`contradicted_count`, scar append), not in scoped attributes. The global Suspicion delta is reduced to `small` so one local contradiction does not generally lower the system's willingness to prosecute *other* patterns.
3. **`harmful` suspicion is 0.** A harmful intervention may have been correctly suspicious but badly timed; the verdict alone does not distinguish. V1 penalises intervention policy globally (friction down, metamorphosis up) and accumulates pattern-specific consequences in the implicated pattern record's scar/counter fields — the global Suspicion attribute is not the right surface for "this pattern was wrong".
4. **`worked` doubt is −0.05 globally.** Read as **ambient inhibition reduction**, not pattern-specific confidence gain. A successful intervention slightly lowers the system's overall reluctance to act — it does NOT add confidence to the specific pattern that triggered it. Pattern-specific success accumulates in the pattern record's `success_count` + `last_outcome` fields.
5. **`contradicted` hunger is 0, not negative.** Per `outcome-semantics.md`, `contradicted` = "SATAN suspected drift, but the user produced useful artifact from the suspected activity." An artifact emerged, so Hunger could plausibly fall by `small`. V1 holds at 0 because the artifact was produced *despite* SATAN (not in response to it) — the Hunger-falling signal belongs to `worked` (artifact in response to intervention), not `contradicted` (artifact in defiance of suspicion). If observation shows global Hunger drifts too high in contradicted-heavy windows, this row revisits to `-0.05`.

### 6.1 Confidence weighting

The outcome verdict carries `:confidence :low|:medium|:high`. Recommended weighting (open Q §15 Q1):

```text
:low    → multiply base delta by 0.5
:medium → multiply base delta by 1.0
:high   → multiply base delta by 1.5
```

Then clamp the **magnitude** only at the **upper bound** (`0.30`) so a `:high contradicted` does not exceed `harmful`'s magnitude. There is no lower-bound clamp — `:low` confidence is allowed to produce sub-`small` deltas (e.g. `low ignored shame` = `0.05 × 0.5 = +0.025`). A lower-bound clamp would defeat the purpose of `:low` for already-small deltas. Zero deltas (`neutral`, `worked friction`) stay zero regardless of confidence. The `worked shame` exception (−0.025 base) is unchanged by `:low` (`0.5 × 0.025 = 0.0125`) — small deltas degrade gracefully toward zero rather than getting floored up to `small`.

### 6.2 Revision handling

When the consumed event is `intervention.outcome_revised` (`:revises` non-nil), the dispatcher emits a **net** delta that compensates the **actually logged** prior effect, not a recomputed theoretical one. Caps + clamps may have reduced the prior delta below its table value (e.g. shame was already 0.98 → `+0.05` clamped to `+0.02`); a "theoretical minus theoretical" net would over- or under-reverse.

**Revision algorithm.** On `intervention.outcome_revised` for intervention id X:

```text
1. Snapshot (doubt, shame) from current projection per §6.3.
2. For each attribute name N in the union of affected attrs across old + new
   classifications:
     a. Query satan_attribute_events for the most recent event where
          evidence_json->>'intervention_id' = X AND name = N
        (the actual logged prior delta — already cap-adjusted).
        If multiple rows exist from a chain of prior revisions, sum them so
        the cumulative prior effect is what gets reversed.  Call this
        prior_actual[N].
     b. Compute new theoretical delta from §6 table + §6.1 confidence
        weighting for the new (classification, confidence).  Call this
        new_theoretical[N].
     c. revision_delta[N] = new_theoretical[N] - prior_actual[N].
3. For each N: apply §7 caps + clamps against the snapshot.  Emit one
   attribute.delta_applied with delta = revision_delta[N] (after caps).
   evidence carries: intervention_id = X, classification = new, confidence =
   new, revises = <prior outcome pointer per outcome-semantics.md §9>,
   prior_actual = prior_actual[N].
4. UPSERT projection (unless disabled — §9).
```

This anchors the revision to the real prior effect. It is still not perfect — later unrelated events may have moved the projection between the original outcome and the revision — but it correctly reverses what *did* happen rather than what *would have* happened in isolation.

A more robust alternative (two events per attribute per revision: `attribute.delta_compensated` reversing the prior actual, then `attribute.delta_applied` applying the new from-snapshot) is deferred. The single-event-per-attribute shape kept v1 simple; the `prior_actual` field in evidence preserves enough information that a future schema can compute the cleaner two-event form by replay if needed.

Revision-without-projection-change is allowed: if the actual-vs-new computation yields zero for every attribute, the events still emit with `delta: 0.0` so the audit trail is complete.

### 6.2.1 Tracking prior deltas

The query in step 2a uses `evidence_json->>'intervention_id'` to find prior events for the same intervention. The `0007_attributes.sql` migration must add an expression index on `(evidence_json->>'intervention_id')` to keep the lookup cheap:

```sql
CREATE INDEX satan_attribute_events_iv_idx
  ON satan_attribute_events ((evidence_json->>'intervention_id'));
```

The daemon reads back through prior events; revision is a *backwards-looking* operation and must not be optimised by maintaining a denormalised "last delta per (intervention, attribute)" projection — that projection would itself need invariant maintenance and provides no benefit over a single indexed lookup on the event log.

### 6.3 Multi-delta semantics — pre-dispatch snapshot

One outcome event produces deltas for several attributes (e.g. `harmful` writes to friction, shame, doubt, metamorphosis). Caps in §7 depend on current attribute values, so the order in which the per-attribute writes are applied within a single source event matters.

**The dispatcher snapshots `(doubt, shame)` at the start of the source event and uses the snapshot for every cap computation within that event.** This makes per-attribute application order irrelevant: the four deltas a `harmful` outcome produces are commutative because their cap inputs are frozen for the duration of the event.

Implications:

- Within a source event, cap inputs are pre-dispatch values.
- Between source events, cap inputs are post-previous-event values (the projection has been UPSERTed and any subsequent event reads the new values).
- This rule is what makes replay deterministic (§10) even when an event raises both Doubt and Friction: the friction cap uses pre-event Doubt, not the just-raised Doubt.

### 6.4 Neutral

`neutral` produces zero delta in v1. Brief §3.3 hints at "tiny + if repeated many times" — deferred to a future revision (open Q §15 Q5). V1 takes the conservative "no signal, no Shame" path per Shame invariant §1.6.

---

## 6H. Hippocampus → attribute delta map (T-attr-1d-hc)

Source `hippocampus`. Hippocampus tool calls carry metabolic signal about SATAN's internal state: writing a memory means acted-on-pressure; deleting a wrong memory means acknowledged-error; searching without result means knowledge-gap. See [`hippocampus-attribute-signals.md`](hippocampus-attribute-signals.md) for design rationale.

### 6H.1 Reason enum

| Reason        | Trigger                                |
|---            |---                                     |
| `written`     | `hippocampus_write` succeeds           |
| `overwritten` | `hippocampus_overwrite` succeeds       |
| `deleted`     | `hippocampus_delete` succeeds          |
| `renamed`     | `hippocampus_rename` succeeds          |
| `searched`    | `hippocampus_grep` returns 0 matches   |

Read-only tools (`hippocampus_list`, `hippocampus_read`, grep with matches) do not emit — reading is not a metabolic event.

### 6H.2 Delta table

Magnitudes: tiny = 0.025. Consistent with the `worked shame` exception (−0.025) precedent in §6 footnote 1.

| Reason        | Δ friction | Δ shame  | Δ doubt | Δ hunger | Δ suspicion | Δ brooding | Δ metamorphosis |
|---            |---:        |---:      |---:     |---:      |---:         |---:        |---:             |
| `written`     | 0          | 0        | 0       | 0        | 0           | −0.025     | 0               |
| `overwritten` | 0          | −0.025   | 0       | 0        | 0           | −0.025     | 0               |
| `deleted`     | 0          | −0.025   | 0       | 0        | 0           | −0.025     | 0               |
| `renamed`     | 0          | 0        | 0       | 0        | 0           | −0.025     | 0               |
| `searched`    | 0          | 0        | 0       | 0        | +0.025      | 0          | 0               |

Design notes:

1. **Brooding drops on write/overwrite/delete/rename** — the pressure that motivated rumination was acted on. A ruminate run with 5–10 writes produces cumulative Brooding reduction of −0.125 to −0.25 — noticeable but not dominant.
2. **Shame drops on overwrite/delete** — correcting or removing wrong knowledge is acknowledging error (same magnitude as `worked` shame at −0.025, §6 footnote 1).
3. **Suspicion rises on empty grep** — searched for knowledge, found a gap. Small signal that there's something worth investigating.
4. **No friction/hunger/doubt/metamorphosis movement.** Hippocampus tools are inward-facing; they don't affect intervention policy, demand for contact, or self-edit pressure.

### 6H.3 No confidence weighting

Hippocampus actions are binary (succeeded or failed). The §6.1 confidence multiplier does not apply. All deltas are at base magnitude (0.025).

### 6H.4 No revision semantics

Hippocampus actions are final — a write either happened or it didn't. `is_revision` is always `false` for this source. The dispatcher skips `gather_prior_actuals` and revision event paths entirely. A `source_supports_revision` flag on the source enum controls this.

### 6H.5 Evidence shape

For `source=hippocampus`, the `evidence` object carries:

```text
evidence.tool_name    ; string — the tool that triggered the signal (e.g. "hippocampus_write")
evidence.filename     ; string — the hippocampus entry filename acted upon (or query string for grep)
```

No `intervention_id`, `confidence`, or `classification` fields. The validator rejects `source=hippocampus` events carrying outcome-shaped evidence, and vice versa.

### 6H.6 Payload shape

The broker stamps `source: "hippocampus"` in the inbox payload JSON. The daemon routes by this field (absent field → `"outcome"` for backwards compatibility). Payload keys for hippocampus:

```text
schema_version    ; same as outcome payloads
source            ; "hippocampus"
run_id            ; SATAN run id
ts                ; ISO 8601 timestamp
reason            ; one of the §6H.1 reasons
tool_name         ; string
filename          ; string
is_revision       ; always false
enabled           ; broker's attribute-updates-enabled switch
```

### 6H.7 Self-manipulation concern

SATAN can choose to call hippocampus tools, so it can indirectly influence its own attributes. At 0.025 per call, maximum Brooding reduction per ruminate run (budget-tool-calls=30) = 0.75 if every call is a write — but that would consume the entire tool budget on writes with no gathering. Hippocampus_write already emits observation traces (§10.7); attribute deltas add audit visibility via `attribute.delta_applied` in the transcript. See [`hippocampus-attribute-signals.md`](hippocampus-attribute-signals.md) §Self-manipulation concern for full analysis.

---

## 7. Caps + clamps

Two layers of constraint, applied in order:

### 7.1 Friction cap (`friction_cap`)

Per `attributes.brief` §1 Cruelty invariants:

```text
friction ≤ max(0, 1 - doubt - shame)
```

Inputs (`doubt`, `shame`) come from the §6.3 pre-dispatch snapshot, not from values changed earlier in the same source event.

When the dispatcher would write a friction value exceeding this bound, it:

1. Reduces `new` to `max(0, 1 - doubt - shame)` (snapshot values).
2. Recomputes `delta` against the original `old`.
3. Appends `"friction_cap"` to `caps_applied`.

The cap only restrains **positive** friction deltas (raising friction). Negative friction deltas always pass — the system can always become less cruel.

**Forward-compat note.** The §6 outcome deltas never raise friction (`worked` = 0, all negative outcomes lower it). The friction cap therefore has no effect in T-attr-1c's outcome-only dispatcher — it is included now because the schema + cap-name registration must be in place before T-attr-1e sources (`percept`, `resonance`) can raise friction. T-attr-1c's friction_cap test fixture must synthesise a positive friction delta via a direct-store helper (not through the dispatcher's outcome path) since no v1 outcome can produce one.

### 7.2 Range clamp (`range_clamp`)

After source-specific deltas + the friction cap, clamp `new` to `[0, 1]`. If the original delta would have pushed outside the range, append `"range_clamp"` to `caps_applied`.

### 7.3 Order (per attribute, within a single source event)

```text
0. Snapshot (doubt, shame) from projection at event start (§6.3).
1. Compute base delta from §6 table.
2. Multiply by confidence factor §6.1; clamp magnitude at upper bound only.
3. Compute new = old + delta.
4. If name = :friction and delta > 0: apply friction_cap (§7.1) using snapshot.
5. Apply range_clamp (§7.2).
6. Emit attribute.delta_applied with old, new, delta, caps_applied.
7. UPSERT projection (unless disabled — §9).
```

Repeat steps 1–7 for every attribute the source event writes; reuse the step-0 snapshot throughout.

---

## 8. Decay

Open question §15 Q2 — **the decay schedule is deferred to T-attr-2**. V1 ships without automatic decay; values only move on explicit source events. This is deliberately conservative: a daily decay rule that lowers Shame on a cron-like schedule is a behaviour change worth a contract amendment of its own, not a baked-in default.

Implications:

- Shame accumulates monotonically until a `worked` outcome counters it. Per brief, a `worked` outcome on the same `cue_handles` line counts; this is achieved by the existing `worked` delta in §6.
- Operators may manually re-zero attributes via a future `my/satan-attribute-zero` command (out of T-attr-1 scope).

T-attr-2 should add a daily idle-decay rule (`-0.01/day` per brief recommendation, on `shame`/`doubt`/`brooding`/`metamorphosis`) once the dispatcher has been observed in production long enough to see whether automatic decay over-corrects.

---

## 9. Disable switch

An operator-visible disable switch (held in the broker as the
`attribute-updates-enabled` boolean, exposed via the broker's usual
defcustom group) gates the projection write. The broker reports
the current switch state in every outcome-event payload it emits
on the §17.2 event bus; the daemon writes events accordingly. The
switch is the rollback path for the attributes tranche
(CODE_REVIEW.md §6 Q9).

Default: enabled. When disabled: events are still recorded in the
run's transcript + `satan_attribute_events` table with
`disabled=true`, but the projection is untouched and the capsule
renders an explicit disabled marker (not stale values) — the
attribute layer is dark, behaviour reverts to pre-T-attr-1.

Behaviour when **enabled** (default):

- Emit `attribute.delta_applied` event with `disabled: false`.
- UPSERT `satan_attributes` projection.
- INSERT `satan_attribute_events` row with `disabled = false`.
- Capsule (T-attr-1d) renders attribute bars from the live projection.

Behaviour when **disabled**:

- Emit `attribute.delta_applied` event with `disabled: true`.
- Do **NOT** UPSERT `satan_attributes` — projection is frozen at its last-enabled values.
- INSERT `satan_attribute_events` row with `disabled = true`.
- **Capsule (T-attr-1d) MUST render an explicit "Attributes: disabled" marker — it MUST NOT expose the frozen projection values.** Stale frozen values would be semantically indistinguishable from "low" attribute pressure and would mislead the model. The capsule contract is: either omit the attribute block entirely, or render the single-line marker. The model never reads frozen post-disable values.

Rationale: a stuck attribute writer should not corrupt agent behaviour silently. Operators flip the switch off; the capsule renders "disabled" so the model knows the layer is dark; the audit log preserves what the dispatcher *would have* written so a fix-forward can replay events to catch the projection up via `satan-attrd rebuild --include-disabled` (§10).

---

## 10. Rebuild semantics

The projection (`satan_attributes`) is **derivable** from the event log (`satan_attribute_events`) by ordered replay. A `satan-attrd rebuild` subcommand (T-attr-1b) walks events `ORDER BY ts, run_id, seq` and UPSERTs the final value per `(scope, name)`.

`(ts, run_id, seq)` is the authoritative replay order. `ts` is the primary key (real-world time of the event); `(run_id, seq)` deterministically tie-breaks events with identical timestamps within and across runs. The lexicographic `id`-string sort is **not** safe — `attr10` sorts before `attr9` without zero-padding. Replay must use `seq` (integer), not the `id` string.

### 10.1 Default replay — skips disabled events

```text
satan-attrd rebuild
  WHERE disabled = false
  ORDER BY ts, run_id, seq
  → UPSERT projection
```

This reconstructs the projection's **actual** historical trajectory. A disabled-then-re-enabled window appears as a gap in attribute activity; the projection emerges with the values it had at the moment of disable.

### 10.2 Hypothetical replay — includes disabled events

```text
satan-attrd rebuild --include-disabled
  ORDER BY ts, run_id, seq
  → UPSERT projection (using both disabled and live events)
```

This reconstructs what the projection **would have looked like** had the switch never been flipped. Use case: after a rollback debug session, operator wants to fast-forward the projection to where it would be if the layer had stayed live the whole time. The two replay modes produce different projections by design.

### 10.3 Disaster recovery chain

Three levels of recoverability:

```text
projection         (live UPSERT path)
  ↑ rebuild from
satan_attribute_events table
  ↑ rebuild from
audit transcripts (attribute.delta_applied events in transcript.jsonl)
```

T-attr-1b ships projection-from-events rebuild. Transcript-from-files rebuild is deferred (matches the intervention-projection rebuild story which also stops at the table level).

### 10.4 Determinism guarantee

For any totally-ordered sequence of events (by `(ts, run_id, seq)`), replay produces the same final state. Caps in §7 are deterministic functions of `(old, delta, doubt_snapshot, shame_snapshot)` where the snapshot is the projection state at the start of each source event (§6.3); confidence weighting in §6.1 is a deterministic function of the source event's `evidence.confidence` field. No clock dependency in the dispatcher.

---

## 11. A3 determinism boundary

The dispatcher is a deterministic function of audit events whose timing was already non-deterministic post-T1.5b (`intervention.outcome_classified` carries the broker's `:time_now`, not a real clock). Attribute updates **inherit** that break — they do not introduce a new one. A3 (byte-identical-rerun) is already broken at the outcome layer; adding `attribute.delta_applied` events into the same transcript is not a new sanction.

No transcript-level golden test exists for attributes. The broker's percept A3 ert is unaffected. T-attr-1c must not introduce wall-clock dependencies into the dispatcher — the daemon consumes `:time_now` from the source event payload and uses it for the new event's `ts` (no `now()` calls anywhere in the dispatch path).

---

## 12. Test surface

Tests are split by which side of the broker/daemon line they exercise. The daemon's tests live in `satan-attrd` (Rust integration tests against a live Postgres); the broker's tests live in `~/.emacs.d/satan/` (ert against the broker's audit + capsule paths).

T-attr-1b (state + event log) requires:

- **Daemon (Rust integration):** UPSERT round-trip; event INSERT round-trip; rebuild from events; per-run seq counter monotonicity + reset between runs; expression-index lookup is the planned path (EXPLAIN ANALYZE check on `evidence_json->>'intervention_id'`).
- **Broker (elisp ert):** audit validator widens — `attribute.delta_applied` accepted; unknown source/reason rejected; old/new outside `[0,1]` rejected; delta-sign-mismatch rejected; reserved-but-unimplemented sources rejected; for `source=outcome` the required `evidence.confidence` / `intervention_id` / `classification` keys enforced.

T-attr-1c (dispatcher) requires:

- **Daemon (Rust integration):** golden delta table — 5 classifications × 3 confidence levels = 15 cases against the §6 table + §6.1 weighting (the table accounts for the `worked shame` −0.025 exception and the unclamped lower bound); pre-dispatch snapshot test (multi-attribute event ordering does not affect cap outputs); `range_clamp` at upper + lower; disable-switch behaviour (received in source-event payload) records event with `disabled: true`, skips UPSERT; revision-against-actual-prior-deltas (per §6.2 — seed a prior outcome that hit `range_clamp`, then revise; assert `revision_delta = new_theoretical − prior_actual`, NOT `new_theoretical − prior_theoretical`); revision chain (two-step revise; assert `prior_actual` sums across chain).
- **Daemon (Rust integration):** `friction_cap` fixture uses a **direct-store helper** (not the outcome-dispatcher path) to synthesise a positive friction delta — no v1 outcome can produce one (§7.1 forward-compat note). T-attr-1e fixtures rerun the cap against real source events once `:percept` / `:resonance` can raise friction.
- **Daemon (Rust integration):** rebuild driver, both modes — default-replay reproduces projection after disable-then-enable window; `--include-disabled` reproduces the hypothetical projection.

T-attr-1d (capsule render) lives entirely in the broker (capsule is broker-assembled, glue is elisp) and adds its own ert surface. T-attr-1e splits per source: daemon-side dispatch + cap fixture, broker-side validator widening.

---

## 13. What v1 deliberately does not implement

Per the same "what is NOT in v1" discipline `outcome-semantics.md` §10 established:

- **Pattern-specific attribute vectors.** The design note ([`patterns_attributes.design_note.md`](patterns_attributes.design_note.md)) explicitly rules out giving every pattern its own attribute vector or `pattern × attribute` matrix. Pattern-local state (success/ignored/contradicted/harmful counters, scars, cooldowns, intrusion ceilings, preferred interventions) lives in pattern records — a separate, parallel structure governed by its own theme. Attributes stay global by **architecture**, not by v1 narrowing. The `scope` column on `satan_attributes` is forward-compat for the design note's "possibly with episode-local deltas later"; the dispatcher writes `"global"` for every v1 event.
- **Pattern records themselves.** Out of T-attr-1 scope entirely. Pattern records are a separate theme; T-attr-1's `attribute.delta_applied` events carry the cue-dimension fields (`intervention_kind`, `cue_handles`, `related_motive_id`, `related_trace_ids` in `evidence_json`) so the pattern-records theme can consume the same outcome stream without duplicating intervention-lookup logic.
- **Episode/motive scopes for attributes.** Reserved by `scope` column for the design note's optional motive-local bias terms (small additive scalars, not full vectors); not implemented in v1. The "should I implement scope X" question is bounded — there will never be `hypothesis:<id>` attributes.
- **Automatic decay.** Values move only on source events. Reason: §8 — behaviour change worth a separate contract pass.
- **Cross-attribute cascade rules.** Brief §3.3 `contradicted` says `Suspicion - medium for related cue/hypothesis` — the "related cue/hypothesis" half belongs to the pattern-record's `contradicted_count`/scar fields, not the attribute layer. The global Suspicion delta is reduced to `-0.05` accordingly (§6 footnote 2).
- **Repeated-neutral micro-Shame.** Brief §3.3 hints at "tiny + if repeated many times" for `neutral`. V1 = no signal. Pattern records' `ignored_count` carries the "repeated" signal if the pattern-records theme wants to expose it.
- **`harmful → suspicion` penalty.** A harmful outcome alone does not distinguish "right suspicion, wrong timing" from "wrong suspicion". V1's global Suspicion delta is 0 (§6 footnote 3); the pattern-records theme stores the per-pattern harmful_count + scar.
- **Non-zero seeded baselines.** All 8 attributes seed at `0.0`. Brief §6 example shows non-zero starting bars (Curiosity ≈ 0.6, Doubt ≈ 0.3); v1 starts everything at zero. A zero baseline may make the capsule read as "dead organism" until the dispatcher fires; T-attr-2 may revisit baseline seeds once the layer has been observed under load.
- **Brooding force-action guardrail.** Brief §1 Brooding: "If Brooding stays high while Hunger rises, force either action, mark, or explicit abstention reason." Not modelled in v1 — guardrail is a behaviour rule, not a storage rule, and lives in T-attr-2+ alongside capsule routing.
- **Sources beyond outcome.** T-attr-1c only IMPLEMENTS `:source :outcome` even though the source enum reserves five others (§5). Percept / resonance / sensor / tool_error / manual are deferred to T-attr-1e + future themes; the validator rejects events for reserved-but-unimplemented sources (§5.1).
- **Manual override path.** Out of T-attr-1 scope entirely (§14).
- **Model-side attribute reads via tool.** The capsule renders attributes to the model (T-attr-1d). There is no `attribute_get` tool. The model never sees `attribute.delta_applied` events directly; it sees only the rendered capsule.
- **Maintenance / decay / manual events with no run.** All events require `run_id NOT NULL`. T-attr-2 may relax to nullable + synthetic `maintenance:<ts>` run-ids once a non-run-bound source exists.

---

## 14. Manual override path

Out of T-attr-1 scope. The contract reserves `:source :manual` for a future interactive command + notes directive (mirroring `T1.5b` PR 4's `my/satan-mark-intervention-*` + `notes_at_satan_intervention_done`). The pattern is established; the implementation waits until automatic dispatch (T-attr-1c) is observed in production.

---

## 15. Open questions

Decisions intentionally left for the implementation tranche, not the contract:

1. **Confidence weighting (§6.1).** Multiplicative `0.5 / 1.0 / 1.5`, or only-magnitude-direction with no confidence scaling? Recommendation: ship the multiplier as broker-side operator config (`attribute-confidence-weights`) so operators can disable by setting all three to `1.0` without amending the contract. Daemon receives weights via source-event payload or startup config.
2. **Decay schedule (§8).** Daily idle decay or stay manual? Recommendation: defer to T-attr-2; gather production data first.
3. **Episode-local additive bias (§3).** Per the design note, `episode` and `motive:<id>` scopes are reserved as *additive bias terms* (small scalars layered onto global values while a motive is active), not full per-scope attribute vectors. Open: do v1 sources need any episode bias, or defer entirely? Recommendation: defer. No v1 consumer needs it; the column stays unused until a concrete bias requirement surfaces.
4. **Event-source vs upsert authority (§10).** Is the projection authoritative or always recomputed from events? Recommendation: projection is authoritative for live reads; events are authoritative for rebuild. Same shape as `satan_intervention_outcomes` (T7).
5. **Repeated-neutral micro-Shame (§6.4).** Threshold + magnitude? Recommendation: defer; brief hint is too vague to pin down in v1.
6. **`evidence_json` shape vs `intervention_id` denormalisation.** Should `evidence_json` always carry the source event's id, or should events have a typed `intervention_id` column? Recommendation: stay with `evidence_json` (matches `satan_intervention_outcomes.evidence_json` shape; no new schema column).

These do not block T-attr-1b. T-attr-1b may proceed with the §4 storage shapes as fixed.

---

## 16. Change history

| Date | Change | Author / source |
|---|---|---|
| 2026-05-23 | Initial contract — drafted from `attributes.brief` §0–§6 + `outcome-semantics.md` (delta-source) + T1.5b PR 4 manual-override pattern. | T-attr-1a PR. |
| 2026-05-23 | Pre-implementation review patches: §0 doc hierarchy; §1 dispatcher-determinism softening; §3.1 ambient-not-pattern-specific caution + future-scope evidence preservation; §4.1 evidence_json scope clarification; §4.2 add `seq INTEGER` + `(run_id, seq)` UNIQUE + `disabled` column + replay-order index; §5 source-reservation vs implementation distinction + per-source reason enum; §5.1 validator widening for source/reason pairing + required `evidence.confidence` for outcome; §6 `worked shame` reduced to −0.025 + `contradicted suspicion` reduced to −0.05 + `harmful suspicion` documented as 0 with rationale; §6.1 lower-bound clamp removed; §6.3 new pre-dispatch snapshot rule; §7.1 friction_cap forward-compat note + test-fixture guidance; §7.3 step-0 snapshot; §9 capsule MUST render "disabled" not stale values; §10 rebuild splits into default-skip vs `--include-disabled` modes + replay-order rule + disaster-recovery chain; §12 friction_cap test fixture + rebuild ert; §13 extends non-inferables list with `harmful→suspicion`, zero-seeded baselines, manual path, maintenance-run nullable. | External review (item-by-item disposition). |
| 2026-05-23 | Global-by-architecture reframe per [`patterns_attributes.design_note.md`](patterns_attributes.design_note.md): §3 attributes are global by design (not v1 narrowing); pattern-specific consequences live in separate pattern records (cooldowns, counters, scars). §3.1 ambient-not-pattern-specific rewritten — global Shame/Suspicion/Doubt are organism-metabolism, not prey-shape state. §6 footnotes 2+3 rationale repointed to pattern records rather than future scoped attributes. §13 non-inferables list adds explicit "pattern-specific attribute vectors" and "pattern records themselves" entries; "per-scope storage" entry reframed as bounded forward-compat (episode/motive bias only; never `hypothesis:<id>`). §15 Q3 narrowed to episode-local additive bias only. Reviewer finding #5/#6 (global scope blunt) dispositioned as "by design, not bug" — pattern records carry cue-specific consequences in a parallel theme. | External design note (architectural correction). |
| 2026-05-23 | Round-2 review patches: §3 scope wording sharpened — explicit "never `pattern:<id>` or `hypothesis:<id>`"; §6 column-order reading note added (reviewer misread `contradicted hunger`); §6 footnotes 4+5 added — `worked doubt` interpreted as ambient inhibition (not pattern confidence); `contradicted hunger` held at 0 with rationale + revisit trigger; §6.2 revision algorithm rewritten — compute against actually-logged prior deltas via `evidence_json->>'intervention_id'` lookup; new §6.2.1 covers prior-delta tracking + the GIN/expression index for the migration; §12 dispatcher test surface adds revision-against-actual-prior-deltas + revision-chain cases. Reviewer finding #3 (`ignored` vs `neutral` classifier tightening) dispositioned as out-of-scope: lives in `outcome-semantics.md` (merged). | External review round 2. |
| 2026-05-23 | Language-neutralising pass + locus pivot: §4/§4.2/§4.3/§5/§5.1/§9/§10/§11/§12 rewritten to remove elisp-specific implementation references (specific defcustom names, ert file names, `dl-satan-*` function names, `dl-satan-attribute-rebuild` driver name) and replace with broker / daemon role-language. Implementation locus split (daemon owns store + dispatcher + rebuild; broker owns capsule + audit-validator + transcript write + disable-switch UI) is now reflected throughout, not just in the theme doc amendment. New **§17 — Implementation locus + pinned daemon design choices** adopts (a) daemon-writes-table-then-RPCs-back, (b) PG queue + `pg_notify` event bus, (c) daemon-side disable check, all previously recorded only in `T-attr-1-attribute-layer.md` amendment + `extraction-policy.md`. Contract status stays **draft** for one more change-history row; flips to **merged** when T-attr-1b's first code-bearing PR lands. Forward references to broker UX (`my/satan-attribute-zero`, `my/satan-mark-intervention-*`) kept — they describe broker-side surfaces, not daemon implementation. | T-attr-1b scaffold pass (locus pivot landed in `satan-attrd` initial commit `d8a6a10`). |
| 2026-05-23 | T-attr-1c pre-implementation pin: §17.4 adds **RPC error policy on validator reject** — daemon logs at `ERROR` and drops the event, no retry; rationale is that validator rejects are deterministic and a retry loop wastes cycles on contract violations. Transport errors remain retryable with backoff and live in the wiring PR. New §17.7 **Per-run Counter eviction** pins a bounded LRU at capacity 64 with `tracing::info!` on evict; defers explicit `intervention.run_ended` broker signal until the LRU heuristic is shown wrong. `metadata.status` flips **draft → merged** per the precedent set in T-attr-1a (contract becomes canonical with first code-bearing implementation PR; T-attr-1c is that PR for the daemon dispatcher). | T-attr-1c PR (dispatcher pre-flight; pin open questions before code lands). |
| 2026-05-24 | T-attr-1c slice 2 wiring pre-flight pins: §17.3 expanded with the broker→daemon outcome payload v1.0 shape + `schema_version` major-rejection rule + queue table DDL (`satan_outcome_inbox`, `satan_audit_inbox`) + single-thread run-loop concurrency note (no `SELECT FOR UPDATE` in v1 because dispatch is serialized; flagged as a future multi-worker concern). §17.4 expanded with the **reject reply transport** — new `satan_audit_replies` table + `satan_audit_reply` channel; rejects-only (silence on accept). §17.1 expanded to name the broker-side LISTENer + sentinel-death `notifications-notify` defcustoms (`dl-satan-attribute-listener-enabled`, `dl-satan-attribute-listener-notify-app`). | T-attr-1c slice 2 (wiring PR — broker enqueue + daemon run loop + broker LISTENer). |

---

## 17. Implementation locus + pinned daemon design choices

The attribute layer is split across two processes. This section is normative; locus diagrams in `T-attr-1-attribute-layer.md` are illustrative.

### 17.1 Broker (elisp, `~/.emacs.d/satan/`)

Owns:

- The `attribute-updates-enabled` config switch (operator-visible).
- The capsule render block (T-attr-1d). Capsule is assembled broker-side; the daemon exposes a "snapshot attrs" RPC the broker queries pre-spawn.
- `transcript.jsonl` writes. The broker is the audit-truth surface; the daemon RPCs `attribute.delta_applied` events back to the broker for transcript writing (§17.3).
- The audit-record validator (`attribute.delta_applied` widening per §5.1). Validator runs at the transcript-write boundary, which the broker controls.
- Intervention-outcome emission. The broker continues to mint `intervention.outcome_classified` / `intervention.outcome_revised` events from its existing outcome classifier; the daemon is a downstream consumer.
- The broker-side LISTENer on the `satan_audit_inbox` channel (§17.3 → §17.4). Sentinel reports subprocess death via `notifications-notify` with critical urgency, mirroring `dl-satan-patch-listener.el`. Defcustom `dl-satan-attribute-listener-enabled` (default `t`) gates the LISTENer; `dl-satan-attribute-listener-notify-app` (default `"SATAN"`) names the desktop notification app field.
- Any tool handlers exposed to the model (none in v1; the layer is read-only to the model via the capsule).

### 17.2 Daemon (Rust, `~/dev/satan-attrd/`)

Owns:

- Migration `0007_attributes.sql` (§4). Run explicitly via `satan-attrd migrate`; never auto-migrated on broker start.
- The store API (§4.1 + §4.2): UPSERT projection, INSERT event, per-run `seq` counter (reset between runs), prior-event lookup by `evidence_json->>'intervention_id'` (§6.2.1).
- The outcome dispatcher (§6 + §6.1 + §6.3 + §7).
- The rebuild driver (§10): `satan-attrd rebuild [--include-disabled]`.
- The daemon-side LISTENer on the §17.3 event bus.

### 17.3 Event bus shape — broker → daemon

Broker emits `intervention.outcome_classified` / `intervention.outcome_revised` via a Postgres queue table + `pg_notify`. Daemon `LISTEN`s on the channel; on notify the daemon drains the queue row, applies §6 + §7, writes the event row, and RPCs the `attribute.delta_applied` event back to the broker for transcript writing.

Matches the existing `dl-satan-patch-listener.el` pattern (the patch runner uses PG queue + `pg_notify` between broker and the patch daemon). Standardising on that pattern across SATAN-orbit daemons keeps the broker's transport story uniform.

Alternative considered + rejected: direct broker→daemon RPC on each outcome emit. Simpler but couples broker outcome-classification timing to daemon liveness; the queue absorbs daemon restarts and slow consumers without back-pressuring the broker's classify path.

**Queue tables (daemon-owned migrations).**

```sql
CREATE TABLE satan_outcome_inbox (        -- broker → daemon
  id           SERIAL PRIMARY KEY,
  payload_json JSONB       NOT NULL,
  enqueued_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  claimed_at   TIMESTAMPTZ
);
-- channel: satan_outcome_inbox; NOTIFY carries id as text.

CREATE TABLE satan_audit_inbox (          -- daemon → broker
  id           SERIAL PRIMARY KEY,
  payload_json JSONB       NOT NULL,
  enqueued_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  claimed_at   TIMESTAMPTZ
);
-- channel: satan_audit_inbox; NOTIFY carries id as text.
```

**Payload schema versioning.** Both `satan_outcome_inbox.payload_json` and `satan_audit_inbox.payload_json` carry a top-level `"schema_version": "<MAJOR>.<MINOR>"` string. Consumers reject payloads whose **major** does not match the consumer's compiled major. Minor differences are forward-compatible (consumer ignores unknown fields). V1 ships `"schema_version": "1.0"` on both directions. Daemon hard-codes the accepted major; broker validator rejects mismatched major with a clear error string per §17.4.

**Broker → daemon outcome payload (v1.0):**

```json
{
  "schema_version": "1.0",
  "run_id":         "<UTC-mode-entropy>",
  "ts":             "<ISO8601>",
  "intervention_id":"<run-id>.iv<NNN>",
  "classification": "worked|neutral|ignored|contradicted|harmful",
  "confidence":     "low|medium|high",
  "evidence": {
    "intervention_kind":  "<kind>" | null,
    "related_motive_id":  "<motive-id>" | null,
    "cue_handles":        ["..."],
    "related_trace_ids":  ["..."]
  },
  "is_revision":    false,
  "revises":        "<prior outcome pointer>" | null,
  "enabled":        true
}
```

The daemon reads `(doubt, shame)` snapshot + the projection itself from the local `satan_attributes` table — those are not carried across the queue.

**Concurrency / read consistency.** The daemon's run loop is single-threaded (`tokio` `current_thread` runtime) and processes inbox rows sequentially: one notify → claim row → snapshot read → dispatch → write events → next notify. Within one daemon process there is **no** inter-event interleave; the §6.3 pre-dispatch snapshot is naturally coherent without `SELECT FOR UPDATE`. A future multi-worker daemon MUST re-introduce row-level locks on the 8 `satan_attributes` rows for the duration of a dispatch — flag is in run-loop comment.

### 17.4 Audit transcript path — daemon writes table, then RPCs event back

After the daemon writes the `satan_attribute_events` row (and, if not disabled, UPSERTs `satan_attributes`), it RPCs the constructed `attribute.delta_applied` event back to the broker. The broker validates the event against §5.1 and appends it to the current run's `transcript.jsonl`.

Rationale: keeps the existing "transcript.jsonl is audit truth" convention intact (every audit event ultimately lands on the broker's transcript-write path, regardless of which daemon emitted it). Alternative considered + rejected: daemon writes table only, no transcript line. Simpler but diverges from convention — audit verification (`dl-satan-audit-verify-run`) would have to read both `transcript.jsonl` and the daemon's table to reconstruct events.

**RPC error policy on validator reject.** If the broker rejects an `attribute.delta_applied` event at §5.1 validation, the daemon **logs at `ERROR` level and drops the event** — it does NOT retry. Validator rejects are deterministic (a coherent dispatcher cannot fix the payload by sending it again); a retry loop would burn cycles on a contract violation. The event row remains in `satan_attribute_events` (the projection write already happened or was skipped per §9), so `satan-attrd rebuild` continues to reflect the daemon's view; the divergence between table-truth and transcript-truth is the operator's signal that a daemon bug needs investigation. Daemon emits one `tracing::error!` per reject carrying the rejected payload + the broker's error string. Transport-layer errors (connection drop, queue unavailable) are distinct and DO get retried with backoff — that policy lives in the wiring PR.

**Reject reply transport.** The daemon receives the broker's reject verdict on a dedicated channel + table (daemon-owned migration):

```sql
CREATE TABLE satan_audit_replies (        -- broker → daemon, rejects only
  inbox_id   INTEGER PRIMARY KEY,         -- references the original satan_audit_inbox.id
  ts         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  error_msg  TEXT NOT NULL
);
-- channel: satan_audit_reply; NOTIFY carries inbox_id as text.
```

Flow:

1. Daemon enqueues `attribute.delta_applied` payload onto `satan_audit_inbox`, NOTIFY `satan_audit_inbox <id>`.
2. Broker LISTENs `satan_audit_inbox`, claims the row, runs the §5.1 validator.
3. On **accept**: broker appends to `transcript.jsonl`, DELETE FROM `satan_audit_inbox` WHERE id = $. No reply; silence is success.
4. On **reject**: broker INSERTs `(inbox_id, error_msg)` into `satan_audit_replies`, DELETE FROM `satan_audit_inbox` WHERE id = $, NOTIFY `satan_audit_reply <inbox_id>`.
5. Daemon LISTENs `satan_audit_reply`, SELECTs the row, emits `tracing::error!`, DELETE FROM `satan_audit_replies` WHERE inbox_id = $.

Rejects-only-reply chosen because §17.4 only requires the daemon to log on reject; success acknowledgements would add noise without observability value.

### 17.5 Disable-switch placement — daemon-side check

The broker forwards the current `attribute-updates-enabled` state in every source-event payload it puts on the queue (§17.3). The daemon checks the flag at dispatch time:

- If enabled: write event row with `disabled=false`, UPSERT projection, RPC event back to broker for transcript.
- If disabled: write event row with `disabled=true`, **skip** UPSERT, RPC event back to broker for transcript.

Daemon-side check is required so the event log preserves the "would have applied X but was disabled" delta — `satan-attrd rebuild --include-disabled` (§10.2) replays those rows to reconstruct the hypothetical projection. A broker-side filter (drop the source event before sending) would lose this information.

### 17.6 Forward references

Future broker-side affordances are referenced elsewhere in this contract without prejudice to the locus split:

- `my/satan-attribute-zero` (§8) — broker-side interactive command to manually re-zero an attribute. Out of T-attr-1 scope.
- `my/satan-mark-intervention-*` + `notes_at_satan_intervention_done` (§14) — broker-side manual-override pattern for the reserved `:source :manual` enum value. Out of T-attr-1 scope.

These are broker UX, not daemon implementation; their inclusion does not pull additional logic into the daemon.

### 17.7 Per-run Counter eviction

The daemon maintains a `HashMap<run_id, Counter>` so each run's `seq` allocation is independent (matches the event-id shape `<run-id>.attr<NNN>` per §4.2). Without eviction, the map grows unboundedly across a long-running daemon's lifetime.

V1 eviction: **bounded LRU**, capacity 64. When a new run-id arrives and the map is at capacity, evict the least-recently-touched entry. 64 is generous — a real broker session emits ~one outcome per intervention, with run boundaries on every broker restart; 64 concurrent active runs is well past any observed workload.

Alternative considered + deferred: explicit `intervention.run_ended` broker signal. Cleaner (no LRU heuristic) but requires a new broker-emitted audit event + matching consumer in the daemon. Defer until the LRU heuristic shows wrong (e.g. an evicted run resurfaces with a stale Counter). Eviction is observable: the daemon logs `tracing::info!` on every evict so operators can see when the cap is being hit.

Eviction does NOT touch the event log — only the in-memory Counter. If an evicted run-id resurfaces, the daemon allocates a fresh Counter starting at 1. The `UNIQUE (run_id, seq)` constraint protects against duplicate-seq writes in that case (insert fails on collision; the daemon surfaces the error). In practice, resurfacing only happens if the broker re-emits stale outcomes from a long-gone run, which is itself a bug.
