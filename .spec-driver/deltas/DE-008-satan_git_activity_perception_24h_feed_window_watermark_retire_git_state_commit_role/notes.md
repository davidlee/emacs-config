# Notes for DE-008

## Phase 01 — Feed perception: git 24h window (2026-06-02)

### What's done

Five changes in `satan/dl-satan-memory-evidence.el`:

1. **`dl-satan-memory-evidence-git-window-minutes`** defcustom (default 1440 = 24h).
2. **`--git-feed-paths` rewritten** — calendar-day enumeration via `--next-day` (DST-immune).
3. **`--git-commits-status` hardened** — per-file parse tolerance + sort by `:end_ts`.
4. **`git-start` threaded** into `assemble-with-bounds` — git probe on 24h window.
5. **`:git_window_start_at`** exposed in raw evidence plist.

7 new ERT tests, all passing. Live spot-check: 5 real cross-repo commits in 24h window.

Commit: `a3dc8c1`

### Surprises

- `--next-day` uses `parse-iso8601-time-string` + `decode-time` + `calendar-absolute-from-gregorian`; `calendar.el` API is designed for `(month day year)` lists.
- `%F` format is lexicographically chronological — `string-lessp` correct for the while-loop guard.

## Phase 02 — Outcome predicate + git_state demotion (2026-06-02)

### What's done

1. **Predicate swap**: `:git_head_changed` → `:git_commit_observed` in `dl-satan-observer-classify.el`.
   - `--git-row-matches-motive`: `string-equal` on expanded paths (NOT `file-equal-p` — returns nil for non-existent paths).
   - `--git-row-in-window`: `:end_ts` in `(:intervention_emitted_at, window-end]`.
   - No baseline needed (window-anchored).
2. **Tank**: git line renders `:git_commits` count + newest sha + `:git_window_start_at`.
3. **Docs**: `outcome-semantics.md`, `CHANGELOG.md`, `perceptual-design.md` updated.
4. **Tests**: 6 new P2 tests + 4 integration fixture updates + tank test update.

`just check`: 947 total, 1 pre-existing failure (db-probe), 0 new failures.

Commit: `5de4dc6`

### Surprises

- **`file-equal-p` trap**: Returns nil for non-existent paths (unspecified per docstring). Switched to `string-equal` on `expand-file-name` + `directory-file-name` normalized paths. Test fixtures use temp paths that don't exist on disk — caught during integration test debugging.

### Follow-ups

- VA-live-tick pending
- `:crosses_midnight` guard (Q3) still not addressed
- `:dirty` retargeting deferred to follow-up delta
