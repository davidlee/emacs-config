---
id: mem.fact.satan.perceive-consume-seam
slug: perceive-consume-seam
name: SATAN perceive/consume broker seam
kind: memory
status: active
memory_type: fact
created: '2026-06-10'
updated: '2026-06-10'
verified: '2026-06-10'
confidence: high
scope:
  paths:
    - satan/dl-satan-broker.el
    - satan/dl-satan-context.el
provenance:
  sources:
    - kind: code
      ref: satan/dl-satan-broker.el
    - kind: code
      ref: satan/dl-satan-context.el
    - kind: adr
      ref: ADR-001
    - kind: design_revision
      ref: DR-010
    - kind: doc
      ref: docs/satan/perceptual-design.md
tags:
- satan
- broker
- perception
summary: broker-run perceives UNCONDITIONALLY before session/budget gates (ISSUE-001
  root); consume carries effects+cursor+LLM. session-blocked=failed/session_blocked,
  NO .FAILED/announce. denial paths mirror :percept into bundle.json.
---

# SATAN perceive/consume broker seam

The SATAN tick (`dl-satan-broker-run`) is cut into **perceive** and **consume**
([[DE-010]], landed 2026-06-10; ratified by [[ADR-001]]).

## Control flow (as built)

```
broker-run: prepare (alloc run_id, freeze time_now) → mkdir run-dir
  → PERCEIVE (unconditional, pure)
  → if session-active  → no-child blocked bundle, return
  → if budget-exceeded → no-child denied bundle, return   ← ISSUE-001 fixed
  → else CONSUME (effects + tokens)
```

- **Perceive** (`dl-satan-run-perceive`) = percept-build + persist `percept.json`
  + probe **read-snapshot** (frozen onto `prepare :probe_snapshots`, internal,
  never serialized → bundle byte-stable). PURE: no LLM, no tool dispatch, no
  attribute enqueue, no consumption-state mutation. Runs **before both gates** —
  budget-denied no longer skips perception. Its ONLY write is `percept.json`.
- **Consume** (`dl-satan-broker--spawn`) = observer + probe-commit + resonance +
  motive + sensor-alerts + ingest-cursor advance + bundle + `make-process` (LLM).
- `assemble-context = enrich∘perceive`; `-probe = commit∘read`. Single percept
  builder (`dl-satan-percept-build`).

## No-child terminal paths (`--write-no-child-run STATUS REASON`)

Shared helper; three callers, all mirror `:percept` into `bundle.json` (consumers
read it THERE, not the sidecar):

| caller | status | reason | .FAILED? | announce? |
|---|---|---|---|---|
| budget-denied | `budget-exceeded` | — | yes | yes |
| **session-blocked** | `failed` | `session_blocked` | **NO** | **NO** |
| perceive-failed | `failed` | `perceive_failed` | yes | yes |

session-blocked is verify-clean (intentional DEC-8 deferral — must NOT pollute the
failure-streak counter or pop desktop alerts).

## Related

- [[mem.fact.satan.ingest-cursor-store]] — the consume-side frontier this advances.
- [[mem.pattern.satan.sensor-watermark-format]] — probe watermark = native ts.
- Signal model UNCHANGED (perception still reads present-tense live state; not yet
  replayable → IMPR-013).
