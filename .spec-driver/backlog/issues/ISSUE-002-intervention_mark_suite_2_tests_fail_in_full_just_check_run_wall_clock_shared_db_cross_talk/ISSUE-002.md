---
id: ISSUE-002
name: "intervention-mark suite: 2 tests fail in full just check run (wall-clock + shared-DB cross-talk)"
created: "2026-05-30"
updated: "2026-05-30"
status: open  # one of: in-progress | open | resolved | triaged
kind: issue  # one of: audit | delta | design_revision | issue | memory | phase | plan | policy | problem | prod | requirement | risk | spec | standard | task | verification
categories: [satan, testing]
severity: p3  # one of: p1 | p2 | p3 | p4
impact: process  # one of: user | systemic | process
---

# intervention-mark suite: 2 tests fail in full just check run

Surfaced 2026-05-30 when `just check` started running the DB-backed suites
(previously hidden by a subsystem exclusion — see
`mem.fact.satan.test-db-isolation`). Both live in
`satan/test/dl-satan-intervention-mark-test.el`; both require the test DB
(`satan_memory_test`) reachable.

## `dispatch-routes-to-writer` — wall-clock time-dependence

The test fixes the intervention's `ts` to `2026-05-23T12:00:00+1000`, but the
mark/read path (`dl-satan-intervention-mark--read-iv-id` →
`dl-satan-intervention-mark--now-iso`) uses the **live wall clock**. Once real
time drifts past the recency/maturity window (run on 2026-05-30, 7 days later),
the iv is classified stale and excluded without a prefix arg →
`user-error "no interventions available"`. Passed when authored (035e159,
2026-05-23); now fails purely from clock drift.

Fix direction: inject the clock (bind/stub `--now-iso`, or thread a `now`
parameter) so the read path uses the test's fixed time.

## `recent-orders-newest-first` — full-run-only flake

Passes in isolation; fails only in the full `ert-run-tests-batch t` run →
cross-suite interference on the shared `satan_memory_test`. `--with-db`
reset-and-migrates per test, so this is likely migration-level or ordering
state left by another suite sharing the DB.

Fix direction: confirm cross-suite DB contract (same migration head for all
suites sharing the DB), or isolate/serialize DB suites.

## Repro

`just check` with `satan_memory_test` reachable →
`FAIL 2 unexpected / 862 total`.
