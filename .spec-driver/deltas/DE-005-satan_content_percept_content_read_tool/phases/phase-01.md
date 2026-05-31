---
id: IP-005-P01
slug: "005-satan_content_percept_content_read_tool-phase-01"
name: IP-005 Phase 01
created: "2026-05-31"
updated: "2026-05-31"
status: draft  # one of: completed | deferred | draft | in-progress | pending
kind: phase  # one of: audit | delta | design_revision | issue | memory | phase | plan | policy | problem | prod | requirement | risk | spec | standard | task | verification
plan: IP-005
delta: DE-005
---

# Phase 01 — content_read tool (O1)

## 1. Objective

Ship the `content_read` tool: a read-only window over panopticon's content store
with four scopes (`recent`, `get`, `filter`, `search`), plus the mandatory
`~/notes/satan/tools/content_read.md` behavioural-text file. This phase also
establishes the shared idioms (jsonl-read, limit-clamp, sidecar-read,
malformed-line skip) that P02/P03 reuse.

## 2. Links & References

- **Delta**: DE-005 (O1; risks R1, R6, R7)
- **Design Revision Sections**: DR-005 §4.1 (tool contract), DEC-1/3/4/6, O-1/O-3
- **Prior art**: `satan/dl-satan-tools-activity.el` (consumer pattern, `dl-satan-tool-register`, `(cons 'ok|'error …)`, `--read-json`/`--clamp-limit`); `~/notes/satan/tools/activity_read.md` (description-file shape); `dl-satan-jsonl-read-file`
- **Store**: `~/.local/state/behaviour/content/` — `articles.jsonl` + `<shard>/<hash>.{md,json}` (DE-005 CI1)

## 3. Entrance Criteria

- [x] DR-005 locked (internal + external review integrated)
- [x] Tool/description-file mechanism confirmed (`dl-satan-tool--description` hard-errors if absent; descriptions in `~/notes/satan/tools/`)

## 4. Exit Criteria / Done When

- [ ] `satan/dl-satan-tools-content.el` exists, registers `content_read` (risk=`read`), all 4 scopes implemented per DR-005 §4.1
- [ ] `~/notes/satan/tools/content_read.md` exists (mirrors `activity_read.md`: scope docs + producer-owns-redaction caveat)
- [ ] ert suite green in-session for every scope + error/empty paths (DR-005 §5 VT-content-tool rows)
- [ ] Module byte-compiles clean (compile-angel on save), zero lint warnings
- [ ] `(require 'dl-satan-tools-content)` added to `satan/dl-satan.el`
- [ ] Files `git add`ed (flake visibility — trap #1; switch happens in P04)

## 5. Verification

- `eval-buffer` the module + test file in the running server; `M-x ert` (or `dl-test-run-suite` scoped) → green.
- Cases (VT-content-tool):
  - `recent`: newest-first order; limit default 20, clamp to max 200; honours `recent-scan-max`.
  - `get`: page slice; `offset`/`returned`/`next_offset`/`total_chars` correct across a multi-page body; `limit` clamp [1,5000]; negative offset → clamped to 0 (F-5); offset≥T → returned 0/empty/next_offset null; unknown hash → `unknown content_hash` error; hash-present-but-sidecar-absent → distinct `content body missing` error (F-6).
  - `filter`: by domain; by url substring; both; each row carries `:excerpt`; capped.
  - `search`: rg over fixture `.md`; dedupe-by-hash (one snippet/hash); recency-sort desc (F-2); result cap + `truncated_results`; `--fixed-strings` literal query; rg-missing → soft `:matches []`; invoked via `call-process` arg-vector (O-3).
  - malformed `articles.jsonl` line → skipped, not propagated (O-1).
  - empty store → every scope returns ok with empty payload.
- Evidence: paste ert pass summary into §10.

## 6. Assumptions & STOP Conditions

- Assumptions: store layout per CI1 is stable; `text_content` is the body of record; `.md` filename basename == content_hash.
- STOP when: the store layout differs from CI1 (e.g. no `articles.jsonl`, or `.md` name ≠ hash), or `dl-satan-tool-register`/description mechanism differs from prior art — check in before adapting.

## 7. Tasks & Progress

_(Status: `[ ]` todo, `[WIP]`, `[x]` done, `[blocked]`)_

| Status | ID  | Description | Parallel? | Notes |
| ------ | --- | ----------- | --------- | ----- |
| [ ] | 1.1 | Temp-content-store ert fixture helper | [ ] | reused by P02/P03 |
| [ ] | 1.2 | `recent` scope (red→green) | [ ] | tail + clamp + scan-max |
| [ ] | 1.3 | `get` scope, paginated (red→green) | [ ] | offset/next_offset/total; 2 error paths; clamps |
| [ ] | 1.4 | `filter` scope (red→green) | [ ] | domain/url; excerpt from sidecar |
| [ ] | 1.5 | `search` scope (red→green) | [ ] | rg call-process; dedupe; recency-sort; cap; soft-fail |
| [ ] | 1.6 | Register tool + arg-schema; require in `dl-satan.el` | [ ] | risk=read |
| [ ] | 1.7 | `~/notes/satan/tools/content_read.md` | [P] | mirror activity_read.md |
| [ ] | 1.8 | Lint + byte-compile clean; git add | [ ] | |

### Task Details

- **1.1 Fixture helper**
  - **Approach**: build a temp dir with `articles.jsonl` (N rows incl. one malformed) + matching `<shard>/<hash>.{md,json}`; bind `dl-satan-tools-content-dir` to it. Factor so P02 (sensor) and P03 (rule) reuse.
  - **Files**: `satan/test/dl-satan-tools-content-test.el` (+ shared fixture in an existing test helper if one exists).
- **1.2–1.5 Scopes**
  - **Approach**: red/green/refactor each scope. Reuse activity's `--clamp-limit`/`--read-json` shapes; do NOT prematurely extract a shared lib — mirror, then refactor only if duplication earns it.
  - **Testing**: per §5.
- **1.6 Registration**
  - **Files**: `satan/dl-satan-tools-content.el` (register block), `satan/dl-satan.el` (`require`).
  - **Schema**: `scope` enum(recent/get/filter/search) required; `limit`/`offset` integer; `hash`/`domain`/`url`/`query` string — match handler dispatch.
- **1.7 Description file**
  - **Files**: `~/notes/satan/tools/content_read.md`. Note: outside `.emacs.d` git; not flake-tracked.

## 8. Risks & Mitigations

| Risk | Mitigation | Status |
| ---- | ---------- | ------ |
| Missing description file crashes dispatch (R7/F-1) | Task 1.7; exit criterion asserts presence | open |
| Premature shared-lib abstraction vs activity | Mirror first; refactor only if it earns it | open |
| `articles.jsonl` whole-file read (R6) | `recent-scan-max` cap (DEC-6) | open |

## 9. Decisions & Outcomes

- `2026-05-31` — Phase scoped from DR-005; tool is P01 because it establishes shared jsonl/clamp idioms for P02/P03.

## 10. Findings / Research Notes

- (ert evidence + spelunking notes go here during execution)

## 11. Wrap-up Checklist

- [ ] Exit criteria satisfied
- [ ] Verification evidence stored (ert summary in §10)
- [ ] DE/IP updated if scope shifted
- [ ] Hand-off note to P02/P03 (shared fixture location, idiom decisions)
