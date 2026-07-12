# Review RV-013 — reconciliation of SL-013

Adversarial-review ledger (ADR-007). Structured findings live in the sister
ledger toml; this prose companion carries the reviewer's framing.

## Brief

**Subject:** SL-013 (note-system revival) — subtree promotion command +
review-view gap-fill. Phases 3/3 implemented; lifecycle divergent (started,
not terminal). Facet: `reconciliation`. Self-audit (reviewer == author).

**Surface reviewed:** the working tree on `main` (non-dispatched slice; no
candidate branch). Selectors: `dl-denote-promote{,-test}.el`, `dl-review{,-test}.el`,
`dl-notes-paths.el`, `dl-org-capture.el`, `dl-keymap.el`, `init.el`.

**Invariants held to:**
- INV-1 promote never loses content (subtree → exactly one new note + stub link).
- INV-2 new note lands inside `dl-notes-root` so `denote:` links resolve.
- Design conformance: shipped behaviour matches `design.md` §5, D-decisions,
  and each phase's `EX-`/`VT-` criteria in `plan.toml`.
- Zero-warning byte-compile; paren gate clean; `just check` green.

**Evidence gathered (this audit):**
- ERT batch (the real VT channel): 9/9 green — 7 promote suite (incl. e2e
  create-note-and-stub, quit-untouched) + 2 review suite (journal-open keyword
  selection, recent-note ordering/cap). Matches notes' 7/7 + 2/2.
- `just check`: `PASS 0/0` — **vacuous** (org suites off `dl-test-suite-dirs`;
  ISS-007). Gate green but carries no SL-013 signal → F-2.
- Byte-compile `error-on-warn`: new `dl-denote-promote.el` clean. Two warnings
  from isolated `-Q` compile of `dl-review.el:232` / `dl-org-capture.el:34` are
  pre-existing free-vars (`my/org-agenda-work-files`, `org-capture-templates`,
  blame `04f77ba` / `56a7643e`, May) exposed only by the missing require chain —
  NOT SL-013; clean under real init + compile-angel (notes concur).
- VA-1 sweep: sole `"protocol.org"` literal is the `dl-notes-protocol-file`
  defconst (its rightful home); the one sibling ref is a docstring in
  `my/review-protocol` mirroring `my/review-inbox`. No code-path literal escapes
  `dl-notes-paths.el`. Satisfied.
- Bindings present: `C-c n p` (promote), `C-c n v {j,p,n}` personal,
  `C-c n W v {j,n}` work — all with which-key labels.

**Lines of attack / suspected divergences:**
1. Design §5.2 authored `my/review--journal-files` as returning *dirs*; shipped
   returns concrete `.org` files (`org-ql-select` does not expand dirs). Code
   right, design prose stale → F-1.
2. Verification basis: the required `just check` gate is vacuous; all VT signal
   came from the batch runner, not the gate → F-2 (ISS-007).
3. Two human VH gates (PHASE-02 promote live e2e; PHASE-03 views live e2e)
   remain OPEN — recorded as pending, not passed. Carried in Synthesis + brief.
4. Out-of-scope, left untouched: pre-existing red
   `dl-denote-journal/personal-daily-nav` (jail path vs hardcoded `~/notes`);
   PHASE-01 nixpkgs neofetch→fastfetch swap (unrelated breakage). Synthesis only.

## Synthesis

**Overall: solid.** SL-013 does what it set out to do — the note corpus is no
longer write-only. Promotion is one keystroke (`C-c n p`) that wraps upstream
`denote-org-extract-org-subtree` rather than reimplementing it (D1), leaves a
level-preserving provenance stub (D3), and aborts cleanly on quit. The review
surfaces (`journal-open`, `protocol`, `recent-notes` + work mirrors) extend the
existing `dl-review.el` rather than spawning a parallel module (D5), and the
duplicated `protocol.org` literal is collapsed to a single defconst. The diff is
small, cohesive, and DRY: the `my/review--org-files-in` seam feeds both the
journal-open and recent-notes paths. INV-1/INV-2 hold — the e2e test proves the
subtree ends up in exactly one place with a resolving `denote:` link.

**Verification stands, but on the batch runner, not the gate.** The nine ERT
assertions are real and green, and they cover the load-bearing behaviour
(promote e2e + quit-safety; journal keyword selection; recent ordering/cap).
The honest caveat (F-2): the required `just check` gate is vacuous — it proves
nothing about SL-013 because the org suites live outside `dl-test-suite-dirs`.
Every phase's EX-4 ("just check green") was satisfied only in the vacuous sense.
This is pre-existing infra debt (ISS-007), not an SL-013 regression, and the
work was independently verified — but the gate's blindness is a standing risk
worth stating plainly.

**One authored-vs-shipped drift (F-1), design's fault not the code's.** The
design assumed `org-ql` would expand directories; it does not for `org-ql-select`.
The implementation is correct; the design prose is stale and gets a one-line
reconcile edit.

**Standing risks / consciously accepted:**
- VH gates OPEN (see below) — the two live-emacs e2e passes are the only
  verification a batch run cannot give; they gate a clean /close, not this audit.
- Curated promote targets widened to 10 dirs (5 personal + 5 work) vs the
  user-approved "5 personal" — self-flagged RN-4, justified by scope's "work
  parity where it falls out free," design-confirmed. Aligned, no finding.
- `protocol.org` plain captures are drained by `my/review-protocol` (open+triage),
  not the stale-WAITING report — the honest limit named in §5.1/RN-3.
- Pre-existing red `dl-denote-journal/personal-daily-nav` (jail-path vs hardcoded
  `~/notes`) left untouched — out of scope; filed as a backlog issue in harvest.

**Haiku:**

    Write-only no more —
    one keystroke buries the note,
    a stub marks the grave.

## Outstanding VH gates (PENDING — record, not passed)

Two human live-emacs gates remain OPEN. The audit records them as pending; they
gate a clean `/close`, not the audit→reconcile move. Steps in
`.doctrine/slice/013/notes.md`:

- **VH-1 PHASE-02** — promote a real journal subtree live; assert new note in
  chosen dir, level-preserving stub, `C-c n b` backlink resolves; `C-g` on
  another subtree leaves it untouched. **Requires `home-manager switch`** first
  (new required file `dl-denote-promote.el` + init require).
- **VH-1 PHASE-03** — exercise `C-c n v {j,p,n}` + `C-c n W v {j,n}`; each view
  surfaces a known item; which-key labels read sensibly. **No rebuild** —
  `eval-buffer` the four edited files (edits are to already-loaded `.el`).

## Reconciliation Brief

### Per-slice (direct edit)
- **design.md §5.2 (and §5.1 interface table entry for `my/review--journal-files`)**
  [F-1]: change the documented return from "journal + weekly *dirs*" to "concrete
  `.org` files under those dirs (via `my/review--org-files-in`)". Rationale:
  `org-ql-select` does not expand directories; the shared seam must return files.
  The code is canonical; align the prose to it.

### Governance/spec (REV)
- None. No ADR, policy, standard, or spec is contradicted by the shipped work.

### Deferred to /close (not reconcile writes)
- Two VH gates above must be executed before a clean close; reconcile does not
  write them.
- F-2 (vacuous `just check`) is tolerated and tracked in ISS-007 — no reconcile
  write; a note only.

## Reconciliation Outcome

### Direct edits applied
- **design.md §5.2** (RV-013 F-1): interface comment for `my/review--journal-files`
  changed from "journal + weekly dirs" to "concrete `.org` FILES (via
  `--org-files-in`), not dirs"; added the `my/review--org-files-in` seam to the
  listed interfaces. **design.md §10 RN-7** added recording the rationale
  (`org-ql-select` does not expand a directory). Prose aligned to shipped code;
  the implementation is canonical.

### REVs completed
- None. No governance/spec item in the brief — zero ADR/policy/standard/spec
  contradiction.

### Withdrawn / tolerated
- RV-013 F-2: tolerated — `just check` vacuity is pre-existing infra debt tracked
  in ISS-007; SL-013 VT proven independently 9/9 via the batch runner. Rationale
  in the finding disposition. No reconcile write.

### Deferred to /close (not reconcile writes)
- Two VH gates (PHASE-02 promote live e2e — needs `home-manager switch`;
  PHASE-03 views live e2e — `eval-buffer`, no rebuild) remain PENDING and gate a
  clean close. Steps in `.doctrine/slice/013/notes.md`.

Reconcile pass complete — handoff to /close.
