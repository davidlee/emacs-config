---
name: hippocampus-attribute-signals
description: Design sketch — hippocampus tool calls emitting attribute deltas
metadata:
  type: design
  topic: satan-attributes
  status: draft
  updated_at: 2026-05-24
---

# Hippocampus tool calls → attribute signals

> **Status.** Draft sketch for handover. Not yet contracted.

## Motivation

Hippocampus tool calls carry semantic signal about SATAN's internal
state: writing a memory means acted-on-pressure; deleting a wrong
memory means acknowledged-error; grepping without result means
searching-for-missing-knowledge. These signals should influence
attributes — particularly Brooding (which motivates rumination)
and Shame (which motivates correction).

Currently the only implemented attribute source is `outcome`
(intervention verdicts). The contract reserves five others
(`percept`, `resonance`, `sensor`, `tool_error`, `manual`) but
none are implemented. Hippocampus signals don't fit `tool_error`
(which implies failure); they need either a new source or a
renamed/widened existing reservation.

## Proposed source: `hippocampus`

**Why not `tool_action` or `tool_outcome`?** Keeping the source
name specific avoids a premature generalisation. Other tool
actions (org_update_owned_block, motive_replace) have different
semantics. If a general tool-action source is needed later,
hippocampus can be folded in; starting narrow is cheaper to
reason about and test.

### Reason enum

| reason | trigger |
|---|---|
| `written` | hippocampus_write succeeds |
| `overwritten` | hippocampus_overwrite succeeds |
| `deleted` | hippocampus_delete succeeds |
| `renamed` | hippocampus_rename succeeds |
| `searched` | hippocampus_grep returns 0 matches |

Read-only tools (hippocampus_list, hippocampus_read, grep with
matches) do not emit — reading is not a metabolic event.

### Delta table (draft)

Magnitudes: tiny = 0.025, small = 0.05. Consistent with the
`worked shame` exception (−0.025) precedent in §6 footnote 1.

```
              friction  shame   doubt  hunger  suspicion  brooding  metamorphosis
written         0        0       0      0       0         −0.025     0
overwritten     0       −0.025   0      0       0         −0.025     0
deleted         0       −0.025   0      0       0         −0.025     0
renamed         0        0       0      0       0         −0.025     0
searched        0        0       0      0      +0.025      0         0
```

Design notes:
- **Brooding drops on write/overwrite/delete/rename** — the
  pressure that motivated rumination was acted on.
- **Shame drops on overwrite/delete** — correcting or removing
  wrong knowledge is acknowledging error (same magnitude as
  `worked` shame at −0.025).
- **Suspicion rises on empty grep** — searched for knowledge,
  found a gap. Small signal that there's something worth
  investigating.
- **No confidence weighting.** Hippocampus actions are binary
  (succeeded or not); the §6.1 confidence multiplier doesn't
  apply. All deltas at base magnitude.
- **No friction/hunger/doubt/metamorphosis movement.** These
  tools are inward-facing; they don't affect intervention
  policy, demand for contact, or self-edit pressure.
- **Magnitudes are deliberately sub-small.** A single
  hippocampus_write should not meaningfully move Brooding;
  a ruminate run with 5-10 writes produces a cumulative
  effect of −0.125 to −0.25, which is noticeable but not
  dominant.

### Self-manipulation concern

SATAN can choose to call hippocampus tools, so it can
indirectly influence its own attributes. Mitigations:

1. **Magnitudes are tiny** (0.025 per call). At
   budget-tool-calls=30 (ruminate), maximum possible Brooding
   reduction per run = 0.75 if every call is a write — but
   that would consume the entire tool budget on writes with
   no gathering, producing empty/useless entries.
2. **Cross-ref trace** — every hippocampus_write already emits
   an observation trace (§10.7). Attribute deltas would add
   audit visibility via `attribute.delta_applied` in the
   transcript. Gaming is detectable.
3. **Content validation is out of scope for v1.** The
   dispatcher trusts that a successful write is a real write.
   A future "quality gate" (checking entry length, novelty,
   or duplication before emitting) is possible but premature.
4. **Existing precedent.** SATAN already influences attributes
   indirectly through intervention choices — choosing to
   intervene vs. not, choosing intervention kind, etc. Tool
   calls are a weaker influence channel.

## Implementation path

### 1. Contract amendment (docs/satan/attributes/design-contract.md)

- Add `"hippocampus"` to §5 reserved source list.
- Add `"hippocampus"` to implemented sources.
- Define §6-style reason enum (table above).
- Define delta table (table above).
- Note: no confidence weighting for this source.
- Note: no revision semantics (hippocampus actions are
  not revisable in the intervention sense).

### 2. Broker — validator widening (satan/dl-satan-audit.el)

- Add `"hippocampus"` to `dl-satan-audit-attribute-sources-reserved`.
- Add `"hippocampus"` to `dl-satan-audit-attribute-sources-implemented`.
- Define `dl-satan-audit-attribute-hippocampus-reasons`
  constant: `("written" "overwritten" "deleted" "renamed" "searched")`.
- Add cond branch in `dl-satan-audit--attribute-reasons-for-source`.
- Validator evidence shape for `source=hippocampus`:
  `evidence.tool_name` (string), `evidence.filename` (string),
  no `intervention_id`, no `confidence`, no `classification`.

### 3. Broker — enqueue from tool handlers (satan/dl-satan-tools-hippocampus.el)

- After each mutating tool succeeds (and hippocampus_grep
  with 0 matches), build payload and call
  `dl-satan-attribute-enqueue-outcome`.
- Pattern: mirror `dl-satan-tools-hippocampus--cross-ref`
  — soft-fail, log on error, do not affect tool return value.
- Payload shape: `source="hippocampus"`, `reason=<per tool>`,
  `evidence={tool_name, filename}`, `confidence` absent,
  `is_revision=false`.
- Gate on `dl-satan-attribute-updates-enabled` (§9 disable
  switch) — skip enqueue when disabled.

### 4. Daemon — dispatcher (~/dev/satan-attrd/src/dispatcher.rs)

- Add `hippocampus_deltas(reason: HippocampusReason) -> [f64; 7]`
  parallel to `base_deltas`.
- No confidence weighting pass (base deltas are final).
- Caps (friction_cap, range_clamp) still apply per §7.
- Add `dispatch_hippocampus` parallel to `dispatch_outcome`.
- Run loop routes by source field in payload.

### 5. Tests

Broker (ert):
- Validator accepts all 5 hippocampus reasons.
- Validator rejects unknown hippocampus reason.
- Validator requires evidence.tool_name.
- Enqueue from each tool handler (mock enqueue, verify payload).

Daemon (Rust):
- Golden delta table: 5 reasons × 7 attributes = 35 cells.
- No confidence weighting (base = final).
- Caps apply (range_clamp at 0/1 boundaries).

## Open questions

1. **Should `hippocampus_grep` with matches also emit?**
   Current proposal: no. Finding what you expected is not
   metabolically interesting. Counter-argument: finding a
   contradicting entry is interesting, but the grep tool
   doesn't know whether the match contradicts — that
   requires reading and interpreting.

2. **Should the source be `hippocampus` or more general
   (`tool_action`)?** Starting narrow is safer; can fold
   into a general source later if other tools want signals.
   But if motive_replace, org_update_owned_block, etc. will
   want signals too, a general source avoids N source
   registrations.

3. **Should overwrite/delete require reading the entry
   first to emit?** Currently: no, emit on any successful
   call. Possible concern: deleting an entry you wrote 30
   seconds ago in the same run shouldn't reduce Shame
   (it's not correcting an error, it's undoing a mistake
   within the same session). Mitigation: magnitudes are tiny
   enough that this doesn't matter in practice.

4. **Revision semantics.** Intervention outcomes can be
   revised (§6.2) — a `contradicted` can later be re-classified
   to `worked`. Hippocampus actions are final (you either
   wrote or you didn't). No revision path needed, but the
   daemon dispatcher assumes revision capability per source.
   Simplest: `is_revision=false` always, dispatcher skips
   revision logic for hippocampus source.

## Relationship to ruminate mode

Ruminate is the primary consumer but not the only one.
Morning/motd/self-edit modes also have hippocampus tools
and would emit the same signals. The delta table is designed
for any-mode use: a morning-mode hippocampus_write emitting
Brooding −0.025 is correct regardless of whether Brooding
was high when the write happened.

Ruminate runs are expected to produce more hippocampus calls
(5-15 per run vs 0-2 for other modes), so cumulative
attribute effects are larger. This is intentional: a
productive rumination run should meaningfully reduce the
Brooding pressure that triggered it.
