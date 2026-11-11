# Review RV-024 — reconciliation of SL-018

Adversarial-review ledger. Structured findings live in the sister
ledger toml; this prose companion carries the reviewer's framing.

## Brief

Mode: **conformance** (self-audit; one agent drives raiser and responder).
Surface reviewed: the primary checkout at `96b9c8a` plus `~/dev/umbriel.el`
at `8d3bb77`. Not dispatched, so no candidate branch.

Lines of attack:

1. **Path conformance.** `doctrine slice conformance 018`: undeclared and
   undelivered cells against the `design-target` selectors.
2. **Gates.** Config `just check` and package `nix develop -c just check`,
   re-run by the auditor; `doctrine slice verify-vt SL-018`;
   `doctrine check gate`.
3. **Design vs code.** Integration file (sec-4), shared helper (DEC-036),
   keymap binds, faces, saved faces, test layout (sec-5).
4. **Rename completeness.** Sweeps for `my/umbriel` / `dl-umbriel-*` in the
   config, the package, and known external callers (compositor config,
   SATAN, flakes, bin dirs), as the seat's autonomy log asked.
5. **Seat path rewrite** (DEC-038 supersedes DEC-033): no stale
   `~/dev/umbriel` path left.
6. **Work after PHASE-04.** Commits `79e5086` (drop `C-c u f`) and `96b9c8a`
   (IMP-033) against the plan and design.
7. **Uncommitted work in other repos** the slice left behind.

Invariants held: no behaviour change except the soft-load warning (scope);
config green at every commit (sec-7); no work email (EX-4); plan criteria are
append-only.

## Synthesis

**Closure story.** SL-018 delivered what it scoped. The umbriel client
lives in `~/dev/umbriel.el` (import `c315b3b`, docs `8d3bb77`, local only,
per DEC-038). The config consumes it through `desktop/dl-umbriel.el` and the
shared `core/dl-checkout.el` helper. Both gates were re-run by the auditor:
config `just check` 362 tests, 0 unexpected, 2 skipped (the two dl-nostr
skips from the baseline); package `just check` 240/240, 5 suites loaded.
Count equality from notes holds: 240 + 362 = 600 baseline + 2 new tests.
Rename sweeps are empty in both repos. No stale `~/dev/umbriel` path is
left from the seat's DEC-038 rewrite. VH-1 passed (user).

**What diverged.** One real divergence (F-1): after VH-1 the user
dropped `C-c u f` (79e5086). The code is right. The plan was settled now by
the user's choice: VT-1 waived with a recorded reason, VT-4 appended. Design
prose has drifted in five small places (F-2), and one selector duplicates a
glob (F-3). Reconcile fixes both.

**Standing risks.**
- Two writes outside this repo are uncommitted and depend on the user (F-5):
  `~/.config/umbriel/app_support.toml` (the scratchpad spawn now calls
  `umbriel`) and satan:ISS-068. Until the compositor config is committed,
  a reset there would bring back the dead `my/umbriel` call.
- Hosts without the checkout get a warning and no umbriel (design sec-9, by
  design). The soft-load test covers it.
- The `.elc` files in the package checkout (09:20, daemon restart) come from
  `dl-checkout-compile-stale` and are gitignored. Expected, not a leak.

**Tradeoffs accepted.** Record edits (DEC-037) show as undeclared in
conformance by design (F-4). Dated history in the compositor's notes keeps
the old names (F-5). `doctrine check gate` stays unwired until CHR-008 (F-6).

**For the human.** The integration path is `init.el` → `desktop/dl-umbriel.el`
→ `locate-library "umbriel-buffer"` → either `display-warning` or
`dl-checkout-compile-stale` + `use-package`. `test/dl-umbriel-keys-test.el`
tests both branches in fresh subprocesses (smoke and soft-load). Its
subprocesses bind `byte-compile-current-file`, so `just check` writes no
`.elc` into the checkout. Sources: `doctrine show DEC-038` (repo/remote),
`doctrine show DEC-036` (shared helper), `doctrine show DEC-024` (the
`C-c u` map, now without `f`).

## Reconciliation Brief

### Per-slice (direct edit)
- F-2, design.md sec-1 diagram: `dev/umbriel-test.el` → `dev/umbriel-test-runner.el`.
- F-2, design.md sec-2: "beside the 17 faces" → 16.
- F-2 / F-1, design.md sec-4: drop `umbriel-focus-frame` from the
  `keys/dl-keymap.el ─binds─▶` diagram line and the keymap bullet. Add a note
  that `C-c u f` was dropped after VH-1 (79e5086, DEC-024). `umbriel-focus-frame`
  stays on `server-switch-hook` and `M-x`.
- F-2, design.md sec-5 count check: new tests are dl-checkout's 5, the smoke
  test and the soft-load test.
- F-2, design.md sec-7 last bullet: cite DEC-038, not DEC-033.
- F-3, selector registry: `doctrine slice selector rm SL-018
  test/dl-umbriel-keys-test.el`. The `test/dl-umbriel*-test.el` glob still
  covers it. No design.md sec-6 prose change is needed: sec-6 lists the file
  as new, which is still true.

### Governance/spec (REV)
- None. No ADR, policy, standard or spec governs this slice (POL-001 checked,
  not applicable). DEC-024 was already updated in 79e5086.
