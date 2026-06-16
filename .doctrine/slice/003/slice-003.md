# SL-003: Consolidate SATAN DRY violations: shared db, prep-value, slugify, JSONL

# DE-003 – Consolidate SATAN DRY violations

```yaml supekku:delta.relationships@v1
schema: supekku.delta.relationships
version: 1
delta: DE-003
revision_links:
  introduces: []
  supersedes: []
specs:
  primary: []
  collaborators: []
requirements:
  implements: []
  updates: []
  verifies: []
phases: []
```

```yaml supekku:delta.context_inputs@v1
schema: supekku.delta.context_inputs
version: 1
entries:
  - id: docs/satan/INDEX.md
    type: architecture
    source: "docs/satan/INDEX.md"
    summary: "SATAN architecture docs — broker/memory/patch/attribute/perceptual layers"
  - id: POL-001
    type: policy
    source: "POL-001"
    summary: "SATAN module extraction policy — this delta works entirely within the broker; no daemon extraction"
  - id: docs/satan/refactor/plan.md
    type: reference
    source: "docs/satan/refactor/plan.md"
    summary: "Active refactor themes — T1 DRY consolidation is listed"
```

```yaml supekku:delta.risk_register@v1
schema: supekku.delta.risk_register
version: 1
risks:
  - id: R1
    description: "Shared DB module breaks existing psql error handling — regression in memory/patch/attribute write paths"
    likelihood: medium
    impact: high
    mitigation: "Existing test suites for dl-satan-memory-store, dl-satan-patch-store, dl-satan-attribute cover psql error paths; run full ert before merging"
  - id: R2
    description: "prep-value → dl-satan-jsonl-prepare substitution changes JSON serialisation shape (alist handling, keyword stringification)"
    likelihood: low
    impact: medium
    mitigation: "dl-satan-jsonl-prepare is already used by the audit/transcript layer; the substitution aligns all serialisers; audit golden tests will catch"
  - id: R3
    description: "slugify consolidation changes behaviour at edges (different regex, different leading/trailing handling)"
    likelihood: low
    impact: low
    mitigation: "Three functions today, all three have same regex. Canonicalise to dl-satan-memory-canon--slugify (most tested) then replace others"
```

## 1. Summary & Context

- **Product Spec(s)**: None — internal code quality improvement.
- **Technical Spec(s)**: None — the SATAN architecture docs (`docs/satan/INDEX.md`) define the broker's layered architecture; this delta consolidates shared infrastructure within those layers.
- **Implementation Plan**: [DR-003](./DR-003.md) — design revision; IP to follow after DR approval.
- **Change Drivers**: Comprehensive code review of 56 `.el` files (~16,600 lines) on 2026-05-31. Findings documented in review session.

## 2. Motivation

The SATAN broker codebase has accumulated duplicate infrastructure as modules multiplied. The review found 8 DRY violations concentrated in three categories:

1. **psql plumbing** — 4 copies of the `--query(db sql vars)` function across `memory-store`, `patch-store`, `attribute`, and `memory-migrate`. Each assembles identical psql args, runs via `call-process-region`, and returns `(ok . stdout) / (error . msg)`.

2. **JSON serialisation prep** — 3 copies of `--prep-value` (recursive plist→json-serialize normaliser), when `dl-satan-jsonl-prepare` already exists and is more thorough.

3. **Utility clones** — `slugify` in 3 files; `parse-pg-array` in 2; `review-commands` in 2; JSONL file reading in 3.

Consequence: every infrastructure change (psql timeout, connection retry, encoding fix) propagates to 3–4 files. Test coverage for error handling is triplicated. New modules that need psql access will add yet another clone.

This delta targets the **highest-leverage DRY extractions** — those where a single shared module replaces 3+ near-identical copies and the substitution is mechanical.

## 3. Scope & Objectives

- **Primary Outcomes**:
  1. Extract a shared `dl-satan-db` module with `dl-satan-db-query(db sql vars)` replacing 4 `--query` clones.
  2. Delete `--prep-value` / `--prep-plist` clones; route all JSON serialisation through `dl-satan-jsonl-prepare`.
  3. Consolidate `slugify` → single function in `dl-satan-memory-canon` (most tested).
  4. Merge `parse-pg-array` → single implementation.
  5. Unify JSONL reading into `dl-satan-jsonl-read-file` with a `:null-object` keyword arg.
  6. Extract shared `review-commands` helper used by both `tools-patch` and `patch-runner`.
  7. All existing tests pass; no behavioural change to any write path.

- **Operational Constraints**: Broker-process only (per POL-001, no daemon extraction). All changes are pure elisp refactoring — no SQL migrations, no API changes, no format changes.

- **Dependencies**: None. This delta is self-contained.

## 4. Out of Scope

- **Extraction to daemon/CLI** — POL-001 triggers are not met. The `memory-store`, `patch-store`, and `attribute` query helpers all belong to modules that "earn their seat" inside the broker per the extraction policy.
- **Mode tool-list composition** (finding #7) — deferred to a follow-up delta; touches 5 mode specs and needs its own DR.
- **Broker spawn function refactoring** (finding #8) — deferred; the 185-line `--spawn` is a cohesion issue but stable; extracting the shared db module is higher leverage.
- **Output handler factory pattern** (finding #11) — deferred; mode spec `:auto-apply` already provides the mechanism; a follow-up can simplify.
- **Cancellable `"running"` state race** (finding #16) — deferred; needs patch-runner coordination.

## 5. Approach Overview

- **System Touchpoints**: `dl-satan-memory-store.el`, `dl-satan-patch-store.el`, `dl-satan-attribute.el`, `dl-satan-memory-migrate.el`, `dl-satan-intervention.el`, `dl-satan-audit.el`, `dl-satan-tools-hippocampus.el`, `dl-satan-tools-org.el`, `dl-satan-patch-runner.el`, `dl-satan-tools-patch.el`, `dl-satan-memory-canon.el`
- **Key Changes**:
  1. New file: `dl-satan-db.el` — shared psql runner + connection config
  2. Delete: `--query` in memory-store, patch-store, attribute; reroute through `dl-satan-db-query`
  3. Delete: `--prep-value`/`--prep-plist` in memory-store, patch-store, attribute; route through `dl-satan-jsonl-prepare`
  4. Delete: `--slugify` in tools-hippocampus, tools-org; require `dl-satan-memory-canon`
  5. Delete: `--parse-pg-array` in patch-store (or memory-store); unify
  6. Modify: `dl-satan-jsonl-read-file` — add `:null-object` kwarg
  7. Delete: `--read-jsonl` in audit, intervention; use `dl-satan-jsonl-read-file`
  8. Extract: `dl-satan-patch--build-review-commands(row)` used by both tools-patch and runner
- **Migration / Rollout Notes**: No migration. All changes are internal refactoring. Standard workflow: refactor, run full ert suite, lint, commit.

## 6. Verification Strategy

- **Requirements Coverage**: N/A — no formal requirements. Verified by existing test suites.
- **Planned Artefacts**:
  - VT: existing ert suites for all touched modules (35+ test files)
  - VA: none needed (behavioural no-op)
  - VH: none
- **Acceptance Criteria**:
  1. Full ert suite passes with zero regressions
  2. `dl-satan-db.el` has its own test suite (psql success, psql error, connection failure, variable substitution)
  3. No `--query`, `--prep-value`, `--prep-plist`, or `--slugify` private functions remain outside their canonical home
  4. Zero byte-compiler warnings in all touched files

## 7. Follow-ups & Tracking

- **Future Phases / Deltas**:
  - DE-004 (proposed): mode tool-list composition + output handler factory
  - DE-005 (proposed): broker spawn function refactoring
  - DE-006 (proposed): cancellable `"running"` state race fix
- **Backlog Items**: None — findings from code review, not backlog-driven.
- **Open Decisions / Questions**: None. All findings are mechanical. Design decisions in DR-003.

## 8. Implementation Notes

- `dl-satan-db.el` should carry `defcustom` for host/db/program with defaults; all callers override as needed.
- The `--query` API signature is already consistent across all four clones — the shared function drops in without changing call sites.
- `dl-satan-jsonl-prepare` handles alists (converts `(KEY . VAL)` to plist); the three `--prep-value` clones do not. The audit/transcript layer already relies on this behaviour; aligning all serialisers to use it is the point.
