# Notes SL-011: SATAN tick performance: observe and bound

Durable per-slice scratchpad — tracked in git. The place to lift anything from a
disposable phase sheet (`.doctrine/state/.../phase-NN.md`) that must survive
`rm -rf` before the slice close-out audit harvests it.

## Implementation via /dispatch (PHASE-01..04 landed on `dispatch/011`)

Driven through the claude dispatch arm; workers self-commit via `worker_commit`,
orchestrator lands via `dispatch_import` → `dispatch_conclude_phase` → reap. Per-
batch verify beat = coord-tree `just check` (the `check regression` harness is
unconfigured here — defaults to cargo; `check prove` ⇒ absent `just prove`). Test
postgres must be up or `just check` is red and blocks `worker_commit`. See memory
`dispatch-prereqs-emacs-d`.

## Reconciliations for /audit (design §2 named some sites by shorthand)

- **PHASE-03 F-a**: bough choke is `dl-satan-bough--invoke` (tools-bough.el), not
  the elisp wrapper `--bough-call`/`bough-read` the design named. Real subprocess
  routed.
- **PHASE-03 F-b**: sway fn is `dl-satan-sway--swaymsg` (design said
  `tools-sway--call`); defcustom `dl-satan-sway-timeout-seconds` uses the file's
  existing `dl-satan-sway-` prefix (not design's `dl-satan-tools-sway-`).
- **PHASE-03 F-c**: `dl-satan-bough--invoke` captured stderr to a temp file;
  `trace-call` returns only `(:exit :stdout :timed-out)`. Concession: bough now
  routes with COMBINED stdout+stderr in `:stdout`; error text may include both. No
  VT asserts exact bough error text.
- **PHASE-03 adaptations**: git sites resolve the program via `executable-find`
  (absolute path) so the `timeout` wrapper resolves it via PATH — keeps the
  PHASE-01 stub-git test green under the folded `:env`. `test-sway-border.el` stub
  reseated from `call-process` → `dl-satan-trace-call` (the routing wraps argv in
  `timeout`, so the raw-argv seam moved). migrate `--fetch-traces` passes explicit
  `nil` INPUT before `:timeout-secs nil` (cl-defun `&optional`+`&key` ordering).
- **PHASE-02→04 seam**: PHASE-02 built `with-tick` flushing a placeholder
  `"ok"/"error"` outcome; PHASE-04 added `dl-satan-trace-outcome` + threaded the
  domain outcomes (`spawned|budget_denied|session_blocked|perceive_failed`). Clean
  phase split, not a PHASE-02 miss.
- **PHASE-04**: `dl-satan-db.el` `db-query`/`db-psql` are now `cl-defun` with
  `&key label (timeout-secs dl-satan-db-timeout-seconds)`; all pre-existing
  positional callers unchanged. 3 broker gate tests bind `dl-satan-trace-enabled
  nil` (write hygiene — avoid real tick rows into `~/.local/state/satan/` when the
  suite runs unjailed).
- **PHASE-04**: `dl-satan-trace-subprocess` gained a trailing optional `label`
  arg (reconciles the "reuse for the row" + "label on the row" mandates).

## Selectors

Declared design-target selectors from design §5 mid-drive (were empty at plan
time — declare BEFORE `dispatch_import` or its classify belt rejects
`undeclared-scope`). 21 selectors now cover the §5 targets + touched test files.
