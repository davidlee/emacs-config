# Review RV-011 — reconciliation of SL-011

Adversarial-review ledger (ADR-007). Structured findings live in the sister
ledger toml; this prose companion carries the reviewer's framing.

## Brief

Conformance audit of SL-011 ("SATAN tick performance: observe and bound"),
driven via `/dispatch` (7 phases on `dispatch/011`, self-audit). Reviewed
surface: the coordination tip `dispatch/011` (materialized into the coord
worktree) + the prepared `review/011` / `phase/011-NN` evidence refs.

Lines of attack:
- **Choke coverage** — is every per-tick subprocess (db/git/bough/sway/patch)
  routed through `dl-satan-trace-call` with a deadline, and is read-only git
  carrying `GIT_OPTIONAL_LOCKS=0`? (VA-1 residue sweep; VH-1 lock loop.)
- **Telemetry fidelity** — does a real tick emit exactly one honest `kind:"tick"`
  row + a lossless subprocess ledger? (VH-1 live run.)
- **Budget honesty** — do optional stages shed + degrade truthfully under an
  exhausted budget, with core stages + watermark commits never skipped?
- **Confinement** — does every mutating patch git op assert ownership?
- **Design/impl conformance** — do the shorthand names + predicted targets in
  design §2/§5 match what actually landed?

Invariants held: choke-return contracts preserved; the trust boundary stays in
Emacs (POL-001); watermark integrity (no half-skipped read/commit); telemetry
never fails the tick.

Evidence: `just check` PASS 1026/1035 (0 unexpected, 9 pre-existing skips);
`slice conformance 11` → 0 undeclared, 23 conformant, 1 undelivered (F-2);
VH-1 live tick row perfect + zero `index.lock` collisions under a concurrent
git-status loop on a real repo.

## Synthesis

SL-011 lands its intent: the SATAN perception tick is now **bounded** (per-probe
deadlines on every db/git/bough/sway/patch subprocess choke; a tiered wall
budget that sheds optional stages) and **observed** (a per-tick trace row + a
subprocess ledger, day-bucketed JSONL under XDG state, kill-switch
`dl-satan-trace-enabled`). Live VH-1 confirmed the primary deliverable: a real
tick emits one honest, fully-attributable tick row (every core + optional stage
timed, budget fields, `outcome:"spawned"`, `skipped:[]`), and a concurrent
`git status` loop against a real repo produced **zero `index.lock` collisions**
— the `GIT_OPTIONAL_LOCKS=0` coverage does its job.

The audit raised six findings, all terminal, no blockers:

- **F-4 (major, fix-now)** was the one real defect — VH-1 caught the subprocess
  ledger silently dropping rows whose argv carried a **unibyte** non-ASCII
  payload (`json-serialize` → `json-value-p`), a latent gap in the shared
  `dl-satan-jsonl-prepare` that SL-011's ledger was first to exercise at volume.
  Fixed in-slice (unibyte→UTF-8 coercion + 3 tests). This vindicates the live
  gate: a green unit suite alone would not have surfaced it.
- **F-1 / F-2 (minor, verified → reconcile)** are design-prose drift: §2 named
  the choke fns by shorthand, and §5 predicted a patch-runner edit the runner
  didn't need (its git already routes through the confined `--git`). Both are
  design-tells-the-truth cleanups for `/reconcile`, not code defects.
- **F-3 (minor, tolerated)** — bough error text may now combine stdout+stderr;
  no consumer asserts exact text.
- **F-5 (nit, tolerated)** — unbound-tick rows render `run_id` as `{}` not
  `null`; cosmetic, owned by IMP-015.
- **F-6 (minor, aligned)** — `verify-vt` UNATTRIBUTABLE on 7 VTs is a
  refresh-base-merge diff-attribution artifact; the tests are delivered (508
  insertions vs trunk) and green.

**Standing risks / consciously accepted tradeoffs.** The wall budget bounds only
the optional tail; the honest worst case is Σ core per-probe timeouts (~40s
pathological). Tightening the defaults is a data-driven follow-up once trace
rows accumulate (design §3, IMP-014 owns the read side). Trace-file retention is
unbounded (day-bucketed) — folded into IMP-014. Neither blocks this slice.

## Reconciliation Brief

### Per-slice (direct edit)
- **design.md §2** (F-1): rename the choke sites to the real fns —
  `dl-satan-bough--invoke` (not `evidence--bough-call`), `dl-satan-sway--swaymsg`
  (not `tools-sway--call`), and defcustom `dl-satan-sway-timeout-seconds` (not
  `dl-satan-tools-sway-timeout-seconds`). Note bough routes combined
  stdout+stderr (F-3).
- **design.md §5** (F-2): record that `dl-satan-patch-runner.el` needs no direct
  change — patch git is fully routed through `dl-satan-patch-worktree--git`
  (confinement + ledger), so the runner is subsumed. Drop or annotate the
  undelivered `satan/dl-satan-patch-runner.el` selector.

### Governance/spec (REV)
- None. No ADR/policy/standard/spec change is implied by this slice. POL-001
  (trust boundary in Emacs) is upheld — telemetry + budget live in the broker;
  no daemon extraction.

### Follow-up (backlog, not reconcile)
- **IMP-015** (F-5): render unbound-tick `run_id` as `null` not `{}`.

## Reconciliation Outcome

### Direct edits applied
- **design.md §2** (F-1, F-3): choke-site table renamed to the real fns —
  `dl-satan-bough--invoke` (tools-bough.el, note "combined stdout+stderr"),
  `dl-satan-sway--swaymsg` (tools-sway.el), defcustom `dl-satan-sway-timeout-seconds`.
- **design.md §5** (F-1, F-2): code-impact table — bough row →
  `dl-satan-bough--invoke → trace-call (combined stdout+stderr)`; patch-worktree
  row dropped `(+ runner)`, added "patch-runner needs no change — its git routes
  through `--git`".

### REVs completed
- None. Reconciliation brief carried no governance/spec item — POL-001 upheld
  (telemetry + budget live in the broker; no daemon extraction).

### Withdrawn / tolerated
- **F-3** (bough merges stderr into stdout): tolerated — no consumer asserts
  exact bough error text.
- **F-5** (unbound-tick `run_id` renders `{}` not `null`): tolerated, cosmetic —
  owned by follow-up IMP-015.
- **F-6** (`verify-vt` UNATTRIBUTABLE on 7 VTs): aligned — refresh-base-merge
  diff-attribution artifact; tests delivered (508 insertions vs trunk) + green.
- **F-4** (major): the one real defect — fixed in-slice (`dl-satan-jsonl-prepare`
  unibyte→UTF-8 coercion + 3 tests, corrective worker on `dispatch/011`).

Reconcile pass complete — every finding terminal, no half-applied REVs.
Handoff to /close.
