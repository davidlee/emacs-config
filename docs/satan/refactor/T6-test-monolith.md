---
name: satan-refactor-T6
description: Split the 2337-LOC test/dl-satan-test.el monolith into per-module test files
metadata:
  type: refactor-theme
  topic: satan-refactor
  status: in-progress
  blocked_by: []
  updated_at: 2026-05-23
---

# Theme T6 — Split the test monolith

**Impact:** Med. **Effort:** M (mechanical but tedious). **Risk:** Low. **Reversibility:** Trivial.

## Current shape

`test/dl-satan-test.el` is 2337 LOC containing 134 ert-deftests covering 18 modules (sub-agent H). Already well-sectioned by source-module name prefix. Memory substrate is the working alternative: 8 dedicated per-module test files totalling ~119 tests (`review/08-TESTABILITY.md`).

## Why it hurts

Finding tests for a module requires searching by name prefix inside a 2337-line file; running a module's tests means running all 134; adding attribute-related tests (state, intervention records, outcome classifications, Shame deltas, capsule rendering — easily 30+ new tests) would push the monolith past 3000 LOC.

## Target shape

Per-module test files mirroring the memory substrate pattern. Roughly 12–15 new files: `test/dl-satan-jsonl-test.el`, `test/dl-satan-block-test.el`, etc. Some closely-related sections (broker prepare + utilities + manifest) collapse into one file.

## Migration sketch

One PR per module. Lift the section, drop into a new file with `(require 'dl-satan-MODULE)` + helpers, confirm green. Start small (jsonl, 6 tests) to prove the pattern; finish with the large sections (context, broker, tools registry).

## Considered and rejected

- Section the monolith with markers without splitting files — kicks the can.
- Split by responsibility (handler / dispatch / budget / audit) — doesn't align with module boundaries.

## First concrete step

PR that extracts `dl-satan-jsonl-test.el` from `test/dl-satan-test.el` L44–112. Confirm both old + new files run green.

## Open questions

- Cross-module tests (`dl-satan-broker/refuses-spawn-when-budget-exceeded` exercises both broker and budget) — file by assertion subject (broker) with a comment, or by setup (budget)? Recommendation: assertion subject.

## PR log

- [x] PR 1: extract `dl-satan-jsonl-test.el` (proof of pattern) — merged 2026-05-23
- [x] PR 2: extract `dl-satan-block-test.el` — merged 2026-05-23
- [x] PR 3: extract `dl-satan-tools-test.el` (schema validator subsection) — merged 2026-05-23
- [x] PR 4: dispatch capability guard → `dl-satan-tools-test.el` + cross-cutter to `dl-satan-broker-test.el` — merged 2026-05-23
- [x] PR 5: extract `dl-satan-tools-notify-test.el` — merged 2026-05-23
- [x] PR 6: extract `dl-satan-tools-inbox-test.el` — merged 2026-05-23
- [x] PR 7: merge file-side hippocampus tests into `dl-satan-tools-hippocampus-test.el` — merged 2026-05-23
- [x] PR 8: extract `dl-satan-tools-org-test.el` — merged 2026-05-23
- [x] PR 9: merge self-edit context-fn tests into `dl-satan-context-test.el` — merged 2026-05-23
- [x] PR 10: append JSON Schema builder tests to `dl-satan-tools-test.el` — merged 2026-05-23
- [x] PR 11: append `dl-satan-broker--prepare` tests to `dl-satan-broker-test.el` — merged 2026-05-23
- [ ] PR 12..N: remaining modules, one per PR — pending
