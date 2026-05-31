---
id: IP-003-P01
slug: "003-consolidate_satan_dry_violations_shared_db_prep_value_slugify_jsonl-phase-01"
name: Extract shared infrastructure, kill DRY clones
created: "2026-05-31"
updated: "2026-05-31"
status: draft
kind: phase
plan: IP-003
delta: DE-003
---

# Phase 01 — Extract shared infrastructure, kill DRY clones

## 1. Objective

Create `dl-satan-db.el`, then sequentially kill each DRY clone — rerouting callers to the shared implementation. Each step is a commit; each step's tests gate the next. Zero behavioural change.

## 2. Links & References

- **Delta**: [DE-003](../DE-003.md)
- **Design Revision**: [DR-003](../DR-003.md) — DEC-001 through DEC-005
- **Specs / PRODs**: None
- **Support Docs**: `docs/satan/memory/design.md` §3.1 (slugify authority)

## 3. Entrance Criteria

- [ ] DR-003 design decisions recorded and approved
- [ ] IP-003 drafted
- [ ] Working directory clean — no uncommitted changes in `satan/`

## 4. Exit Criteria / Done When

- [ ] `dl-satan-db.el` exists with `dl-satan-db-query(db host program sql vars)` and test suite
- [ ] `dl-satan-memory-store.el` — `--query` deleted, calls `dl-satan-db-query`
- [ ] `dl-satan-patch-store.el` — `--query` deleted, calls `dl-satan-db-query`
- [ ] `dl-satan-attribute.el` — `--query` deleted, calls `dl-satan-db-query`
- [ ] `dl-satan-memory-store.el` — `--prep-value`/`--prep-plist` deleted, calls `dl-satan-jsonl-prepare`
- [ ] `dl-satan-patch-store.el` — `--prep-value` deleted, calls `dl-satan-jsonl-prepare`
- [ ] `dl-satan-attribute.el` — `--prep-value` deleted, calls `dl-satan-jsonl-prepare`
- [ ] `dl-satan-tools-hippocampus.el` — `--slugify` deleted, calls `dl-satan-memory-canon--slugify`
- [ ] `dl-satan-tools-org.el` — `--slugify` deleted if present, calls `dl-satan-memory-canon--slugify`
- [ ] `dl-satan-memory-store.el` — `--parse-pg-array` deleted, uses shared fn
- [ ] `dl-satan-jsonl.el` — `dl-satan-jsonl-read-file` gains `:null-object` kwarg
- [ ] `dl-satan-audit.el` — `--read-jsonl` deleted, calls `dl-satan-jsonl-read-file`
- [ ] `dl-satan-intervention.el` — `--read-jsonl` deleted, calls `dl-satan-jsonl-read-file`
- [ ] Shared `dl-satan-patch--build-review-commands` exists
- [ ] `dl-satan-tools-patch.el` — `--review-commands` deleted, calls shared fn
- [ ] `dl-satan-patch-runner.el` — `--review-commands` deleted, calls shared fn
- [ ] Full ert suite passes with zero regressions
- [ ] Zero byte-compiler warnings in all touched files

## 5. Verification

- **Tests to run**: `emacs --batch -L . -L satan -l satan/test/dl-satan-db-test.el -f ert-run-tests-batch-and-exit` (new); then full `satan/test/*.el` suite
- **Lint**: `emacs --batch -L . -L satan --eval '(setq byte-compile-error-on-warn t)' -f batch-byte-compile satan/dl-satan-db.el satan/dl-satan-memory-store.el satan/dl-satan-patch-store.el satan/dl-satan-attribute.el satan/dl-satan-intervention.el satan/dl-satan-audit.el satan/dl-satan-jsonl.el satan/dl-satan-tools-patch.el satan/dl-satan-patch-runner.el satan/dl-satan-tools-hippocampus.el satan/dl-satan-tools-org.el`
- **Evidence**: commit hashes for each step; ert output showing zero failures

## 6. Assumptions & STOP Conditions

- **Assumptions**: `dl-satan-jsonl-prepare` handles all data shapes the three `--prep-value` clones receive (plists only — no alists in the DB serialisation paths). `dl-satan-tools-hippocampus` already requires `dl-satan-memory-canon` (no circular import).
- **STOP when**: Any existing test fails after a step. Revert that step, diagnose, update DR if needed.

## 7. Tasks & Progress

_(Status: `[ ]` todo, `[WIP]`, `[x]` done, `[blocked]`)_

| Status | ID | Description | Parallel? | Notes |
|--------|----|-------------|-----------|-------|
| [ ] | 1.1 | Create `dl-satan-db.el` + test suite | — | Shared psql runner with `-q` |
| [ ] | 1.2 | Switch memory-store `--query` → `dl-satan-db-query` | — | Latent `-q` bug fix here |
| [ ] | 1.3 | Switch patch-store `--query` → `dl-satan-db-query` | — | |
| [ ] | 1.4 | Switch attribute `--query` → `dl-satan-db-query` | — | |
| [ ] | 1.5 | Switch `memory-migrate--psql` → `dl-satan-db` (with extra-flags) | — | `--single-transaction` passthrough |
| [ ] | 2.1 | Kill memory-store `--prep-value`/`--prep-plist` → `dl-satan-jsonl-prepare` | — | |
| [ ] | 2.2 | Kill patch-store `--prep-value` → `dl-satan-jsonl-prepare` | — | |
| [ ] | 2.3 | Kill attribute `--prep-value` → `dl-satan-jsonl-prepare` | — | |
| [ ] | 3.1 | Kill `--slugify` in tools-hippocampus → `dl-satan-memory-canon--slugify` | — | |
| [ ] | 3.2 | Kill `--slugify` in tools-org (if present) → `dl-satan-memory-canon--slugify` | — | |
| [ ] | 4.1 | Unify `parse-pg-array` — intervention's version wins, memory-store switches | — | Better double-quote handling |
| [ ] | 5.1 | Add `:null-object` kwarg to `dl-satan-jsonl-read-file` | — | |
| [ ] | 5.2 | Kill `--read-jsonl` in audit → `dl-satan-jsonl-read-file` | — | |
| [ ] | 5.3 | Kill `--read-jsonl` in intervention → `dl-satan-jsonl-read-file` | — | |
| [ ] | 6.1 | Extract `dl-satan-patch--build-review-commands(row)` | — | Generalised from runner version |
| [ ] | 6.2 | Switch tools-patch and patch-runner → shared fn | — | |
| [ ] | 7.1 | Full ert suite run + byte-compile lint | — | Final gate |

### Task Details

#### 1.1 — Create `dl-satan-db.el`
- **Design / Approach**: New file in `satan/`. Exports `dl-satan-db-query(db host program sql variables)`. Always passes `-q`, `-X`, `-A`, `-t`, `-F "\t"`, `ON_ERROR_STOP=1`. Returns `(ok . stdout)` or `(error . msg)`. Defcustoms for default host/db/program. Also exports `dl-satan-db-psql(db host program extra-flags sql)` for callers that need custom flags (`memory-migrate`'s `--single-transaction`).
- **Files / Components**: NEW `satan/dl-satan-db.el`, NEW `satan/test/dl-satan-db-test.el`
- **Testing**: psql success (valid SQL with variable substitution), psql error (syntax error SQL), connection failure (bad host), `--single-transaction` passthrough. Uses a test DB or mocks psql.
- **Observations & AI Notes**: The `memory-migrate--psql` function is slightly different — it takes an `extra-flags` list and doesn't do `-v` variable substitution. It needs its own wrapper or a flag-passthrough variant.
- **Commits / References**: `feat(DE-003): add shared dl-satan-db.el psql runner`

#### 1.2–1.4 — Switch `--query` callers
- **Design / Approach**: Replace `(dl-satan-memory-store--query db sql vars)` with `(dl-satan-db-query db dl-satan-memory-store-host dl-satan-memory-store-psql-program sql vars)`. Delete the private `--query` function. Run module's test suite.
- **Files / Components**: `dl-satan-memory-store.el`, `dl-satan-patch-store.el`, `dl-satan-attribute.el`
- **Testing**: Existing test suites for each module. No new tests needed.
- **Observations**: Memory-store currently lacks `-q`; this commit fixes that latent bug. The `string-trim` on stdout already strips banner noise, but `-q` makes it deterministic.

#### 2.1–2.3 — Kill `--prep-value` clones
- **Design / Approach**: Replace `(dl-satan-memory-store--prep-value v)` with `(dl-satan-jsonl-prepare v)`. Delete `--prep-value` and `--prep-plist`. All callers pass plists (no alists) — verify before deleting.
- **Files / Components**: `dl-satan-memory-store.el`, `dl-satan-patch-store.el`, `dl-satan-attribute.el`
- **Testing**: Each module's ert suite covers JSON serialisation round-trips. No change to output.

#### 3.1–3.2 — Unify slugify
- **Design / Approach**: `tools-hippocampus` already requires `memory-canon`. Replace `dl-satan-tools-hippocampus--slugify` with `dl-satan-memory-canon--slugify`. Both use identical regex.
- **Files / Components**: `dl-satan-tools-hippocampus.el`, `dl-satan-tools-org.el`
- **Testing**: Grammar sync test ensures slugify consistency. Hippocampus write tests exercise slugify indirectly.

#### 4.1 — Unify parse-pg-array
- **Design / Approach**: `dl-satan-intervention--parse-pg-array-text` has better double-quote handling. Move to shared location, reroute `dl-satan-memory-store--parse-pg-array` callers.
- **Files / Components**: `dl-satan-memory-store.el`, `dl-satan-intervention.el`, possibly new `dl-satan-db.el` (or `dl-satan-util.el`)
- **Testing**: Memory-store resonate tests; intervention lookup tests. Both parse `{a,b,c}` arrays.

#### 5.1–5.3 — Unify JSONL reading
- **Design / Approach**: Add `&key null-object` to `dl-satan-jsonl-read-file`. Default `nil` preserves existing callers. Audit and intervention pass `:null-object :null`.
- **Files / Components**: `dl-satan-jsonl.el`, `dl-satan-audit.el`, `dl-satan-intervention.el`
- **Testing**: `dl-satan-jsonl-test.el` — add round-trip test with `:null-object :null`. Audit and intervention tests verify identical output.

#### 6.1–6.2 — Extract shared review-commands
- **Design / Approach**: The runner version is more general (accepts optional commits override). Extract to `dl-satan-patch-common.el` or `dl-satan-patch-store.el`. Both callers switch.
- **Files / Components**: `dl-satan-tools-patch.el`, `dl-satan-patch-runner.el`, NEW or modified `dl-satan-patch-store.el`
- **Testing**: Tools-patch tests (result shape); runner tests (result_json assembly).

#### 7.1 — Final gate
- **Design / Approach**: Run full `satan/test/*.el` suite. Byte-compile all touched files with `error-on-warn`. Verify zero failures, zero warnings.
- **Testing**: `emacs --batch -L . -L satan -l satan/test/dl-satan-db-test.el -f ert-run-tests-batch-and-exit` for new; then full suite.

## 8. Risks & Mitigations

| Risk | Mitigation | Status |
|------|------------|--------|
| R1: psql error semantics differ between `-q` and no `-q` | `-q` only suppresses welcome banner; error output is on stderr, unaffected | — |
| R2: `dl-satan-jsonl-prepare` alist→plist conversion changes DB insert shape | All three callers only serialise plists (never alists). Verify with grep before killing. | — |
| R3: `dl-satan-memory-migrate--psql` shape differs too much from `--query` | Give it a separate wrapper `dl-satan-db-psql` that takes `extra-flags` list. | — |

## 9. Decisions & Outcomes

- `2026-05-31` — DEC-001 vs DEC-001 revised: `-q` always-on (adversarial review finding). Fixes latent memory-store banner bug.

## 10. Findings / Research Notes

- Adversarial review of DR-003 (2026-05-31) found: memory-store `--query` lacks `-q` flag. Patch-store and attribute have it. Shared `dl-satan-db-query` always passes `-q`, fixing the memory-store latent bug.

## 11. Wrap-up Checklist

- [ ] Exit criteria satisfied (all 17 items checked)
- [ ] Verification evidence stored (ert output, lint output)
- [ ] Spec/Delta/Plan updated with lessons
- [ ] Hand-off notes to next phase: N/A (single phase)
