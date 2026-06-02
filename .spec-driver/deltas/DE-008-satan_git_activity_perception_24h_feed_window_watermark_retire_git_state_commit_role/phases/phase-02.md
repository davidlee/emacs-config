---
id: IP-008-P02
slug: "008-satan_git_activity_perception_24h_feed_window_watermark_retire_git_state_commit_role-phase-02"
name: IP-008 Phase 02
created: "2026-06-02"
updated: "2026-06-02"
status: draft
kind: phase
plan: IP-008
delta: DE-008
---

# Phase 02 — Outcome predicate + git_state demotion

## 1. Objective

Replace `:git_head_changed` (P2) with `:git_commit_observed` (repo-scoped, window-anchored); demote `git_state` commit role in the tank; update docs and CHANGELOG; verify no orphaned references to the old predicate.

## 2. Links & References

- **Delta**: DE-008
- **Design Revision Sections**: DR-008 §4.3 (predicate), §4.4 (git_state demotion + tank), §5a (removal-surface checklist)
- **Phase 01**: Feed now populates sorted `:git_commits` over 24h.

## 3. Entrance Criteria

- [x] Phase 01 complete (commit `a3dc8c1`)
- [x] `:git_commits` populated with sorted, properly-filtered rows in the 24h window

## 4. Exit Criteria / Done When

- [x] `:git_head_changed` / `--predicate-git-head-changed` fully removed from `dl-satan-observer-classify.el`
- [x] `:git_commit_observed` predicate registered in the same slot; fires once for in-scope commit, holds for out-of-scope / no-project_cwd
- [x] Tank git line renders `:git_commits` summary (count + newest); `:git_state` head/dirty not surfaced
- [x] `docs/satan/attributes/outcome-semantics.md` updated
- [x] `CHANGELOG.md` updated
- [x] `docs/satan/perceptual-design.md` updated
- [x] `rg ':git_head_changed|git-head-changed'` returns empty (outside historical CHANGELOG context and DR-008/artefacts)
- [x] VT-commit-observed + VT-p2-retired green
- [x] `just check` green
- [x] VA-live-tick: throwaway commit + forced tick → appears in `percept.json` git_commits

## 5. Tasks & Progress

| Status | ID  | Description | Notes |
| ------ | --- | ----------- | ----- |
| [x] | 2.1 | Add `--git-row-matches-motive` + `--git-row-in-window` helpers | pure functions; discovered file-equal-p trap (non-existent paths) |
| [x] | 2.2 | Add `--predicate-git-commit-observed`; replace in registry; remove P2 | DR-008 §4.3; string-equal on expanded paths |
| [x] | 2.3 | Update tank git line: render `:git_commits` count + newest, drop `:head_short`/`:dirty` | DR-008 §4.4 |
| [x] | 2.4 | Update `docs/satan/attributes/outcome-semantics.md` | replace predicate vocabulary |
| [x] | 2.5 | Update `CHANGELOG.md` | DE-008 entry |
| [x] | 2.6 | Update `docs/satan/perceptual-design.md` | git feed 24h + :git_commit_observed |
| [x] | 2.7 | Tests: VT-commit-observed + VT-p2-retired in `dl-satan-observer-test.el` | 6 new P2 tests + 4 integration fixture updates |
| [x] | 2.8 | Final removal-surface audit: `rg ':git_head_changed\|git-head-changed'` | empty outside CHANGELOG history + artefacts |
| [x] | 2.9 | VA-live-tick: throwaway commit + forced tick | 7 commits, sensor_status.git=ok, git_window_start_at distinct |

## 6. Verification

- ERT: `satan/test/dl-satan-observer-test.el` — rewrite P2 cases for `:git_commit_observed`; assert registry order.
- Live VA: throwaway commit in a tracked repo, force a tick, inspect `~/notes/satan/runs/*/percept.json` for git_commits.

## 7. Risks

| Risk | Mitigation |
| ---- | ---------- |
| Orphaned references to `:git_head_changed` | Final `rg` gate (2.8) |
| Predicate fires on unrelated repo | Repo-scope + window-anchor in predicate; ERT covers |
| Sensor-alerts regression | `:git` sensor_status still reads the git probe — no code change needed (confirmed DR-008) |
