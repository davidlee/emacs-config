---
id: ADR-002
title: 'ADR-002: SATAN arrival via metabolic stochastic gating'
status: proposed
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
deltas: []
revisions: []
audits: []
related_decisions: [ADR-001]
related_policies: []
tags: [satan, arrival, attributes, governance, proposed]
summary: 'PROPOSED: shift SATAN consumer arrival from fixed schedule to attribute-gated stochastic — attributes bias arrival probability and mode; rolls are seeded and logged; depends on ADR-001.'
---

# ADR-002: SATAN arrival via metabolic stochastic gating

> **Status: proposed.** This ADR frames a doctrine shift for decision; it is not
> yet accepted. It depends on [[ADR-001]] and must clear the open questions
> (§Open questions) — chiefly a written self-manipulation analysis — before
> acceptance.

## Context

[[ADR-001]] decouples perception from cognition: the LLM **consumer** now
arrives on its own trigger, separate from the deterministic perception view.
That makes *consumer arrival* a free variable for the first time — previously it
was welded to the fixed `satan-tick` timer.

`governance.md`'s core thesis lists **invocation schedule** in SATAN's durable
DNA, and `architecture.md` states arrival is *"explicit, scheduled, inspectable,
boring. SATAN does not decide for itself when to wake up except through
mechanisms the user has explicitly installed."* Today that means fixed systemd
timers (`satan-tick OnUnitActiveSec=30min`, `morning`, `motd`).

The attribute layer (`docs/satan/attributes/design-contract.md`) already exists
as **metabolic control variables that bias behaviour** — but only *within* a
run (read from the prompt capsule). It is deterministic, append-only,
event-sourced, capped, and decays daily toward homeostasis. The proposal: let
that same metabolism also decide *arrival*.

## Decision

**PROPOSED — gate consumer arrival on attribute state, stochastically.**

- Arrival is **biased-random**, not fixed-schedule: high Curiosity → likely
  info-gathering run; high Metamorphosis → likely introspection/self-edit;
  Brooding → ruminate. The gate reads attributes, rolls a biased die, maybe
  fires; a completed run of a kind **satiates** its matching attribute
  (integrate-and-fire / leaky bucket → bursty, natural rhythm).
- **Reuses existing machinery**, does not reinvent: satiation already exists
  (source-event tables decrement the matching attribute on the matching action);
  the homeostatic floor already exists (T-attr-2 daily decay); continuous
  integration already exists (sensors charge attributes every tick). The gate is
  read + roll + (on-fire) satiate.
- **Two timescales, shared vocabulary.** Slow *global* attributes drive
  *discretionary* arrival (metabolism). Intervention urgency is a fast,
  cue-bound spike → a **fast episode-scoped transient** attribute drives the
  intervention reflex. The contract already reserves `scope = episode | motive`
  but v1 only writes `global`; this is what motivates implementing it.
- **Placement:** daemon-owned (`satan-attrd`, consistent with decay) — reads
  attrs, rolls, signals the broker to spawn via the existing pg_notify/inbox
  path. May retire the systemd heavy-run timer; the waybar widget becomes manual
  arrival injection.

Capture: [[IMPR-012]]. Builds on [[ADR-001]] / [[DE-010]].

## Consequences

### Positive

- Arrival texture matches the organism metaphor (`patterns_attributes`:
  "global attributes are the animal's metabolism"). Self-paced, non-mechanical.
- Almost entirely reuses the event-log / caps / replay / decay substrate.
- Subsumes the fixed-timer zoo into one principled mechanism.

### Negative — these are why this is `proposed`, not `accepted`

- **Contradicts the current DNA.** Shifts arrival deterministic-schedule →
  self-paced-stochastic. `governance.md` + `architecture.md` say arrival is
  "explicit, scheduled, boring." Accepting this ADR **requires amending** that
  doctrine, not quietly overriding it.
- **Self-manipulation surface.** The model already nudges its own attributes via
  tool calls (design-contract §6H.7). Once attributes gate *arrival*, indirect
  self-summoning becomes possible. **A written self-manipulation analysis is a
  precondition of acceptance.**
- **Replay-determinism risk.** The attribute layer's foundation is byte-exact
  replay (`Math.random`/`Date.now` are banned there). An unlogged dice roll
  breaks it.

### Neutral

- A new dispatcher **source** (`source=arrival`/`gate`) with its own reason enum
  + delta table + caps; slots into the contract's reserved-source pattern.

## Guards (mandatory if accepted)

1. **Daily token ceiling is the hard cap** (`dl-satan-budget`) — a saturated
   metabolism cannot summon unbounded runs.
2. **Fire-probability modulated by remaining budget** — hungry + broke →
   suppressed.
3. **Rolls are seeded + logged** as an `arrival.rolled` event (threshold, roll,
   fired?) so arrival is as auditable as every attribute delta.
4. **Probability, not trigger** — attributes bias odds; they never force a run.

## Open questions (block acceptance)

- Written self-manipulation analysis (containment argument).
- DE-010 **D2** (pure replayer vs hybrid) — settles whether the gate is the only
  clock or coexists with a thin reflex touch.
- Doctrine amendment text for `governance.md` core thesis + `architecture.md`
  Invocation layer.

## Verification

- `arrival.rolled` events present + replay-deterministic (seeded).
- Arrival count over a window respects the budget ceiling under saturation.
- Self-manipulation: model-driven attribute nudges cannot raise arrival rate
  past the budget cap (adversarial test).

## References

- [[IMPR-012]] — capture + ranked design notes.
- [[ADR-001]] / [[DE-010]] — the decoupling this builds on.
- `docs/satan/attributes/design-contract.md` — attribute layer (sources, caps,
  decay, §3.1 ambient/global, §6H.7 self-manipulation).
- `docs/satan/governance.md` core thesis — "invocation schedule" as DNA.
- `docs/satan/architecture.md` — Invocation layer ("explicit, scheduled,
  boring").