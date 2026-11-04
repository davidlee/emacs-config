# Notes SL-016: umbriel window and workspace control surface

Durable per-slice scratchpad — tracked in git. The place to lift anything from a
disposable phase sheet (`.doctrine/state/.../phase-NN.md`) that must survive
`rm -rf` before the slice close-out audit harvests it.

## Design triage (2026-11-04, design run exploring)

Inputs: `slice-016.md`, `research/research.md` (baseline fresh), umbriel
`docs/user/ipc.md` re-read, `lisp/dl-umbriel.el`, `lisp/test/dl-umbriel-test.el`.

### Constraining governance
- STD-001 one concern per file (required) — decides the file split.
- AGENTS.md: paren check per `.el`, `just check` commit gate, CHANGELOG; trap 1
  (`git add` new files), trap 6 (env scrub).
- `docs/emacs/naming.md` — `dl-umbriel-*` / `--private` / `my/` commands.

### New evidence this round
- **E1 — `just check` is red on main.** `dl-umbriel/focus-frame-focuses-its-window`
  expects argv `("msg" "window-focus:ours")`; code sends
  `("msg" "window-focus" "ours")`. upstream (`ipc.md`, `actions.cpp:1470`) takes
  the id as a separate word, so the test is stale, not the code. Observed by
  running the file in batch.
- **E2 — a missing binary is not exit 127 inside Emacs.** `call-process` and
  `make-process` both signal `(file-missing "Searching for program" …)`
  (verified in `emacs --batch -Q`). The 127 conflation is a shell artefact;
  `ignore-errors` in `dl-umbriel--windows` is what collapses it. So the four
  failures are separable cheaply: signal / exit 127 + stderr / exit 1
  `cannot connect` / exit 1 `closed the stream without sending anything`.
- **E3 — no CLI path takes a typed JSON action.** `umbriel msg` takes words;
  typed `{"cmd":"action",…}` exists only on the socket, a slice non-goal. The
  slice's "JSON request shape" test item is therefore unreachable as written —
  drift to settle (test argv instead).
- **E4 — uncommitted stray `t`** after `(declare-function consult-line "consult")`
  in `core/dl-keymap.el:50` (working tree, not ours). Harmless top-level form;
  surfaced to the user, not touched.

### Open questions (→ design inquiries)
file split; failure taxonomy representation; stream process ownership/lifetime/
reconnect; repaint coalescing and point preservation; workspace addressing
(named → name, else index, always `--output`); action completion & refresh when
the stream is down; fate of `dl-umbriel-focus-frame` on the new client; buffer
key bindings (directional keys — user preference applies); destructive-action
confirmation (`window-kill`).

### Risks
silent dead child; drag-event volume; upstream field renames (accessors default);
no compositor in agent env (manual host check only).

### Assumptions
`umbriel` on PATH in plain shell; `ipc_commands.cpp` field names are the contract;
`magit-section` available (magit packaged).

## Review passes (design run, reviewing)

RV-018 pass 1 (agent): F-1..F-3, fixed. Pass 2 (quotient `review` profile):
F-4..F-19 — 14 integrated, 2 refuted with source evidence (see the ledger).
DEC-016, DEC-020, DEC-022, DEC-024 amended from these passes.

A further pass would probe the same seams with runtime evidence rather than
reading: connect/close races and eviction mid-line, the throttle under a real
drag, and multi-output layout behaviour. The manual host check covers those
better than another document review, so none is needed. Note for any future
delegated review: the quotient sandbox could not read `~/.local/src/umbriel`,
`/nix/store` or run `emacs`, so its claims there were inferences and had to be
verified here — two were wrong.

## Progress

- PHASE-02 (2026-11-04): stream half of apps/dl-umbriel.el — held state (one record, three writers), change hook, waiter, stream open/close, stream lines, refresh. 31 new tests (54 umbriel total); mutation-checked; VA-1 live passed (17 windows, 6 workspaces, 0 skipped). pi-orchestrated: tests and code by separate pi runs, review by pi; seat fixed 6 issues.
- PHASE-01 (2026-11-04): client requests + transport in apps/dl-umbriel.el (git mv), focus in apps/dl-umbriel-focus.el on the client; 29 umbriel tests green; F-9 test mutation-checked; VA-1 live read-only probe passed. Added public `dl-umbriel-echo-failure` (one failure echo for focus and row actions). Baseline red from the user's uncommitted dl-keybind.el remap (policy lint L2), not ours.

## Implementation run

From PHASE-02 (2026-11-04): /pi-orchestrate from the session seat. pi
(quotient) does phase work; the seat keeps gates, contract-test reads,
mutation checks, VA-1 and doctrine state.

- Form: project forms at `.quotient/forms/{read,write}` (df0b4b5): emacs,
  just, read-only `~/dev/satan` and `~/.local/src/umbriel`. No
  `UMBRIEL_SOCKET`/`XDG_RUNTIME_DIR` in the sandbox, so neither tests nor
  delegates can reach the compositor; VA-1 is the seat's. A rebuild changing
  the form needs the user's `quotient allow`.
- Delegates can read the repo root, including `*.secret.el`; the form
  cannot mask files inside the root. Briefs never point at them.
- Sandbox-only `just check` failures (not form gaps; host gate is
  authoritative): `dl-agent-review-external-edit-comments-and-cleanup`,
  `dl-nix/apheleia-formats-with-alejandra` (no alejandra), LOADERR
  `dl-modeline-test`/`dl-org-iw-test` (org-iw not bound). Workers run
  targeted `^dl-umbriel` ERT; the seat runs `just check` on the host.
- Host gate: `just check` from the session shell. Baseline red only on
  `dl-policy-lint/l2-real-config` (user's uncommitted dl-keybind.el).
- Other writers: user's uncommitted `completion/dl-corfu.el`,
  `core/dl-keybind.el`, `core/dl-keymap.el`. Commit explicit paths only.

- Plan for the rest (user, 2026-11-04): PHASE-03..04 unattended via /super-orchestrator, halt after PHASE-04; PHASE-05..06 with the user present (PHASE-05 EN-2: user's dl-keymap.el; keys are theirs). Workers: 03 pi; 04 pi, Sonnet after two pi failures, pi + Claude review; 05 pi for the pure action table, Claude for keymap/keys, user checks mutating actions live; 06 Sonnet; audit/reconcile Opus (GPT optional).
- Super-orchestrator run PHASE-03..04 (2026-11-04): form re-probed (write: emacs/just/git ok, magit-section source readable, `^dl-umbriel` ERT 60/60). Targeted ERT has no just recipe: reproduce `check`'s load path with selector `^dl-umbriel`. Background tasks on, spawn depth unset (ok), auto mode.

## Autonomy log

- PHASE-02 · phase sheet: dropped `defcustom` for the change hook → `defvar` (internal hook, less code) · decided
- PHASE-02 · tests: asked for notify-path isolation coverage in the two waiter-signalling tests (registration-only coverage let a non-isolating notify path pass; F-16) · decided
- PHASE-02 · refresh writes per family via its own `dl-umbriel--refresh-families`, not `dl-umbriel-send-all` (which surfaces only the last reply); plan T-5 said reuse send-all · decided; design § Held state silent — audit
- PHASE-02 · waiter isolation uses `condition-case`, not the design's `with-demoted-errors` (returns a truthy message string on a signal, which would read as "predicate held") · decided; design text drift — audit
- PHASE-02 · rule added: detach (or subscribe) before announcing a status, so a hook/waiter that reconnects keeps its connection (pi review F1–F3) · decided; design § The stream connection should state it — audit
- PHASE-02 · a windows/workspaces event without `data` is skipped, not taken as empty (design § Stream lines table lacks the row; JSON null and [] both parse to nil, so only a missing key is detectable) · decided — audit
- PHASE-02 · close-on-request fails pending waiters with `(:failure closed "stream closed")` (design names no failure for it) · decided — audit
- PHASE-02 · fake transport: one handle per connection, writes to a deleted one signal · decided (test helper)

### pi passes (PHASE-02)

| run | profile | cost | outcome |
|---|---|---|---|
| form probe ×2 | write | $0.008 | first: no emacs (machine form) → project form df0b4b5; second: emacs/ERT/paren/byte-compile ok |
| phase sheet | implement | $0.035 | good; C-1..C-5 checked against design, sound. Byte-compile command compiled in place — fixed by seat |
| red tests | implement | $0.090 | 26 tests, all void-function red, reproduced on host. Missed notify-path isolation (registration-only) |
| test gap fix | implement (same session) | $0.023 | notify-path isolation added in both signalling tests |
| implementation | implement | $0.062 | 49/49 green; 5 deviations, all sound. Missed: stream-close no-op after a server close (design failed→never); a >80-col docstring; reported byte-compile rc from `tail` |
| review | review | $0.057 | 6 findings, all accepted: 3 announce-before-detach reentrancy bugs (VERIFIED by probe), missing-`data` silently empties, docstring width, sheet wording. Good value |

## Harvest
<!-- single-copy: updated in place each harvest; ids only, never restated content -->
fresh-as-of: 2026-11-04 · PHASE-02 completed, PHASE-03 next · fbcaf5d

### Produced
design.md (locked, run rev 41) · RV-018 (design review; F-6/7/8/9/11/14 routed into plan criteria) · DEC-012..DEC-024 · CHR-010 · IDE-003 · plan.toml/plan.md (PHASE-01..06) · RV-019 (plan review, codex; done) · PHASE-01: apps/dl-umbriel.el (client), apps/dl-umbriel-focus.el, lisp/test/dl-umbriel{,-focus}-test.el · PHASE-02: stream/state/hook/waiter/refresh in apps/dl-umbriel.el, 31 tests · project quotient forms (df0b4b5) · commits af416dc, 643f68a, deb8ab9, fbcaf5d

### Learned
E1–E4 in § Design triage · § Progress PHASE-01 (connect-error mapping re-observed; F-9 mutation check; `dl-umbriel-echo-failure` added beyond design) · compositor reachable from the in-session agent (user, 2026-11-04; Claude auto-memory) — read-only live probes are agent checks, mutating actions are the user's

### Open
slice Risks + design § Verification say "no compositor reachable" — stale, fix at /reconcile · design § Files "provides" list lacks `dl-umbriel-echo-failure` — reconcile · `just check` red only from the user's uncommitted core/dl-keybind.el:125 remap (policy lint L2) — theirs to resolve · E4 stray `t` core/dl-keymap.el:50 (user's) · PHASE-05 EN-2: user's dl-keymap.el edits · upstream k:v window metadata (IDE-003) · PHASE-02 design drift for audit: see § Autonomy log (send-all, condition-case, detach-before-announce, data-less events, close-on-request failure) · CHANGELOG entry deferred to the first user-facing phase
