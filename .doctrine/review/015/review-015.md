# Review RV-015 — reconciliation of SL-014

Adversarial-review ledger (ADR-007). Structured findings live in the sister
ledger toml; this prose companion carries the reviewer's framing.

## Brief

<!-- Pre-reading + lines of attack: what this review is probing, the invariants
     it must hold the subject to, and where the bodies are likely buried. Seeded
     at `review new`; the reviewer fills it before raising findings. -->

Conformance audit of SL-014 (commits `71deb8c`, `4d8fb12`, `8b6984f`) against
`design.md` (rules R1–R5, D1–D5, static lint, migration, verification).

Lines of attack:

- Rules hold in the tree: no forbidden form (R2) outside R3 exemptions; no
  (map, key) written twice (R4). Evidence: `l2-real-config` /
  `l3-real-config` gates, `rg` for `global-set-key` & co.
- Lint coverage matches design § Verification (records, violations,
  duplicates, L1 naming, gates).
- Migration table and collision resolutions match what shipped; live keys
  resolve as designed (PHASE-02 VA-1 batch init, VH-1 user smoke test).
- Docs (EX-1..3 of PHASE-03): KEYS.md states R1–R5 and where each lint runs;
  no stale line on changed keys.
- Design-of-record drift: anything shipped that `design.md` does not say.


## Synthesis

SL-014 conforms to its design. Rules R1–R5 hold in the tree: the
`l2-real-config` and `l3-real-config` gates are green with an empty
duplicate allow-list, and `rg` finds no `global-set-key` / `keymap-global-set`
/ `global-unset-key` / `local-set-key` outside a commented line in
`core/dl-theme.el`. The three collisions (`C-:`, ``C-M-` ``, `C-z`) were
resolved as the user decided; `C-<f1>` is `popterm-toggle`. Live behaviour
was checked by a full batch init (PHASE-02 VA-1, 37 key spot checks) and a
user smoke test (VH-1). `just check` 166/166. Docs (PHASE-03) state the
rules and where each lint runs.

Drift is in the design record only (F-1): three migration rows resolved
differently per site, as § Risks allowed. ERT names differ from the design's
illustrative list (F-2, tolerated). VA-1 surfaced pre-existing KEYS.md
staleness outside the slice's keys, fixed in place (F-3).

Standing risks:

- L2/L3 see only literal maps and keys. A computed write (e.g. a `dolist`
  over keys) escapes both lints; none exists today.
- L1 runs on the live keymap; foreign packages that grab `C-c <letter>`
  after startup are caught only by `M-x my-policy-lint`.
- Mode-owned `C-c` ranges and per-mode shadowing are unpoliced (IMP-019).

Accepted tradeoffs: `crux` is now deferred (its remaps resolve to
autoloads); `meow-*-define-key` stays unlinted (R3).

## Reconciliation Brief

### Per-slice (direct edit)

- F-1 → `design.md` § Migration: embark's `org-mode-map` `C-,` is
  `bind-keys :map` inside `with-eval-after-load 'org` (not `:bind` — a
  `:bind` on `use-package org` would defer org); eshell `C-r` binds on
  `use-package esh-mode :ensure nil` (the map's defining feature) and
  `my/setup-eshell` is deleted; `org/dl-org-links.el` is deleted (it held
  only `C-c l`; `init.el` require and `docs/NOTES.md` line removed).
  Design is a managed run — edit through `doctrine design`, not by hand.
- F-2 (optional, tolerated) → `design.md` § Verification: test names may be
  aligned to `dl-policy-lint/records-*`, `l2-*`, `l3-*` if § Verification is
  touched anyway.

### Governance/spec (REV)

- None. No ADR, policy, standard or spec governs key ownership; the rules
  live in `docs/KEYS.md`.

## Reconciliation Outcome

### Direct edits applied
- `design.md` § Migration (sec-6): org row notes `dl-org-links.el` deleted;
  the combined vertico/embark/eshell row split into three rows stating the
  shipped bind sites (embark via `bind-keys :map` in
  `with-eval-after-load 'org`; eshell on `use-package esh-mode`,
  `my/setup-eshell` deleted). Covers RV-015 F-1. User-approved.

### REVs completed
- None — no governance/spec items.

### Withdrawn / tolerated
- RV-015 F-2: tolerated — ERT names in § Verification are illustrative;
  every designed case has a shipped counterpart. No edit.
- RV-015 F-3: fixed in `8b6984f` during audit; no reconcile write.

Reconcile pass complete — handoff to /close.
