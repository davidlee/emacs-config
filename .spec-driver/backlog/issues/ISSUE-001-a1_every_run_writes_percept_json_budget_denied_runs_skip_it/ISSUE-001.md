---
id: ISSUE-001
name: "A1: every run writes percept.json (budget-denied runs skip it)"
created: "2026-05-30"
updated: "2026-05-30"
status: open  # one of: in-progress | open | resolved | triaged
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
