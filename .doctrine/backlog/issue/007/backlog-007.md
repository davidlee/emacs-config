# ISS-007: satan extraction test fallout: orphan doctor test removed; just check now scans empty lisp/test, org ert suites ungated

<!-- Backlog item body — context, detail, links. The structured, queried fields
     live in the sister `backlog-NNN.toml`; this prose is free-form and is never
     structurally parsed (the storage rule). -->

## What happened

SL-012 extracted SATAN to a standalone repo and deleted `satan/` (commit
`20200c0`, "chore: delete satan (moved to davidlee/satan)"). Two loose ends
surfaced while closing SL-013 PHASE-02:

1. **Orphan test aborted the gate.** `lisp/test/dl-sleipnir-doctor-test.el`
   still `(require 'satan-memory-evidence)` — a now-deleted module. A single
   hard `require` LOADERR aborts the whole `dl-test-run-suite` at "0 tests", so
   `just check` was fully non-functional (nothing ran). Removed the orphan test
   here (its own header pointed load-path at `~/dev/satan/satan`; it belongs in
   the extracted repo). `dl-sleipnir-doctor.el` itself only `declare-function`s
   satan symbols (soft), so it still loads and stays.

2. **Gate now scans an empty directory.** `dev/dl-test.el` hardcodes
   `dl-test-suite-dirs = '("lisp/test")`. That dir held only the satan doctor
   test; removing it leaves `lisp/test/` empty (git dropped the dir), so
   `just check` reports a **vacuous** `PASS 0/0`. The repo's actual ert suites
   — `org/dl-denote-journal-test.el`, `org/dl-denote-promote-test.el` — live
   under `org/` and were never in the gate's scan path. They pass, but only
   when run explicitly via `emacs --batch -L core -L org -l <file>`.

## Recommendation

Re-anchor the gate to real coverage: either widen `dl-test-suite-dirs` to
include `org/` (and any other suite homes), or relocate the org suites under
`lisp/test/`. Confirm no satan-DB preflight regressions once org suites join
the gate. Related: ISS-005 (stale bough binary — a separate `just check` red).
