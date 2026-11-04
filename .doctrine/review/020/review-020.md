# Review RV-020 — reconciliation of SL-016

Adversarial-review ledger. Structured findings live in the sister
ledger toml; this prose companion carries the reviewer's framing.

## Brief

<!-- Pre-reading + lines of attack: what this review is probing, the invariants
     it must hold the subject to, and where the bodies are likely buried. Seeded
     at `review new`; the reviewer fills it before raising findings. -->
Mode: conformance. Surface reviewed: main worktree at 3843400 (not dispatched;
pi/capsule workers in the main tree). Inputs: notes.md § Autonomy log (the
drift list), DEC-025/DEC-026, design.md, plan.toml VT/VH, docs/emacs/umbriel.md
(as-built reference, fact-checked in PHASE-06).

Lines of attack:
- Every § Autonomy log drift line → design text, decision record, or aligned.
- Post-lock user decisions (DEC-025, DEC-026, the `L` skip-switch) reflected in
  design § Addressing / § One table / § Keys and the amended decisions.
- Selector conformance: undeclared / undelivered paths.
- Gates: `doctrine slice verify-vt 16`, host `just check`, `doctrine check gate`.
- VH evidence: anything waived must be visible, not silently passed.
- Collateral docs that cite code the slice deleted (trap 6).

Invariants held: tests isolated from the live compositor (EX-3); no mutating
umbriel action from an agent; one concern per file (STD-001).

## Synthesis

**Closure story.** The implementation matches its intent and its tests; every
finding is design- or documentation-side. Evidence gathered this pass:
`doctrine slice verify-vt 16` — all VT PASS across PHASE-01..06. Host
`just check` (2026-11-04 23:04): 405 tests, 1 unexpected —
`dl-policy-lint/l2-real-config`, caused by the user's uncommitted
`core/dl-keybind.el:125` (not slice code). `doctrine slice conformance 16`:
0 undelivered, 13 conformant; the 14 undeclared paths are all doctrine records
the slice minted (DEC-025, DEC-026, ISS-012, IMP-030, one observation,
notes.md) — aligned, no selector change needed. `doctrine check gate` could not
run: it invokes `just gate`, and the justfile has no `gate` recipe (project
infra, not this slice).

The slice's design locked before the user's live check (VH-1) produced three
behaviour changes (DEC-025 focus restore + silent move, DEC-026 no scroll keys,
the `L` skip-switch), and the implementation phases made a set of reviewed,
tested corrections the design had wrong or left unstated (fold overlays,
window-start, waiter isolation, detach-before-announce, data-less events,
API arities, prompt ordering). F-1..F-7 carry all of them to reconcile; no
code change is required.

**Standing risks.**
- F-9: compositor-exit reconnect (sentinel → closed header → `g`) and
  256 KiB eviction are verified only against the fake transport; the user
  waived the live restart step.
- `focused` row actions now send three requests (DEC-025); previous focus comes
  from held state and can be stale if the buffer lags — accepted in DEC-025.
- ISS-012 (non-alist stream entries) remains open, out of scope.
- The `L` fix depends on umbriel's `back_and_forth` semantics; `s` keeps the
  toggle by user ruling.

**Tradeoffs consciously accepted.** Waived restart step (F-9). Design text
allowed to lag the code until reconcile, rather than amending a locked design
mid-execution.

## Reconciliation Brief

### Per-slice (direct edit)
- F-1 · design.md § Addressing: `focused` window row = [window-focus ROW,
  ACTION, window-focus PREVIOUS] when previous is known and differs (DEC-025);
  `active-workspace` omits the switch when the target is the held focused
  workspace (back_and_forth). § One table: drop the two scroll rows; move is
  `window-move-to-workspace-silent`; delete "-silent is not in v1". § Keys
  buffer table: drop `C-<left>`/`[`, `C-<right>`/`]` (DEC-026).
- F-3 · design.md § Verification :756 and slice-016.md Risks :179: the session
  shell reaches the compositor; only confined workers do not. Keep the isolation
  obligations.
- F-4 · design.md § Files table: add `dl-umbriel-echo-failure`. § Functions:
  `dl-umbriel-model-workspace-label WORKSPACE &optional COUNT`. § Planning is
  pure: `dl-umbriel-buffer--plan SPEC TARGET FIELDS WORKSPACES`.
- F-5 · design.md § Announcing change: waiters under `condition-case`; § The
  stream connection: detach/subscribe before announcing a status; close on
  request fails waiters with `(:failure closed "stream closed")`; § Stream
  lines: add row "windows/workspaces event without `data` → skipped += 1";
  refresh writes each family via its own reply (not send-all).
- F-6 · design.md § Repaint: replace "without extra code" — repaint shows the
  root section to rebuild fold overlays, resets highlight and modified flag
  (as magit-refresh-buffer), and restores window-point and window-start per
  window; kill hook closes the stream before cancelling the timer.
- F-7 · design.md § Prompts: `C-c u w` refreshes first unless the stream is
  open with workspaces held; workspace and layout prompts keep display order
  via completion metadata (`display-sort-function`/`cycle-sort-function`
  identity).

### Governance/spec (REV)
- F-1 · DEC-016: record the `L` skip-switch (active-workspace plan omits
  `workspace-switch` when the target is already the focused workspace) — amend
  DEC-016 or add a decision record that amends it, as DEC-025/026 did.
- F-2 · DEC-013: choice's workspace label field `window_count` → "window count
  from the join (wire window_count never read)".
- F-6 · DEC-022: qualify the rationale — ids keep point on the same window
  except when it moves between workspaces (ident changes; point falls to a
  sibling).
- F-8 · AGENTS.md trap 6 (:106) and docs/emacs/traps.md § 6 (:105): remove the
  citation of deleted `dl-umbriel--host-environment`. **User ruling pending**
  (AGENTS.md is project authority). Recommended: state the scrub inline —
  bind `process-environment` to it with the `LD_LIBRARY_PATH=` entry removed
  (`seq-remove` + `string-prefix-p`) around each `call-process`/`make-process`
  — and drop traps.md's umbriel-specific "new query / long-lived stream"
  sentence. No live example remains in the config or satan.

## Reconciliation Outcome

The user agreed to the proposal on 2026-11-04 ("agreed"); F-8 wording by the
user's ruling ("1": describe the scrub inline, cite no function).

### Direct edits applied
Written through the design run (`design apply` revision 42, `materialise`
revision 43):
- **sec-actions** (F-1, F-4, F-7): DEC-025/026 named; `focused` row plan with
  the restore step and when it is skipped; `active-workspace` skips a
  redundant switch (back_and_forth), `s` unchanged; scroll rows removed; move is
  `window-move-to-workspace-silent`; display-order prompts and empty-answer
  `user-error`; `--plan … WORKSPACES`; `C-c u w` refresh trigger; `C-c u l`
  prompts at once.
- **sec-keys** (F-1): DEC-026 named; scroll keys removed from the buffer table.
- **sec-files**, **sec-model** (F-4): `dl-umbriel-echo-failure`;
  `workspace-label … &optional COUNT`; flattening is display-only.
- **sec-state** (F-5): `condition-case` waiters; close on request fails
  waiters with `stream closed`; detach/subscribe before announcing; no-`data`
  stream-lines row.
- **sec-buffer** (F-6): window-point/window-start restore; fold overlays via
  `magit-section-show` on the root, highlight and modified-flag reset; kill-hook
  order.
- **sec-verification** (F-3): compositor reachable from the session shell, not
  from tests or confined workers.
- **slice-016.md** Risks (F-3): same correction, direct edit.
- **AGENTS.md** trap 6 and **docs/emacs/traps.md** § 6 (F-8): scrub described
  inline (traps.md carries the `let`/`seq-remove` snippet); citation of the
  deleted `dl-umbriel--host-environment` and the umbriel-specific sentence
  removed.

The edit invalidated the run's `design-accepted` act and the attestations on
the seven edited sections; the run stays `locked` (same state SL-015 was left
in after its reconcile). RV-020 is the review of the reconciled text.

### Governance
No REV: no ADR, spec, requirement, policy or standard touched. Decision
records amended by appended body notes (`knowledge edit --body-mode append`),
accepted choice text left intact:
- **DEC-013** (F-2): label count from the join; `window_count` never read.
- **DEC-016** (F-1): `L` skip-switch, recorded as agent-proposed and passed by
  the user in VH-1 (not as a user decision).
- **DEC-022** (F-6): point keeps the window only while it stays in its
  workspace.

### Brief items not applied (inspected, not applicable)
- **F-5, "refresh not via send-all":** design never said refresh used
  send-all (only plan T-5 did); plan criteria are not a reconcile surface.

### Tolerated
- **F-9:** waived live restart step; rationale in the finding.

Reconcile pass complete — handoff to /close.

## Close

User chose to close on 2026-11-04 ("1."). Gate evidence: `just check` on a
detached HEAD worktree (66de2f2) — 405 tests; red `dl-policy-lint/l2-real-config`
is pre-slice (user's c509d01, `completion/dl-corfu.el:26`), and two
`dl-project` tests fail only because the worktree sat under /tmp. All umbriel
tests green. `doctrine check gate` unconfigured (no `just gate` recipe).
At the user's direction ("update the design if it's inaccurate"), DEC-022's
title was corrected ("idle-coalesced" → "throttled") and its fold claim
qualified; design.md was already accurate there.
