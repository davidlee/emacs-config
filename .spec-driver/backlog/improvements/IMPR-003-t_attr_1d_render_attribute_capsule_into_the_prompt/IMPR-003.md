---
id: IMPR-003
name: "T-attr-1d: render attribute capsule into the prompt"
created: "2026-05-30"
updated: "2026-05-30"
status: idea
kind: improvement
categories: [satan, attributes]
tags: [blocked]
---

# T-attr-1d: render attribute capsule into the prompt

The visible surface of the attribute layer. Substrate (1a–1c) + daemon decay
(T-attr-2) are done: 8 attributes in [0,1], event-sourced dispatcher, projected
in `satan_attrd`. Nothing renders them into the prompt yet — the model can't
feel its own state.

One PR: brief §4 ASCII bar block + a one-line derived "pressure" summary,
threaded into the existing capsule registry. Broker queries a daemon "snapshot
attrs" RPC pre-spawn and renders. Disable-aware: if attribute updates are off,
render `Attributes: disabled` — not the frozen projection (stale values are
indistinguishable from genuinely-low pressure).

**Blocked:** needs ≥1 real `satan_intervention_outcomes` row + visible attribute
drift off the fixture-pinned 0.50, so the render shows something meaningful.
The outcome-classification timestamp bug (fixed 2026-05-29) previously left the
table empty; watch for real outcome rows + drift over the following days.

`refactor/plan.md` (`← next`) and `T-attr-1-attribute-layer.md §"Next actions"`
both point at this item.

Migrated from `docs/satan/follow-ups.md` §"Attribute layer observability" (2026-05-30).
