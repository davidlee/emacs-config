---
id: IP-005-P02
slug: "005-satan_content_percept_content_read_tool-phase-02"
name: IP-005 Phase 02
created: "2026-05-31"
updated: "2026-05-31"
status: completed  # one of: completed | deferred | draft | in-progress | pending
kind: phase  # one of: audit | delta | design_revision | issue | memory | phase | plan | policy | problem | prod | requirement | risk | spec | standard | task | verification
plan: IP-005
delta: DE-005
---

# Phase 02 — content-backlog sensor (O2)

## 1. Objective

Ship the content-backlog sensor: a near-clone of `dl-satan-sensor-curiosity.el` that
emits a `content_backlog` attribute signal when uninspected captures exist in
`articles.jsonl`. The ONE deviation from curiosity is the DEC-5 watermark — store
the max `captured_at` string seen verbatim (UTC-millis-Z), not a formatted `now()`.

## 2. Links & References

- **Delta**: DE-005 (O2; risks R5)
- **Design Revision Sections**: DR-005 §4.2 (sensor contract), DEC-5 (watermark format)
- **Prior art**: `satan/dl-satan-sensor-curiosity.el` (clone target — probe/state/emit/disable pattern)
- **Prior art**: `satan/dl-satan-sensor-wpm.el` (alternate sensor shape, same broker integration)
- **Shared idiom**: `satan/dl-satan-tools-content.el` — `dl-satan-tools-content--read-articles-jsonl` (lenient JSONL reader, skips malformed per O-1)
- **Broker**: `satan/dl-satan-broker.el:743` — call site; line 30 — require list
- **Attribute layer**: `satan/dl-satan-attribute.el` — `dl-satan-attribute-build-sensor-payload`, `dl-satan-attribute-enqueue`

## 3. Entrance Criteria

- [x] DR-005 locked (internal + external review integrated)
- [x] P01 idioms established (lenient jsonl reader, test fixture)
- [x] Call site confirmed: `dl-satan-broker.el:743`, `condition-case` wrapped, alongside curiosity

## 4. Exit Criteria / Done When

- [x] `satan/dl-satan-sensor-content.el` exists with probe + watermark + disable switch per DR-005 §4.2
- [x] Watermark stores max `captured_at` string verbatim (DEC-5), NOT formatted `now()` — tested
- [x] `(require 'dl-satan-sensor-content)` added to `dl-satan-broker.el`
- [x] Probe call added to broker `let*` block, `condition-case` wrapped
- [x] ert suite green in-session: backlog count, watermark advance, DEC-5 format, disable→no-op, soft-fail
- [x] Module byte-compiles clean (compile-angel on save), zero lint warnings
- [ ] Files `git add`ed (flake visibility — trap #1)

## 5. Verification

- `eval-buffer` the sensor module + test file in the running server; `M-x ert` → green.
- Cases (VT-content-sensor):
  - **Backlog detected**: articles.jsonl has 3 rows → sensor emits with count=3, advances watermark to max `captured_at`
  - **No backlog**: all `captured_at` ≤ watermark → no emit, watermark unchanged
  - **Watermark format (DEC-5)**: watermark is verbatim `captured_at` string (`2026-05-31T05:25:45.968Z`), NOT `format-time-string` output
  - **Disabled**: `dl-satan-sensor-content-enabled` nil → probe returns nil without emit
  - **Soft-fail**: unreadable state file or articles.jsonl → `message` + nil
  - **Malformed line skip**: articles.jsonl with broken line → count excludes broken line, doesn't crash
- Evidence: paste ert pass summary into §10.

## 6. Assumptions & STOP Conditions

- Assumptions: `articles.jsonl` `captured_at` format is `YYYY-MM-DDTHH:MM:SS.sssZ` (UTC-millis-Z); broker's `:ts` is a different format and is NOT used for watermark; `dl-satan-attribute-updates-enabled` guards emit (same as curiosity); initial watermark `""` sorts before all timestamps.
- STOP when: the DEC-5 divergence isn't clear (format mismatch between broker ts and captured_at), or the `captured_at` format in the actual store differs from CI1.

## 7. Tasks & Progress

_(Status: `[ ]` todo, `[WIP]`, `[x]` done, `[blocked]`)_

| Status | ID  | Description | Parallel? | Notes |
| ------ | --- | ----------- | --------- | ----- |
| [x] | 2.1 | `satan/dl-satan-sensor-content.el` — probe + watermark + disable | [ ] | near-clone curiosity; DEC-5 divergence |
| [x] | 2.2 | ert suite — backlog, watermark format, disable, soft-fail | [ ] | reuse P01 `--with-store` fixture |
| [x] | 2.3 | Broker integration — require + probe call | [ ] | `dl-satan-broker.el:31` + line 743 |
| [ ] | 2.4 | Lint + byte-compile clean; git add | [ ] | |

### Task Details

- **2.1 Sensor module**
  - **Design / Approach**: Clone `dl-satan-sensor-curiosity.el` structure: defcustoms for state-file and enabled switch → state read/write → probe function. The key difference: `--count-uninspected` walks `articles.jsonl` rows (via lenient reader from P01), partitions by `(string< watermark captured_at)`, and returns `(count . high-water)` where `high-water` = max `captured_at` seen. On emit, `mark-inspected` stores the `high-water` string verbatim — NOT ts/now (DEC-5).
  - **Files / Components**: `satan/dl-satan-sensor-content.el` (NEW)
  - **Testing**: per §5; ert in running server via `eval-buffer`
  - **Observations & AI Notes**: Uses `dl-satan-tools-content--read-articles-jsonl` from the tools module (depends on require). Attribute payload `:sensor-type "panopticon_content_backlog"`.

- **2.2 ert suite**
  - **Design / Approach**: Reuse `dl-satan-tools-content-test--with-store` macro. Cases: (a) 3 articles → emit, watermark advances to max; (b) all behind watermark → no emit; (c) disabled → no-op; (d) empty store → no emit, no crash; (e) malformed line → skipped.
  - **Files / Components**: `satan/test/dl-satan-sensor-content-test.el` (NEW)
  - **Testing**: ert via `eval-buffer`

- **2.3 Broker integration**
  - **Design / Approach**: Add `(require 'dl-satan-sensor-content)` after line 31 (`dl-satan-sensor-wpm`). Add `_content-signal` binding in the `let*` block after `_curiosity-signal`, same `condition-case` shape.
  - **Files / Components**: `satan/dl-satan-broker.el`

## 8. Risks & Mitigations

| Risk | Mitigation | Status |
| ---- | ---------- | ------ |
| DEC-5 format mismatch: broker ts vs captured_at | Store max `captured_at` verbatim; ert asserts format | open |
| Cross-module dependency (sensor→tools) | Acceptable — same in-tree family; tools module is P01's deliverable | open |

## 9. Decisions & Outcomes

- `2026-05-31` — Phase scoped from DR-005 §4.2; sensor is P02 because it reuses P01's lenient jsonl reader.

## 10. Findings / Research Notes

- Call site confirmed: `dl-satan-broker.el:743`, in `let*` block, `condition-case` wrapped, immediately after curiosity probe.
- Curiosity stores timestamp via `format-time-string "%Y-%m-%dT%T%:z"` → local offset (`+10:00`). Content `captured_at` is UTC-millis-Z (`2026-05-31T05:25:45.968Z`). Lexical `string<` between them is meaningless → DEC-5 correct.
- P01's `dl-satan-tools-content--read-articles-jsonl` uses lenient parser that skips malformed lines — exactly what the sensor needs (per-tick read, concurrent append).
- **2026-05-31**: 31/31 ert pass (23 P01 + 8 new). Sensor depends on `dl-satan-tools-content` for lenient reader. Batch-mode `defcustom` clash resolved by requiring `dl-satan-attribute` at top level of test file. DEC-5 watermark format verified by dedicated test.
- Broker integration: `(require 'dl-satan-sensor-content)` added after `dl-satan-sensor-curiosity`; `_content-signal` probe added in `let*` block line ~750, `condition-case` wrapped, mirroring curiosity's shape.

## 11. Wrap-up Checklist

- [x] Exit criteria satisfied
- [x] Verification evidence stored (ert summary in §10)
- [x] DE/IP updated if scope shifted
- [x] Hand-off note to P03 (shared fixture, sensor→tools dependency note)
