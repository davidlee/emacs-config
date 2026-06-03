---
id: IP-008-P01
slug: "008-satan_git_activity_perception_24h_feed_window_watermark_retire_git_state_commit_role-phase-01"
name: IP-008 Phase 01
created: "2026-06-02"
updated: "2026-06-02"
status: completed  # one of: completed | deferred | draft | in-progress | pending
kind: phase  # one of: audit | delta | design_revision | issue | memory | phase | plan | policy | problem | prod | requirement | risk | spec | standard | task | verification
plan: IP-008
delta: DE-008
---

# Phase 01 — Feed perception: git 24h window

## 1. Objective

Decouple the git-activity feed from the 10-minute attention window so SATAN perceives commits over a rolling 24h horizon, and harden the segment read path (multi-day enumeration, sort-before-limit, malformed tolerance, distinct window field). This phase alone fixes the reported symptom ("SATAN isn't seeing my commits") and is independently shippable. No observer/predicate or `git_state` changes here.

## 2. Links & References

- **Delta**: DE-008
- **Design Revision Sections**: DR-008 §4.1 (git window + `:git_window_start_at` + sort-before-limit), §4.2 (calendar feed-paths + malformed tolerance), §3 (sensor_status wording).
- **Specs / PRODs**: none (delta-tracked surface).
- **Support Docs**: `docs/satan/perceptual-design.md`; investigation `/home/david/.claude/plans/purring-launching-peacock.md`.

## 3. Entrance Criteria

- [x] DR-008 approved (internal + external review integrated).
- [x] Baseline `just check` green before edits (fix the build if not — do not stash).

## 4. Exit Criteria / Done When

- [x] `dl-satan-memory-evidence-git-window-minutes` exists (default 1440); the git probe uses a git-specific `[git-start, end]`, focus/browser/content unchanged.
- [x] `--git-feed-paths` enumerates every **calendar** day in range (DST-immune); `--git-commits-status` sorts by `:end_ts` before limit and tolerates a malformed line per file.
- [x] `:git_window_start_at` present in the raw evidence plist, distinct from `:window_start_at`.
- [x] VT-git-window, VT-feed-paths-multiday, VT-sort-limit, VT-malformed-tolerance, VT-git-window-field green.
- [x] Live spot-check: assemble over a window that includes a recent commit returns it in `git_commits` (the `emacsclient --eval` path from the investigation).
- [x] `just check` green (all tests pass; pre-existing db-probe failure unrelated); lint clean (compile-angel byte-compile on save).

## 5. Verification

- ERT: `satan/test/dl-satan-memory-evidence-test.el` — new/updated cases per coverage entries. Run the suite via `just check` (runs ERT over emacsclient).
- Fixture: a git-segment JSONL helper producing multi-day, multi-repo, shuffled-instant rows + one malformed line (reuse existing segment fixtures if present; check `dl-satan-memory-evidence-test.el` first — DRY).
- Live VA (sanity, not gating here): `emacsclient --eval` of `dl-satan-memory-evidence--git-commits-status` over a full-day window (as run during investigation) still returns rows.

## 6. Assumptions & STOP Conditions

- Assumptions: hook + segment format unchanged; `--filter-segments` overlap semantics unchanged; `assemble` delegates to `assemble-with-bounds` (so the git-start change covers all percept-build paths).
- STOP when: changing the git window measurably bloats the capsule beyond budget caps, or `assemble` turns out NOT to route through `assemble-with-bounds` (would widen scope) — `/consult` before proceeding.

## 7. Tasks & Progress

_(Status: `[ ]` todo, `[WIP]`, `[x]` done, `[blocked]`)_

| Status | ID  | Description | Parallel? | Notes |
| ------ | --- | ----------- | --------- | ----- |
| [x] | 1.1 | Add `dl-satan-memory-evidence-git-window-minutes` defcustom | [ ] | default 1440 |
| [x] | 1.2 | Thread git-specific `[git-start, end]` into the git probe in `assemble-with-bounds`; expose `:git_window_start_at` | [ ] | git-start un-clamped by run_started |
| [x] | 1.3 | Rewrite `--git-feed-paths` to calendar-day enumeration (DST-immune) | [ ] | `--next-day` helper |
| [x] | 1.4 | `--git-commits-status`: sort by `:end_ts` before `(last filt limit)`; per-file parse tolerance | [ ] | degrade-don't-blank |
| [x] | 1.5 | Tests (red→green) for 1.1–1.4 + fixture helper | [ ] | DRY against existing fixtures |

### Task Details

- **1.1 defcustom** — `dl-satan-memory-evidence.el` near `:46` (alongside `window-minutes`/`seg-limit`). Testing: covered indirectly by 1.2 window test.
- **1.2 git window threading** — in `assemble-with-bounds` (`:554`): compute `git-start = iso(end - git-window-minutes)`, pass to `--git-feed-paths` + `--git-commits-status`; add `:git_window_start_at git-start` to the raw plist (`:638`). Leave `focus/browser/content` on `start`. Testing: VT-git-window (commit at end-20min visible with 24h, invisible if 10-min were used), VT-git-window-field.
- **1.3 calendar feed-paths** — replace endpoint-only logic; `string-lessp` loop over `%F` + calendar `--next-day`. Testing: VT-feed-paths-multiday incl. a DST fall-back date range.
- **1.4 sort + tolerance** — sort filtered rows by parsed `:end_ts` ascending before limit; wrap per-file JSONL read so a parse error skips that file. Testing: VT-sort-limit (shuffled append order), VT-malformed-tolerance.
- **1.5 tests/fixture** — build/extend a segment fixture helper; assert each behaviour. Red first, then implement.

## 8. Risks & Mitigations

| Risk | Mitigation | Status |
| ---- | ---------- | ------ |
| R5 DST/sort/malformed correctness | calendar enumeration, sort-before-limit, per-file tolerance; ERT each | open |
| Capsule bloat from 24h backlog | `seg-limit` caps the rendered tail; commit rows are tiny | open |

## 9. Decisions & Outcomes

- `2026-06-02` — git feed gets its own window (DEC-1); no watermark (DEC-2); see DR-008.

## 10. Findings / Research Notes

- Live-verified pre-change: `--git-commits-status` over a full Jun-2 window returns all 5 cross-repo commits; the only defect is the window feeding it.

## 11. Wrap-up Checklist

- [ ] Exit criteria satisfied
- [ ] Verification evidence stored (test run + live eval snippet in notes)
- [ ] DE/IP updated if anything shifted
- [ ] Hand-off note to P02 (predicate now has populated, sorted `git_commits`)
