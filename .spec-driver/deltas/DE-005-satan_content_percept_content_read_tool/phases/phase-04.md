---
id: IP-005-P04
slug: "005-satan_content_percept_content_read_tool-phase-04"
name: IP-005 Phase 04
created: "2026-06-03"
updated: "2026-06-03"
status: in-progress  # one of: completed | deferred | draft | in-progress | pending
kind: phase  # one of: audit | delta | design_revision | issue | memory | phase | plan | policy | problem | prod | requirement | risk | spec | standard | task | verification
plan: IP-005
delta: DE-005
---

# Phase 04 — Integration & close-prep

## 1. Objective

Land P01–P03 as a coherent whole in the live config: new requires load in the
running server, the full ert suite is green, CHANGELOG reflects DE-005, and the
delta is ready for `/audit-change`. No new feature code — integration only.

## 2. Links & References

- **Delta**: DE-005 (§6 Acceptance Criteria)
- **Design Revision Sections**: DR-005 (DEC-1..6); no new design.
- **Specs / PRODs**: none (delta-tracked surface).
- **Support Docs**: `docs/satan/perceptual-design.md` §S2; POL-001.

## 3. Entrance Criteria

- [x] P01–P03 complete (tool, sensor, percept rule — all ert-green in-session)
- [x] New `.el` files git-tracked (flake visibility — trap #1): `satan/dl-satan-tools-content.el`, `satan/dl-satan-sensor-content.el` + tests committed (P01–P03 feat commits)

## 4. Exit Criteria / Done When

- [x] Full `just check` green (0 unexpected; pre-existing DB-gated skips only)
- [x] `~/notes/satan/tools/content_read.md` present (R7 hard-error guard satisfied)
- [x] CHANGELOG updated for DE-005 (per-phase entries: P01 tool, P02 sensor, P03 percept rule)
- [ ] **VH**: `home-manager switch` on Sleipnir — new `(require)` forms load, server starts clean, `content_read` dispatches end-to-end (user-run; sandbox cannot reproduce live host)
- [ ] Ready for `/audit-change`

## 5. Verification

- **VA-integration (suite)**: `just check` — 961/970 passed, 0 unexpected, 9 skipped (DB-gated: bough/integration/memory-grammar-db-sync/patch-*). Run `2026-06-03 11:29` after DE-009 landed. DE-005 content tests (`dl-satan-content/*`, sensor, rule) all green.
- **VH-switch**: user runs `home-manager switch`; confirm new requires load + `content_read` reachable through the broker. Evidence: server start clean, one live `content_read` dispatch.

## 6. Assumptions & STOP Conditions

- Assumptions: producer (panopticon) untouched; `~/notes` path resolves to the live host's home (sandbox uses `/workspace/notes` — path differs, not a real-host defect).
- STOP when: `home-manager switch` errors on the new requires, or a live `content_read` dispatch fails the R7 description-file guard — `/consult` before claiming P04 done.

## 7. Tasks & Progress

_(Status: `[ ]` todo, `[WIP]`, `[x]` done, `[blocked]`)_

| Status | ID  | Description | Parallel? | Notes |
| ------ | --- | ----------- | --------- | ----- |
| [x] | 4.1 | git add + commit new tracked `.el` (tool/sensor + tests) | [ ] | done in P01–P03 feat commits |
| [x] | 4.2 | Full `just check` green | [ ] | 961/970, 0 unexpected (2026-06-03) |
| [x] | 4.3 | CHANGELOG DE-005 entries | [ ] | per-phase P01/P02/P03 entries present |
| [ ] | 4.4 | **VH** `home-manager switch` on Sleipnir + live `content_read` dispatch | [ ] | user-run; gates close |

### Task Details

- **4.2 suite** — initial P04 run was red (15 failures) due to uncommitted DE-009
  `:percept_handles` WIP in the shared tree, not DE-005. After DE-009 completed
  (`335e210`), re-run is clean: 0 unexpected. DE-005 content/sensor/rule tests
  all pass.
- **4.4 switch** — only sandbox-irreproducible gate. Live host load is the last
  evidence before audit.

## 8. Risks & Mitigations

| Risk | Mitigation | Status |
| ---- | ---------- | ------ |
| R7 missing `content_read.md` crashes first dispatch | File shipped + present; live dispatch in 4.4 exercises the guard | open until 4.4 |
| Suite contaminated by sibling-delta WIP | Resolved — DE-009 landed green before re-measure | closed |

## 9. Decisions & Outcomes

- `2026-06-03` — P04 full-suite gate was blocked by unrelated DE-009 WIP; chose to
  pause rather than entangle deltas (user decision). DE-009 then completed; suite
  green on re-measure. `home-manager switch` assigned to user as VH (live host).

## 10. Findings / Research Notes

- `just check` IS runnable in this environment now (P01–P03 notes recorded it as
  unavailable — env has since changed). 961/970, 0 unexpected.
- New `.el` already git-tracked before P04 — `git add` portion of P04 was
  effectively folded into the P01–P03 feat commits.

## 11. Wrap-up Checklist

- [x] Exit criteria satisfied (except VH switch 4.4)
- [x] Verification evidence stored (suite run in §5)
- [ ] Spec/Delta/Plan updated with lessons (IP progress flipped on 4.4 close)
- [ ] Hand-off: after VH switch, run `/audit-change` (AUD for DE-005)
