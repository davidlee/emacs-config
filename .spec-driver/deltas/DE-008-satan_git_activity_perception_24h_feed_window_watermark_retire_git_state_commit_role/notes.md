# Notes for DE-008

## Phase 01 — Feed perception: git 24h window (2026-06-02)

### What's done

Five changes in `satan/dl-satan-memory-evidence.el`:

1. **`dl-satan-memory-evidence-git-window-minutes`** defcustom (default 1440 = 24h) — decoupled from the 10-min attention window.
2. **`--git-feed-paths` rewritten** — calendar-day enumeration via `--next-day` helper using `calendar-gregorian-from-absolute` arithmetic (DST-immune).
3. **`--git-commits-status` hardened** — per-file JSONL parse tolerance (one bad day-file doesn't blank good siblings); filtered rows sorted by `:end_ts` before limit so newest is genuinely the last.
4. **`git-start` threaded** into `assemble-with-bounds` — git probe window computed from `end - git-window-minutes`, un-clamped by `run_started`. Focus/browser/content probes unchanged.
5. **`:git_window_start_at`** exposed in the raw evidence plist alongside `:window_start_at`.

Seven new ERT tests, all passing:
- `git-feed-paths-multiday`, `git-feed-paths-dst-fallback`, `git-feed-paths-next-day`
- `git-commits-malformed-tolerant`, `git-commits-sorted-by-end-ts`
- `git-window-sees-commit-outside-10min`, `git-window-field-distinct`

`just check`: 945 total, 1 pre-existing failure (db-probe), 0 new failures.

### Surprises / Adaptations

- `--next-day` uses `parse-iso8601-time-string` + `decode-time` + `calendar-absolute-from-gregorian` rather than `calendar-extract-day`. The `calendar.el` API is designed for interactive use with `(month day year)` lists; the decode-time bridge is the cleanest path for a `%F` string input.
- The DR specified `string-lessp` for the while-loop guard. Confirmed correct: `%F` format is lexicographically chronological (`"2026-05-19"` < `"2026-05-20"`).

### Rough edges / follow-ups

- **Live spot-check pending**: `emacsclient --eval` of the assemble path with a 24h window over a tracked repo. Requires an active Emacs daemon with the new code loaded. Not gating for phase exit (ERT covers the logic); P02 VA-live-tick covers this end-to-end.
- **`seg-limit` (Q2)**: still 10 commits in the rendered tail. Sufficient for current commit volume; observer predicate scans the full filtered set, so the limit only affects the capsule view.
- **`:crosses_midnight` guard (Q3)**: not addressed here; P02 predicate inherits the punt. Separate follow-up delta.

### Commit state

Uncommitted. `.spec-driver/**` and code changes will be committed together per doctrine.
