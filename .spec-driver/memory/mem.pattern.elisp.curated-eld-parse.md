---
id: mem.pattern.elisp.curated-eld-parse
name: 'Curated .eld data: read all forms + test the real file'
kind: memory
status: active
memory_type: pattern
created: '2026-06-03'
updated: '2026-06-03'
verified: '2026-06-03'
confidence: medium
tags:
- elisp
- data
summary: read-once silently drops later top-level forms; parse with read-all-and-append
  and test the parser against the real checked-in file, not a prin1'd fixture
---

# Curated .eld data: read all forms + test the real file

## Summary

`(read (current-buffer))` consumes exactly **one** top-level form. A curated
`.eld` data file written as several `((..))` forms (one per record) yields only
the first record — the rest vanish silently, no error. Parse curated data with a
**read-all-forms-and-append** loop, and always write at least one test that loads
the **real checked-in file**, not a `prin1`'d synthetic fixture.

## Context

- Bit DE-009 (AUD-006 F-001): `satan/patterns.eld` had 3 separate top-level forms;
  `dl-satan-pattern--read-file` did a single `read` → only `docs-after-error`
  synced; `terminal-coding` + `editor-commit` were silently dropped. Pattern
  attribution degraded 67% with the whole test suite green.
- Invisible because every pattern test built its fixture via
  `dl-satan-pattern-test--write-patterns` (`prin1` of one list) — structurally a
  single well-formed form, so it could never reproduce the multi-form shape.
- Fix: canonical single-list file + read-all-forms reader + DB-free regression
  `dl-satan-pattern/real-eld-parses-all-seeds` that parses the real file.
- General rule: a parser and the data it parses must be tested against the
  **actual artefact** shipped, not a re-serialised stand-in.
