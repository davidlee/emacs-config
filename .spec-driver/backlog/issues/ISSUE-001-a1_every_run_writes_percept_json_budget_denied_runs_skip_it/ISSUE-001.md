---
id: ISSUE-001
slug: a1_every_run_writes_percept_json_budget_denied_runs_skip_it
name: "A1: every run writes percept.json (budget-denied runs skip it)"
created: "2026-05-30"
updated: "2026-06-10"
status: resolved  # one of: in-progress | open | resolved | triaged
kind: issue  # one of: audit | delta | design_revision | issue | memory | phase | plan | policy | problem | prod | requirement | risk | spec | standard | task | verification
categories: [satan, audit]
severity: p3  # one of: p1 | p2 | p3 | p4
impact: systemic  # one of: user | systemic | process
---

# A1: every run writes percept.json (budget-denied runs skip it)

A1 strict reading: **every run writes `percept.json`.** Phase 1 still skips
the write on budget-denied runs; Phase 4 also skips `pre_spawn` on
budget-denied. Either A1 should be tightened (always write) or the design
should explicitly carve out the budget-denied case.

Migrated from `docs/satan/follow-ups.md` §Consistency (2026-05-30).

**Resolved by [[DE-010]] Phase 1 (2026-06-10, commit 3c8e333).** A1 tightened to
"always write": `perceive` (percept-build + persist) was lifted before the
session/budget gates in `dl-satan-broker-run`, so budget-denied AND
session-blocked ticks now write `percept.json` and mirror `:percept` into
`bundle.json`. Verified by VT-budget-denied-perceives (IP-010 coverage,
`verified`). See [[mem.fact.satan.perceive-consume-seam]].
