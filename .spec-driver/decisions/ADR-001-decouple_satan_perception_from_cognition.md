---
id: ADR-001
title: 'ADR-001: Decouple SATAN perception from cognition'
status: accepted
created: '2026-06-08'
updated: '2026-06-08'
reviewed: '2026-06-08'
authors:
- name: David Lee
owners: []
supersedes: []
superseded_by: []
policies: []
specs: []
requirements: []
deltas: [DE-010]
revisions: []
audits: []
related_decisions: [ADR-002]
related_policies: []
tags: [satan, perception, architecture]
summary: 'SATAN perception is a budget-independent deterministic view over the durable segment log, separate from the effecting LLM run; the parcel is materialized lazily on consume.'
---

# ADR-001: Decouple SATAN perception from cognition

## Context

A SATAN "tick" today fuses two things into one lifecycle: **deterministic
context preparation** and a **token-spending LLM run with side effects**.
`dl-satan-broker--prepare` already builds the percept deterministically (frozen
`time_now`, evidence window, canon, resonance, motive) — then spawns the model
as its last step (`docs/satan/perceptual-design.md` §S1).

This fusion causes two concrete problems:

1. **Perception is gated by LLM budget.** `ISSUE-001`: every run writes
   `percept.json`, but budget-denied runs skip it. Sensing should not depend on
   whether the system can afford to think.
2. **Invocation control is coarse.** The systemd `satan-tick` timer
   (`OnUnitActiveSec=30min`) is disabled in favour of a waybar widget timer,
   *because* a tick = prep **+** effects + tokens. The user cannot cheaply
   sample "what is happening now" without also paying for and risking a full
   effecting run.

Invocation/perception is load-bearing: `governance.md` core thesis lists
"invocation schedule" in SATAN's durable DNA. So the seam is worth deciding
explicitly, not drifting.

## Decision

**Split perception from cognition.**

- **Perception** is a **pure, deterministic function** of `segments[cursor..head]`
  over the already-durable panopticon segment log — extracted from
  `broker--prepare`. Zero side effects, zero tokens, never gated by budget.
  There is **exactly one** percept builder (an extraction, not a parallel
  implementation).
- **Cognition** is the LLM run — now a separate **consumer** that drains the
  segment backlog at its own (slacker) cadence and carries all effects + budget.
- **D1 — lazy materialization (resolved 2026-06-08).** The parcel is a *view*,
  not a per-tick artifact: materialized lazily on consume, append-only and
  immutable once written. Rejected the alternative (materialize `packet-<n>.json`
  every tick): write amplification + ~144 mostly-empty parcels/day for an
  artifact the durable segment log already backs.

Consumption is tracked by a **separate cursor**, never by mutating the parcel.
Parcel boundaries key on **segment offset, not wall-clock**, so late/overlapping
invocations re-derive the same boundary (idempotent).

Implementation: [[DE-010]].

## Consequences

### Positive

- **Fixes `ISSUE-001` at the root** — perception writes regardless of budget.
- **Completeness** — "segments since cursor" replaces the irregular keyhole; no
  gaps/overlaps.
- **The waybar widget is promoted, not lost** — from "summon the whole beast" to
  "summon the consumer now," beside any future auto trigger. More control, not
  less.
- Honours the existing architecture layering (perception = deterministic broker
  work; cognition = untrusted model). This ADR formalises doctrine, it does not
  contradict it.

### Negative

- **No per-tick perception-of-record.** Lazy materialization drops the "what did
  SATAN see at 10:00" artifact. Mitigated: memory/outcome accrual reads the
  durable segment log via the ingest cursor, so nothing is lost there; an
  optional slow archival materialization can be added if an explicit
  perception-of-record is ever wanted (DE-010 §7 D1a, deferred).

### Neutral

- Two retention semantics must be modelled, not one queue: **intervention
  relevance** (newest-first + freshness horizon) vs **memory/outcome accrual**
  (all segments, order-independent). One ingest cursor + a per-parcel
  "intervention-eligible-until" stamp.
- The *trigger* for the consumer (what wakes it, how often) is deliberately
  **out of scope here** — see [[ADR-002]].

## Verification

- `ISSUE-001` regression: a budget-denied tick still produces perception.
- Idempotency: a doubled/late invocation yields no duplicate/corrupt parcel
  (segment-offset keying).
- Consumer drains backlog and advances the cursor without mutating parcels.

## References

- [[DE-010]] — implementing delta (shaping; D2 consumer-shape open).
- `ISSUE-001` — budget-denied runs skip `percept.json`.
- `docs/satan/perceptual-design.md` §S1 — `broker--prepare` sequence.
- `docs/satan/architecture.md` — Invocation / Broker / State layers.
- [[ADR-002]] — the arrival/trigger decision that builds on this split.