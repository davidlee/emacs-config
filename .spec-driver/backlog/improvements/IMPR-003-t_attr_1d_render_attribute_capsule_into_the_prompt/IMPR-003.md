---
id: IMPR-003
name: "T-attr-1d: render attribute capsule into the prompt"
created: "2026-05-30"
updated: "2026-05-30"
status: resolved
kind: improvement
categories: [satan, attributes]
tags: [done]
---

> **Resolved 2026-05-30.** Bar block delivered in commit `8612667` — render
> module (`dl-satan-attribute-render.el`), prompt wiring (`dl-satan-context.el`
> populates `:attributes` pre-spawn + emits the `# Attributes` block), tank
> surface (`dl-satan-tank.el`), 21 ERT tests, disable-aware. The model feels its
> own state in-prompt. The brief's derived **pressure** line was dropped as YAGNI
> (display-only gloss, re-states bars + duplicates §4 decision rules). Closure
> recorded in **DE-001** (deferred — no work required).


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

**Unblocked 2026-05-30.** Both gate conditions met in production `satan_memory`:
- `satan_intervention_outcomes`: 1 row (post timestamp-fix), so the pipeline
  writes. Caveat: it is `unknown`/low-confidence (`no_correlation`) — proves
  plumbing, not yet an outcome→attribute coupling.
- `global`-scope attribute drift is real and outcome-backed: doubt 0.6,
  shame 0.65, metamorphosis 0.49 (all from a `harmful` classification 2026-05-23),
  brooding 0.175 (hippocampus_write), curiosity 0.40 (panopticon_backlog sensor).
  295 events; updates enabled. Render would show meaningful, non-flat state.

Render the **`global`** scope only. `test:<uuid>` rows in `satan_attributes` are
test-isolation leakage, not real state — see ISSUE-003; filter them out.

Prior block was the outcome-classification timestamp bug (fixed 2026-05-29) that
left the table empty.

`refactor/plan.md` (`← next`) and `T-attr-1-attribute-layer.md §"Next actions"`
both point at this item.

Migrated from `docs/satan/follow-ups.md` §"Attribute layer observability" (2026-05-30).
