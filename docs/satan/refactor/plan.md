---
name: satan-refactor-plan
description: Living index of pre-attributes refactor themes (companion to CODE_REVIEW.md)
metadata:
  type: plan
  topic: satan-refactor
  status: living
  updated_at: 2026-05-23
---

# SATAN refactor — themes index

Companion to [`../../CODE_REVIEW.md`](../../CODE_REVIEW.md) (review artifact, frozen point-in-time).
Per-theme briefs live in this directory.

## Sequence

Recommended landing order (from CODE_REVIEW.md §6 Q1):

```
T4 / T8 / T6   (quick wins + test split; parallel to all)
→ T1            observer file-split
→ T1.5a         outcome-semantics design contract (doc only)
→ T2            pre-spawn extraction
→ T7            intervention records (BLOCKER for attributes)
→ [attributes core tranche]    (out of scope here)
→ T1.5b         negative classifier implementation
→ T3 Path A     capsule registry (only if rendering pain real)
```

## Status table

| Theme | Title | Status | Blocked by | Next PR |
|---|---|---|---|---|
| [T1](T1-observer-split.md)         | Observer file-split                 | merged      | —              | done — classifier extracted to `dl-satan-observer-classify.el` |
| [T1.5](T1.5-outcome-semantics.md)  | Outcome-semantics + neg classifier  | in-progress | T1, T7 (1.5b)  | 1.5a doc landing; 1.5b blocked on T7 |
| [T2](T2-pre-spawn.md)              | Pre-spawn pipeline extraction       | not-started | —              | `dl-satan-pre-spawn.el` + cutover |
| [T3](T3-capsule-registry.md)       | Capsule render registry             | not-started | —              | (Path A gated; awaits rendering pain) |
| [T4](T4-modes-field.md)            | Drop tool-spec `:modes` field       | merged      | —              | done — `:modes' stripped from all tool specs; `dl-satan-mode-check-tool-references' enforces |
| [T6](T6-test-monolith.md)          | Test monolith split                 | merged      | —              | done — monolith deleted, per-module files |
| [T7](T7-intervention-records.md)   | Intervention records                | not-started | T1.5a contract | audit event types + validator + fixtures |
| [T8](T8-pi-adapter-keys.md)        | pi-adapter API-key externalisation  | not-started | —              | TBD (JSON vs README; user-decidable) |

Status enum: `not-started | in-progress | merged | abandoned`.

## Cross-cutting

- **A3 determinism.** T7 + T1.5b intentionally break byte-identical-rerun (new IDs, new classifier outputs). All other themes preserve it. See CODE_REVIEW.md §6 Q7.
- **CHANGELOG.md.** One line per merged PR per project convention. Refactor PR template:
  `refactor(satan): T<N> — <subtitle>`
- **Rollback switches.** T7 + attributes tranche introduce `dl-satan-intervention-recording-enabled` + `dl-satan-attribute-updates-enabled` defcustoms (CODE_REVIEW.md §6 Q9). Wire in T7 PR sequence.

## Open questions (parked from review)

Mirrors CODE_REVIEW.md §6 — decisions only the user can make. Update inline as resolved:

1. **Sequence approval.** *Pending user.*
2. **`:harmful` automation policy.** *Pending user* (recommendation: manual-only v1).
3. **`transcript.jsonl` retention post-T7.** *Pending user.*
4. **T2 + T3 abort conditions.** *Pending user.*
5. **T8 path (JSON spec vs README).** *Pending user* (recommendation: JSON).
6. **Backfill policy for pre-T7 interventions.** *Pending user* (recommendation: option (a) clean break — no synthetic data).
7. **Determinism test boundary acknowledgement.** *Noted; T7 PR 1 must update tests.*
8. **Model visibility of `intervention_id`.** *Pending user* (recommendation: id-only v1; outcome-state on explicit `intervention_status` tool call).
9. **Rollback / disable switches.** *Pending user* (recommendation: ship both defcustoms in T7).
10. **Track refactor plan separately.** *Resolved: yes, this file.*

## Working procedure

When starting a theme:
1. Flip `metadata.status: not-started → in-progress` in the theme file.
2. Flip the Status column in this table.
3. Append a `## PR log` entry in the theme file.
4. Work the theme's `First concrete step` as first PR.
5. On merge: tick the PR log entry, update CHANGELOG.md.
6. When all theme PRs merged: flip `metadata.status: in-progress → merged` here and in the theme file.

When a decision in `## Open questions` resolves: edit the answer inline, commit alongside the next theme PR (not a standalone doc commit).

When a theme reveals a new decision: append to the theme file's `Open questions` section, mirror to this file's open questions if cross-cutting.

## Anti-recommendations (from review §5)

Patterns the scout flagged or that were considered, but should be left alone. Not tracked as themes:

1. Patch-agent 8-file split — load-bearing; do not merge.
2. `dl-satan-memory-writer.el` facade — 5 callers across 3 files; below facade threshold.
3. Consolidate `defcustom` surface — no real problem; scattered shape correct.
4. Make tool-spec `:modes` authoritative — inverts mode-centred ethos.
5. `satan/perceptual/` subdirectory — flat namespace matches rest of `satan/`.
6. Extend `actions.json` with intervention fields — no cross-run query; no rebuild story.
7. Split `tank.el` — well-contained; no growth pressure.
8. Automate `:harmful` v1 — needs causal reasoning not in codebase.
9. Let attributes self-amplify from weak evidence — bake in decay + confidence-tied caps + review thresholds.
