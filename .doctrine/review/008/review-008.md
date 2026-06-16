# Review RV-008 — phase-plan of SL-007

Adversarial-review ledger (ADR-007).

## Brief

DE-007 Phase 4 verification.

## Audit Content (migrated from spec-driver)

```yaml supekku:audit.findings@v1
schema: supekku.audit.findings
version: 1
audit: AUD-008
findings:
  - id: F-001
    description: >-
      MAJOR (correctness — DEC-8 prerequisite vacuous, again). The
      scheduled-run -> refuse-session direction of DEC-8 mutual exclusion is
      still effectively a no-op. `broker--spawn` sets
      `dl-satan-broker--spawn-running` to t, then runs an `unwind-protect`
      whose BODY launches the jailed child via async `make-process`
      (dl-satan-broker.el:843) and returns the run-id immediately. The
      unwind-protect cleanup then clears the flag at synchronous return — i.e.
      at LAUNCH time, not at child completion. So the flag is truthy only
      during the brief synchronous pre-spawn assembly window and is nil for the
      entire live duration of the actual run. `mint-session` and
      `my/satan-mcp-start` both gate on `dl-satan-broker--spawn-running`
      (dl-satan-mcp.el:165,452), so a session can be minted freely while a
      scheduled child is genuinely live — exactly the latent defect F6/R11 that
      Phase 4 was chartered to fix. The in-code comments assert a
      "synchronous path" cleared by unwind-protect and an "async path" cleared
      by the sentinel; there is no synchronous path — make-process is always
      async — so the unwind-protect clear unconditionally defeats the
      sentinel's purpose.
    outcome: drift
    severity: high
    refs:
      - satan/dl-satan-broker.el:700
      - satan/dl-satan-broker.el:843
      - satan/dl-satan-broker.el:880
      - satan/dl-satan-mcp.el:165
    disposition:
      status: reconciled
      kind: follow_up_delta
    rationale: >-
      RECONCILED in-delta (commit ed9067e). Replaced the unwind-protect with a
      condition-case that clears the flag ONLY on synchronous spawn failure;
      the child sentinel clears it on exit. Also broadened the sentinel regex
      to match "killed"/"deleted" — `delete-process` emits "killed\n" (verified
      empirically), which the old regex missed, so timeout/kill paths never
      finalised or cleared the flag. Producer test
      `dl-satan-broker/dec8-spawn-running-persists-until-sentinel` now asserts
      the flag stays t after spawn returns (live child) and clears on the
      killed sentinel; `dec8-sentinel-clears-flag-on-exit-events` covers all
      terminal events.
  - id: F-002
    description: >-
      MAJOR (correctness — boot-context cache is dead code). In
      `dl-satan-mcp-tool/boot-context` the cache fast-path
      `(when (and cached (not refresh)) (cons 'ok cached))` computes its
      value and DISCARDS it — there is no early return — so control always
      falls through to rebuild the capsule and overwrite the cache. The
      per-session `boot-cache` slot is therefore never served, defeating the
      DEC-13 boot-latency mitigation (DR-007 §9). Every `satan_boot_context`
      call re-runs full assembly (percept/resonance/motive build).
    outcome: drift
    severity: high
    refs:
      - satan/dl-satan-mcp.el:351
    disposition:
      status: reconciled
      kind: follow_up_delta
    rationale: >-
      RECONCILED in-delta (commit ed9067e). Restructured to a real
      `if`/early-return that serves `(cons 'ok cached)`. Test
      `dl-satan-mcp/boot-context-caches-per-session` stubs the builder with a
      call counter and asserts the second no-refresh call serves the cache
      (counter unchanged) while `:refresh` forces a rebuild.
  - id: F-003
    description: >-
      MAJOR (DRY / dead code — CLAUDE.md "no parallel implementation").
      `dl-satan-context-interactive` (dl-satan-context.el:574) is registered as
      the interactive mode's `:context-fn`, but the interactive mode is
      `:harness nil` and is never spawned; the only caller of `:context-fn` is
      `broker--spawn`. So `dl-satan-context-interactive` is dead. Meanwhile the
      live boot path, `dl-satan-mcp-tool/boot-context`, reimplements that exact
      logic inline (fresh time_now -> assemble-context -> finalize-prompt with
      assembled=""). Two parallel implementations of one behaviour; the live one
      bypasses the registered one.
    outcome: drift
    severity: medium
    refs:
      - satan/dl-satan-context.el:574
      - satan/dl-satan-mcp.el:355
      - satan/dl-satan-mcp.el:100
    disposition:
      status: reconciled
      kind: follow_up_delta
    rationale: >-
      RECONCILED in-delta (commit ed9067e). `boot-context` now delegates to
      `dl-satan-context-interactive`, which is the single source of the capsule
      (the graceful-degrade condition-case moved into it). The inline
      reimplementation is gone; `:context-fn` registration retained so the
      builder remains the canonical entry point.
  - id: F-004
    description: >-
      MINOR (correctness — destructive mutation of session prepare). Both
      `dl-satan-context-interactive` and `boot-context` do
      `(plist-put prepare :time_now <fresh>)` on the session's stored prepare
      plist. `:time_now` already exists, so plist-put mutates it in place — the
      session's frozen `time_now` (allocated once at mint for run_id/audit
      coherence) is clobbered with wall-clock on every boot-context call, and
      assemble-context further injects :percept/:resonance/etc into the shared
      session struct as a side effect. The fresh time is wanted only for the
      `# Now` block (F3); it should not overwrite the session-frozen value.
    outcome: drift
    severity: medium
    refs:
      - satan/dl-satan-mcp.el:357
      - satan/dl-satan-context.el:588
    disposition:
      status: reconciled
      kind: follow_up_delta
    rationale: >-
      RECONCILED in-delta (commit ed9067e). `dl-satan-context-interactive` now
      `(plist-put (copy-sequence run-ctx) :time_now ...)`, so the caller's
      frozen time_now and the session struct are untouched. Test
      `dl-satan-context/interactive-does-not-mutate-run-ctx` asserts the
      original run-ctx keeps its frozen time_now and gains no assembly keys.
  - id: F-005
    description: >-
      MAJOR (verification gap). The three new DEC-8 tests only exercise the
      CONSUMER with a manually-set flag: `dec8-session-refuses-when-spawn-running`
      and `dec8-startup-refuses-when-spawn-running` both `(setq
      dl-satan-broker--spawn-running t)` by hand, and `dec8-flag-cleared-on-
      disconnect` covers only the session-active (other) direction. Nothing
      asserts that the PRODUCER (`broker--spawn`) keeps `--spawn-running` set
      across a live run — which is precisely why F-001 ships green. Separately,
      the boot-context build, the per-session cache (F-002), and the
      graceful-degrade branch have NO tests despite the Phase-4 plan listing
      VT-mcp-boot-context-{render,suppress,sideeffects,degraded}; the degraded
      branch also leaves :motive/:sensor_status/:evidence unset on the partial
      prepare, untested against the renderer.
    outcome: drift
    severity: medium
    refs:
      - satan/test/dl-satan-mcp-test.el:461
      - satan/test/dl-satan-mcp-test.el:481
      - satan/dl-satan-mcp.el:362
    disposition:
      status: reconciled
      kind: follow_up_delta
    rationale: >-
      RECONCILED in-delta (commit ed9067e). Added a producer test for F-001
      (flag persists across spawn, clears on killed), a sentinel exit-event
      test, a boot-context per-session cache test (F-002), and
      context-interactive non-mutation (F-004) + graceful-degrade tests. The
      degrade test drives the REAL renderer with a partial prepare and asserts
      a coherent capsule string — confirming the renderer tolerates nil
      percept/sensor_status. +5 tests; suite 976 -> 981, all green.
  - id: F-006
    description: >-
      MAJOR (repo hygiene / commit gate). Commit 3ff23c8 ("extract
      dl-satan-run-assemble-context") tracked ~45 build/editor artefacts that
      must never be committed: `result` (a Nix build symlink), the entire
      `.direnv/` tree (flake-inputs, profile, nix-direnv-reload), `.cache/`
      (gptel + svg-lib + treemacs-persist), and `.envrc`. This pollutes the
      tree, breaks Nix flake purity, and indicates a `git add -A`/`git add .`
      that ignored .gitignore scope. Separately, `just check` (the AGENTS.md
      commit gate) is RED: dl-satan-bough/{active-scope-shape,
      day-not-found-becomes-ok-nil,week-scope-bounds} fail because bough-read
      returns `(error . ...)` from the DB layer. bough is not in DE-007's diff
      scope, so these are pre-existing/environment (postgres) failures, not a
      DE-007 regression — but a red gate blocks delta closure regardless.
    outcome: drift
    severity: high
    refs:
      - result
      - .direnv/
      - .cache/
      - .envrc
      - satan/test/dl-satan-tools-bough-test.el:251
    disposition:
      status: reconciled
      kind: follow_up_delta
    rationale: >-
      Artefact leak RECONCILED in-delta (commit c2b106d): `git rm -r --cached
      result .direnv .cache .envrc` (48 files), kept on disk, now re-ignored by
      ~/.gitignore_global. Root cause: a dispatch worker's `git add -A` in an
      isolated worktree that did not honour core.excludesfile — recurring
      footgun for worktree workers. Note: junk remains in history at 3ff23c8;
      full purge would need a history rewrite (out of scope unless required).
      The bough gate failures are NOT env/postgres as first thought: the
      installed `~/.cargo/bin/bough` (v0.1.0) has no `read` subcommand
      (`error: unrecognized subcommand 'read'`) — a stale binary lagging its
      Rust source. Out of DE-007 scope (bough untouched since DE-006 956af18);
      filed as ISSUE-005 (rebuild the binary). `just check` must be green
      before close — that is the ISSUE-005 owner's action, not a DE-007 code
      fix.
    drift_refs:
      - ISSUE-005
findings_summary:
  total: 6
  by_outcome:
    drift: 6
  unresolved: 0
  reconciled: 6
```

## Observations

- User reported "DE-007 implementation complete", but spec-driver shows the
  delta in-progress (IP-007 P02 6/14, P03 4/19) and the recent work is a
  separately-tracked "Phase 4" not yet represented as a phase sheet. State is
  not closure-ready independent of the findings below.
- Phase 4 charter (notes.md) was explicitly to FIX the vacuous DEC-8 guard
  (R11). F-001 shows the fix is itself ineffective — the unwind-protect clears
  the producer flag at async launch.
- Two of the highest-severity defects (F-001 producer flag, F-002 dead cache)
  are invisible to the current suite (F-005), so the green DEC-8 tests give
  false confidence.

## Evidence

- Commit range reviewed: eb0f044..d4434c3 (Phase 4), core files
  dl-satan-broker.el (+73), dl-satan-context.el (+68), dl-satan-mcp.el (+140),
  dl-satan-tools-content.el (+12), tests (+113).
- `just check`: 967/976 expected, 3 unexpected (dl-satan-bough/*), 6 skipped —
  gate RED.
- `make-process` async confirmed at dl-satan-broker.el:843; handler return
  contract `(eq (car-safe res) 'ok)` confirmed at dl-satan-tools.el:181.
- args-schema double-paren fix (d4434c3) and the filter domain/url guard
  (tools-content.el) are correct; the latter is DE-005 reconciliation already
  recorded under AUD-007 F-002 — out of AUD-008 scope.

## Resolution (post-fix)

- All six findings reconciled in-delta. Code fixes for F-001..F-005 in commit
  ed9067e; artefact leak (F-006) in c2b106d. +5 tests, full suite 976 -> 981,
  zero regressions.
- The only remaining `just check` failures are the three `dl-satan-bough/*`
  tests, root-caused to a stale `bough` binary missing the `read` subcommand
  (ISSUE-005) — a separate subsystem, not DE-007 code.

## Recommendations

- DE-007's own Phase-4 work is now audit-clean and verified.
- Do NOT hand off to /close-change yet: the AGENTS.md commit gate (`just
  check`) is still RED on ISSUE-005 (stale bough binary). Closure is blocked on
  rebuilding that binary, which is the ISSUE-005 owner's action — not a DE-007
  code change. Re-run `just check` after ISSUE-005 is resolved, then close.
