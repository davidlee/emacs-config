---
id: mem.fact.satan.batch-ert-redefined-double-load
slug: batch-ert-redefined-double-load
name: batch ERT redefined error from sibling require + suite re-load
kind: memory
status: active
memory_type: fact
created: '2026-05-31'
updated: '2026-05-31'
verified: '2026-05-31'
confidence: high
scope:
  paths:
  - dev/dl-test.el
  globs:
  - satan/test/**
provenance:
  sources:
    - kind: code
      ref: dev/dl-test.el
    - kind: code
      ref: ert.el:155
tags:
- satan
- testing
- emacs
- sharp-edge
summary: Batch (noninteractive) ert-deftest errors 'redefined (or loaded twice)' when
  a sibling test file requires another for fixture macros and the suite then loads
  it again. dl-test-run-suite skips already-provided features. Interactive emacsclient
  tolerates it silently.
---

# batch ERT redefined error from sibling require + suite re-load

## Summary

`ert.el:155`: `ert-deftest` errors `Test 'X' redefined (or loaded twice)`
**only when `noninteractive`** (batch). Interactive (emacsclient) silently
redefines.

Trigger: some `satan/test/*` files `(require 'dl-satan-FOO-test)` to reuse
fixture macros. If the requiring sibling sorts earlier in `directory-files`,
its `require` loads FOO-test (defines every `ert-deftest`, `provide`s the
feature) before the suite loop reaches FOO-test.el; the loop then `load`s it
again → first deftest redefines → error aborts that file's load.

## Fix / invariant

`dl-test-run-suite` skips files whose feature is already provided:
`(unless (featurep (intern (file-name-base f))) (load f ...))`. Each test file
must `(provide 'dl-satan-FOO-test)` (basename) for this to hold. A re-aborted
load also corrupts the file's other tests → spurious "flaky" failures.

This was masked for a long time because `just check` used to be emacsclient
(interactive); DE-006 renamed `check` to batch and surfaced it. See
[[mem.fact.satan.test-db-isolation]].

## Context
