# Implementation Plan SL-018: Extract umbriel client to standalone Elisp package

Prose companion to `plan.toml`. Narrative only — no queried data lives here
(the storage rule); the phase list, criteria, verification, and links are
authored in the TOML. Use this for the plan's rationale and sequencing.
<!-- Reference forms: `lib:reference/glossary.md` § reference forms. -->

## Overview

Four phases, matching design sec-7: copy then cut over (SL-012's pattern).
The config stays green at every commit.

```
PHASE-01 package repo ──┐
                        ├──▶ PHASE-03 cutover ──▶ PHASE-04 docs + records + live check
PHASE-02 dl-checkout  ──┘    (one config commit)
```

## Sequencing & Rationale

- **PHASE-01 and PHASE-02 are independent.** PHASE-01 touches only
  `~/dev/umbriel.el`; PHASE-02 touches only `core/`, `ai/dl-satan.el` and a new
  test. Either may go first or both run in parallel.
- **PHASE-01 before any config edit** proves the suites pass across the repo
  boundary, under `-Q`, under the new names, before the config depends on
  them. Hidden transitive requires surface here, not in the cutover.
- **PHASE-02 ends with the count baseline.** The baseline must be taken after
  `dl-checkout-test` exists and before the umbriel suites leave, so the
  PHASE-03 equality (design sec-5, V4) has one well-defined left side.
- **PHASE-03 is one commit** because any partial state leaves the config with
  dangling names (saved faces, key binds, requires). The user commits by
  hand unless they ask otherwise.
- **PHASE-04 is last** because backlog bodies, memories and the changelog
  should cite paths and names that exist. The live check (V6) needs the
  daemon restarted on the cutover commit.

## Evidence outside this checkout

`~/dev/umbriel.el` sits outside this repo, so no selector, VT mandate or
`verify-vt` run can see it. PHASE-01's checks (V1, V3 package half, V7) are
therefore `VA` rows whose evidence (command and summary line) goes into
`notes.md`. PHASE-03 VA-3 (V4) reuses PHASE-01's recorded package total.

## Plan-time refinements of the locked design

Found while planning (a pi re-check of RV-023 plus re-greps). None changes a
decision. Each sharpens a criterion, so the design was not reopened:

- **Face count.** The source has 16 `defface` forms (`:group 'faces`); the
  design says 17. PHASE-01 EX-5 uses the real count and places `defgroup`
  before the first face.
- **Package lint scope.** The config lint compiles the umbriel suites today
  (`bin/elisp-lint` lints all tracked `.el`). The package lint keeps that:
  tests and runner too (PHASE-01 EX-7).
- **No `.elc` from lint or tests.** The config lint compiles through Flymake's
  batch helper and writes no `.elc`. The package lint must match, and the
  config's smoke and soft-load subprocesses bind the helper's guard. Otherwise
  a devshell-built or test-built `.elc` could look fresh to
  `dl-checkout-compile-stale` (PHASE-01 EX-7, PHASE-03 EX-8).
- **Third sweep.** Four `ui/dl-faces.el` docstring mentions and the suites'
  `dl-test` header comments escape both design sweeps. PHASE-01 EX-3 and
  VA-2 add `rg '\bdl-|\bmy[-/]'`.
- **Soft-load test.** The design's warn branch had no automated check (RV-023
  notes: "needs a run"). PHASE-03 EX-8 adds a no-checkout subprocess test.
- **Paren checker.** The design left copy-vs-point open; the plan copies it
  (two files, `emacs -Q` only), so the package does not depend on the config.

## Notes

- RV-023: all 13 findings raiser-verified at plan time (pi `review` run
  `run-20261110T154155679Z-12-7b2c632eebd7`); ledger `done`.
- ISS-022 (flaky test) is tolerated: re-run once before treating red as real.
- `~/flakes` is not touched (DEC-033).
