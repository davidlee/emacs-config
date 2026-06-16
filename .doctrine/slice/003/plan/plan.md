# Implementation Plan for SL-003

```yaml supekku:plan.overview@v1
schema: supekku.plan.overview
version: 1
plan: IP-003
delta: DE-003
revision_links:
  aligns_with: [DR-003]
specs:
  primary: []
  collaborators: []
requirements:
  targets: []
  dependencies: []
phases:
  - id: IP-003-P01
```

```yaml supekku:verification.coverage@v1
schema: supekku.verification.coverage
version: 1
subject: IP-003
entries:
  - artefact: dl-satan-db-test.el
    kind: VT
    requirement: ~
    status: planned
    notes: New test suite for shared db module
  - artefact: Existing ert suites (35+)
    kind: VT
    requirement: ~
    status: existing
    notes: Regression gate — all must pass
```

## 1. Summary

- **Delta**: DE-003 — Consolidate SATAN DRY violations
- **Specs Impacted**: None — internal refactoring
- **Problems / Issues**: 8 DRY findings from 2026-05-31 code review
- **Desired Outcome**: Single shared psql runner replaces 4 clones; single JSON serialiser prep replaces 3 clones; single slugify, pg-array parser, JSONL reader, review-commands builder each replace 2 clones. ~185 lines deleted, zero behavioural change.

## 2. Context & Constraints

- **Current Behaviour**: Four modules carry private `--query` clones; three carry `--prep-value` clones; two carry `slugify` clones; etc.
- **Target Behaviour**: One shared `dl-satan-db.el` (psql), one canonical `dl-satan-jsonl-prepare` (JSON), one `dl-satan-memory-canon--slugify`, etc. Identical wire/disk output.
- **Dependencies**: None — self-contained.
- **Constraints**: Broker-process only (POL-001). Zero behavioural change. All existing tests pass. No SQL migrations.

## 3. Gate Check

- [x] DR-003 populated with design decisions
- [x] POL-001 confirms all modules stay in broker
- [ ] All ert suites pass after refactoring
- [ ] Zero byte-compiler warnings
- [ ] New `dl-satan-db-test.el` covers psql success/error/connection-failure

## 4. Phase Overview

| Phase | Objective | Entrance Criteria | Exit Criteria | Phase Sheet |
|-------|-----------|-------------------|---------------|-------------|
| P01 — Extract shared infra | Create `dl-satan-db.el`; kill clones; reroute serialisers; unify slugify/pg-array/JSONL/review-commands | DR-003 approved, IP-003 drafted | All 6 changes implemented, ert green, lint clean | `phases/phase-01.md` |

_Single phase — the changes are mechanical and sequential (each change is a commit). No parallel work; each step's tests gate the next._

## 5. Phase Detail Snapshot

- **Design Revision**: [DR-003](./DR-003.md)
- **Active Phase Sheet**: `phases/phase-01.md`
- **Parallelisable Work**: None — sequential. Each change depends on the previous being correct (shared db module must exist before callers switch to it).
- **Plan Updates**: If a decoupling surprise emerges (circular require, edge-case test failure), update this plan.

## 6. Testing & Verification Plan

- **New Suites**: `test/dl-satan-db-test.el` — psql success, psql error (bad SQL), connection failure (bad host), variable substitution, `--single-transaction` flag passthrough.
- **Modified Suites**: `test/dl-satan-jsonl-test.el` — add `:null-object` kwarg round-trip test.
- **Regression Gate**: Run full `satan/test/*.el` suite. Key suites: `dl-satan-memory-store-test`, `dl-satan-patch-store-test`, `dl-satan-attribute-test`, `dl-satan-memory-grammar-test` (slugify), `dl-satan-audit-test` (JSONL read), `dl-satan-intervention-test`, `dl-satan-tools-patch-test`.
- **Rollback Plan**: `git revert` per commit. Each change is a single commit; reverting any step leaves the rest intact.

## 7. Risks & Mitigations

| Risk | Mitigation | Owner |
|------|------------|-------|
| R1: psql error handling breaks in memory/patch/attribute paths | Run existing test suites for each module after switching to shared fn |
| R2: `dl-satan-jsonl-prepare` changes serialisation shape (alist handling) | All three clones only receive plists; no alist callers exist. Verify by test. |
| R3: circular require between dl-satan-memory-canon (slugify) and dl-satan-tools-hippocampus | Already required: `tools-hippocampus` requires `memory-canon`. No cycle. |
| R4: latent `-q` fix in memory-store changes stdout output for callers that relied on welcome banner | No caller parses `--query` stdout without `string-trim`. Banner was always noise. |

## 8. Open Questions & Decisions

None. All design decisions resolved in DR-003.

## 9. Progress Tracking

- [ ] Phase P01 complete
- [ ] Verification gates passed

## 10. Notes / Links

- Code review findings: 2026-05-31 (session)
- `docs/satan/memory/design.md` — slugify authority
- POL-001 — extraction policy (confirms broker scope)
