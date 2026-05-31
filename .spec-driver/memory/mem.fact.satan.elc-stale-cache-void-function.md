---
id: mem.fact.satan.elc-stale-cache-void-function
name: stale .elc cache causes void-function after adding functions
kind: memory
status: active
memory_type: fact
created: '2026-05-31'
updated: '2026-05-31'
verified: '2026-05-31'
confidence: medium
tags:
- satan
- emacs
- sharp-edge
- testing
summary: 'After adding new defuns to a module, stale .elc byte-compiled cache causes
  void-function errors. Run: find satan/ -name ''*.elc'' -delete before testing. Hit
  during DE-003 with dl-satan-db-parse-pg-array.'
---

# stale .elc cache causes void-function after adding functions

## Summary

When you add a new `defun` to an existing elisp module, stale `.elc`
byte-compiled cache files can cause `void-function` errors even though
the source file is correct.

## Fix

```bash
find satan/ -name '*.elc' -delete
```
Then re-run tests. This happened during DE-003 when `dl-satan-db-parse-pg-array`
was added to `dl-satan-db.el` — stale `dl-satan-db.elc` didn't contain the
new function, causing `dl-satan-memory-store-test.el` to fail with
`void-function` even though `dl-satan-memory-store.el` correctly required
`dl-satan-db`.

## When to do it

- After adding any new `defun` to a module that already has a `.elc`
- Before running test suites that transitively depend on the modified module
- As first troubleshooting step for unexplained `void-function` errors

## Related

- [[DE-003]]
