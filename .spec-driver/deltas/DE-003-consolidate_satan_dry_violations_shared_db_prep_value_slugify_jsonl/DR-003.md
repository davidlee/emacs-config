---
id: DR-003
slug: consolidate_satan_dry_violations_shared_db_prep_value_slugify_jsonl
name: "Design Revision - Consolidate SATAN DRY violations"
created: "2026-05-31"
updated: "2026-05-31"
status: draft
kind: design_revision
aliases: []
owners: []
relations:
  - type: implements
    target: DE-003
delta_ref: DE-003
source_context:
  - "docs/satan/INDEX.md"
  - "POL-001"
code_impacts:
  - "dl-satan-memory-store.el —psql query, prep-value, parse-pg-array"
  - "dl-satan-patch-store.el — psql query, prep-value"
  - "dl-satan-attribute.el — psql query, prep-value"
  - "dl-satan-memory-migrate.el — psql runner"
  - "dl-satan-intervention.el — JSONL read, pg-array parse, exec-sql"
  - "dl-satan-audit.el — JSONL read"
  - "dl-satan-memory-canon.el — slugify (canonical home)"
  - "dl-satan-tools-hippocampus.el — slugify"
  - "dl-satan-tools-org.el — slugify"
  - "dl-satan-tools-patch.el — review-commands"
  - "dl-satan-patch-runner.el — review-commands"
  - "dl-satan-jsonl.el — prep-value already exists, add null-object kwarg"
  - "NEW: dl-satan-db.el — shared psql runner"
verification_alignment:
  - "Existing ert suites cover all write paths; no new VTs needed for behavioural no-op"
  - "New VT: dl-satan-db-test.el — psql success, error, connection failure, variable substitution"
  - "New VT: dl-satan-jsonl-test.el updates — null-object kwarg round-trip"
design_decisions:
  - "DEC-001: dl-satan-db-query signature matches existing —(db sql vars) → (ok . stdout) | (error . msg)"
  - "DEC-002: dl-satan-jsonl-prepare as sole prep-value; kills 3 clones"
  - "DEC-003: canonical slugify lives in dl-satan-memory-canon (most tested, memory.design.md §3.1 authority)"
  - "DEC-004: dl-satan-jsonl-read-file gains —:null-object kwarg; audit/intervention callers switch"
  - "DEC-005: shared review-commands helper in dl-satan-patch-store or new dl-satan-patch-common"
open_questions: []
---

# DR-003 – Consolidate SATAN DRY violations

## 1. Executive Summary

- **Delta**: [DE-003](./DE-003.md)
- **Status**: draft
- **Owners / Team**: —
- **Last Updated**: 2026-05-31
- **Synopsis**: Consolidate 8 DRY violations found in code review — ~120 lines of duplicated code deleted, 4 cloned functions replaced by 1 shared module, 3 cloned serialisers routed through the existing canonical one. All changes are internal, behavioural no-ops, broker-process only (per POL-001).

## 2. Problem & Constraints

- **Current Behaviour**: Four modules that talk to PostgreSQL (`memory-store`, `patch-store`, `attribute`, `memory-migrate`) each carry a private `--query` function with identical psql argument assembly and error handling. Three modules carry a private `--prep-value` recursive normaliser for `json-serialize` when `dl-satan-jsonl-prepare` already does this (more thoroughly). Three modules carry a private `slugify`. Two modules read JSONL files with identical logic. Two modules build the same `review_commands` list.

- **Drivers / Inputs**: Code review findings 2026-05-31 (findings #1–#6, #14). POL-001 confirms all touched modules "earn their seat" inside the broker — no extraction is triggered.

- **Constraints / Guardrails**:
  - Zero behavioural change. No byte on disk or wire changes.
  - All existing ert suites must pass.
  - No SQL migrations, no format changes, no API changes.
  - `psql` argument assembly must remain identical (same flags, same error handling).
  - `dl-satan-jsonl-prepare` is already the audit/transcript canonical serialiser; aligning all modules to it is a correctness win, not a risk.

- **Out of Scope**: Extraction to daemon (POL-001 triggers not met). Mode tool-list composition, broker spawn refactoring, output handler factory, cancellable-state race (all deferred to follow-up deltas).

## 3. Architecture Intent

- **Target Outcomes**:
  1. **Shared DB module**: `dl-satan-db-query(db sql vars)` replaces 4 `--query` clones. Callers pass their preferred `db` string; host/program default from defcustoms on `dl-satan-db` group.
  2. **Single JSON serialiser**: `dl-satan-jsonl-prepare` used everywhere; 3 `--prep-value`/`--prep-plist` clones deleted.
  3. **Single slugify**: `dl-satan-memory-canon--slugify` used by hippocampus and org tools.
  4. **Single pg-array parser**: one `parse-pg-array` implementation, shared.
  5. **Single JSONL reader**: `dl-satan-jsonl-read-file` with `:null-object` kwarg; audit and intervention callers switch.
  6. **Single review-commands builder**: extracted helper used by both tools-patch and patch-runner.

- **Guiding Principles**:
  - **Authority**: `dl-satan-memory-canon` is the authority for slugify (referenced by `memory.design.md` §3.1, already tested against the DB grammar sync test).
  - **Canonical serialiser**: `dl-satan-jsonl` is the authority for JSON preparation (used by audit transcript, harness wire, manifest assembly).
  - **DB access**: `dl-satan-db` is the single entry point for psql subprocess calls within the broker. Modules that need custom psql behaviour (e.g. `memory-migrate`'s `--single-transaction`) pass extra flags.

- **State Transitions / Lifecycle Impact**: None. All changes are function-level refactoring.

## 4. Code Impact Summary

| Path | Current State | Target State |
|------|--------------|--------------|
| `dl-satan-memory-store.el` | `--query(db sql vars)` → psql, **no `-q`** | `dl-satan-db-query(db host program sql vars)` → psql with `-q` |
| `dl-satan-patch-store.el` | `--query(db sql vars)` → psql | `dl-satan-db-query(db host program sql vars)` |
| `dl-satan-attribute.el` | `--query(db sql vars)` → psql | `dl-satan-db-query(db host program sql vars)` |
| `dl-satan-memory-migrate.el` | `--psql(db flags sql)` → psql | `dl-satan-db-psql(db flags sql)` wrapper |
| `dl-satan-intervention.el` | `--exec-sql(db sql)` wraps `memory-migrate` | wraps `dl-satan-db-psql` |
| `dl-satan-memory-store.el` | `--prep-value` / `--prep-plist` → json-serialize | `dl-satan-jsonl-prepare` |
| `dl-satan-patch-store.el` | `--prep-value` → json-serialize | `dl-satan-jsonl-prepare` |
| `dl-satan-attribute.el` | `--prep-value` → json-serialize | `dl-satan-jsonl-prepare` |
| `dl-satan-memory-canon.el` | `--slugify` (private) | unchanged (canonical home) |
| `dl-satan-tools-hippocampus.el` | `--slugify` (private) | `dl-satan-memory-canon--slugify` |
| `dl-satan-tools-org.el` | `--slugify` (private, if exists) | `dl-satan-memory-canon--slugify` |
| `dl-satan-memory-store.el` | `--parse-pg-array` | shared fn (from intervention if better) |
| `dl-satan-intervention.el` | `--parse-pg-array-text` | shared fn (survives — better double-quote handling) |
| `dl-satan-jsonl.el` | `dl-satan-jsonl-read-file(path)` | `dl-satan-jsonl-read-file(path &key null-object)` |
| `dl-satan-audit.el` | `--read-jsonl(path)` private | `dl-satan-jsonl-read-file` |
| `dl-satan-intervention.el` | `--read-jsonl(path)` private | `dl-satan-jsonl-read-file` |
| `dl-satan-tools-patch.el` | `--review-commands(row)` private | `dl-satan-patch--build-review-commands(row)` |
| `dl-satan-patch-runner.el` | `--review-commands(row commits)` | `dl-satan-patch--build-review-commands(row)` |
| **NEW** `dl-satan-db.el` | — | Shared psql runner + defcustoms |

## 5. Verification Alignment

| Verification | Impact | Notes |
|---|---|---|
| Existing ert suites (35+ files) | regression | Every write-path test must pass; psql error tests, serialisation round-trip tests, grammar sync tests |
| NEW: `dl-satan-db-test.el` | new | Test psql success, psql error, connection failure, variable substitution, `--single-transaction` path |
| NEW: `dl-satan-jsonl-test.el` updates | modified | Add `:null-object` kwarg round-trip test; verify audit/intervention callers produce identical output |
| Grammar sync test | regression | `dl-satan-memory-grammar-test.el` ensures elisp/DB grammar match after refactor |

## 6. Supporting Context

- **Research**: Code review findings 2026-05-31 (16 findings across 56 files). The 8 DRY findings selected for this delta are the highest-leverage: each replaces 2–4 clones with 1 shared implementation.
- **Hypotheses**: N/A — no behavioural hypothesis; this is pure mechanical consolidation.
- **Related Deltas / Specs**: POL-001 (extraction policy — confirms all touched modules stay in broker). DE-001 (attribute render — unrelated).

## 7. Design Decisions & Trade-offs

**DEC-001 — `dl-satan-db-query` signature**
- Decision: `(db host program sql variables)` → `(cons 'ok stdout) | (cons 'error msg)`. Always passes `-q` to psql (quiet mode). Callers pass their preferred host/db/program from their own defcustoms.
- Rationale: All three clones use the same args except `-q` (present in patch-store + attribute, absent in memory-store). Absence of `-q` is a latent bug: psql may emit welcome-banner lines into stdout before the result. Making `-q` unconditional fixes this for all callers. Host/db/program are explicit params because each module has its own defcustom names; the shared fn must be config-call neutral.
- Consequence: `dl-satan-db` is a utility, not a service. It has no state, no connection pooling, no prepared statements. If those are needed later, they grow inside `dl-satan-db`. Memory-store callers get a latent-bug fix (welcome-banner suppression) for free.

**DEC-002 — `dl-satan-jsonl-prepare` as sole prep-value**
- Decision: Route all JSON serialisation through `dl-satan-jsonl-prepare`. Kill the three `--prep-value` / `--prep-plist` clones.
- Rationale: `dl-satan-jsonl-prepare` already handles alists (converts to plists), symbol→string, nil→:null. The clones do not handle alists. The audit/transcript layer already relies on the fuller behaviour.
- Consequence: If any module relied on the clones' *absence* of alist handling (i.e. alists would have crashed `json-serialize`), those callers are now fixed. This is a correctness improvement, not a risk.

**DEC-003 — `slugify` canonical home**
- Decision: `dl-satan-memory-canon--slugify` becomes the shared implementation. `dl-satan-tools-hippocampus` and `dl-satan-tools-org` require `dl-satan-memory-canon` (or a new `dl-satan-string-util` if circular dependency arises).
- Rationale: Memory canon is already loaded by the tools that need slugify. The function is tested via the grammar sync test and the canon purity test. If requiring `dl-satan-memory-canon` from `dl-satan-tools-hippocampus` creates a circular require, extract to a tiny `dl-satan-util` module instead. Current require graph suggests no cycle: `tools-hippocampus` already requires `dl-satan-memory-canon`.
- Consequence: Hippocampus and org tools get the same slugify behaviour as the memory canonicalizer. Edge cases (empty string, all-symbol input) are handled identically across all consumers.

**DEC-004 — `dl-satan-jsonl-read-file` gets `:null-object` kwarg**
- Decision: Add `&key null-object` to the existing `dl-satan-jsonl-read-file`. Default `nil` preserves current behaviour for existing callers. Audit and intervention pass `:null` explicitly.
- Rationale: The only difference between the three JSONL readers is the `:null-object` value passed to `json-parse-string`. A single keyword argument eliminates all three.
- Consequence: `dl-satan-audit--read-jsonl` and `dl-satan-intervention--read-jsonl` become one-liner calls to `dl-satan-jsonl-read-file`.

**DEC-005 — `review-commands` helper location**
- Decision: Extract to a new `dl-satan-patch-common.el` or place in `dl-satan-patch-store.el`. The tools version takes a row and extracts commits from `result_json`; the runner version receives commits externally. The runner version is the more general — accept an optional commits list, defaulting to extraction from the row.
- Rationale: The runner version calls `dl-satan-patch-worktree-changed-files` / `-commits` / `-diffstat` to get commits. The tools version reads from `result_json`. Both produce identical output shape. Unify on the row-based version with an optional `commits` override.
- Consequence: One function, two call sites, zero duplication.

## 8. Open Questions

None. All findings are mechanical and unambiguous. The only design decision with any trade-off is DEC-005 (helper location), which is resolved by preference for the more general signature.

## 9. Rollout & Operational Notes

- **Migration / Backfill**: None. Pure refactoring, no data changes.
- **Observability / Alerts**: No change. psql errors continue to surface through the same `(error . msg)` return path.
- **Recovery / Rollback**: Standard git revert. All changes are confined to function-level refactoring; reverting `dl-satan-db.el` requires restoring the four `--query` clones, which is a straightforward revert of the deletion commits.

## 10. References & Links

- Code review findings: session 2026-05-31 (findings #1–#6, #14)
- `docs/satan/INDEX.md` — SATAN architecture overview
- `docs/satan/memory/design.md` — memory substrate design (grammar authority for slugify)
- POL-001 — extraction policy (confirms all modules stay in broker)
- `docs/satan/refactor/plan.md` — T1 DRY consolidation theme
