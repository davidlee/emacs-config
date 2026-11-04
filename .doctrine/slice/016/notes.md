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

- PHASE-01 (2026-11-04): client requests + transport in apps/dl-umbriel.el (git mv), focus in apps/dl-umbriel-focus.el on the client; 29 umbriel tests green; F-9 test mutation-checked; VA-1 live read-only probe passed. Added public `dl-umbriel-echo-failure` (one failure echo for focus and row actions). Baseline red from the user's uncommitted dl-keybind.el remap (policy lint L2), not ours.

## Harvest
<!-- single-copy: updated in place each harvest; ids only, never restated content -->
fresh-as-of: 2026-11-04 · design locked (run rev 41), slice status plan · 28a16e4 (uncommitted: slice/notes/design/DEC/backlog records)

### Produced
design.md (locked) · RV-018 (F-1..F-19 disposed; severe ones routed — control/probe criteria for /plan) · DEC-012..DEC-024 (accepted; DEC-016/020/022/023/024 amended in review) · CHR-010 · IDE-003 · research addendum (socket) · slice-016.md amended (socket transport, apps/ split, keys)

### Learned
E1–E4 in § Design triage above · server one-request-per-connection + 1 s deadline (DEC-015/017 context) · window-kill kills the owning process (DEC-019)

### Open
plan authored (PHASE-01..06); RV-019 plan review (codex): F-1..F-3 fixed + verified, done; awaiting user approval + commit · compositor IS reachable from the in-session agent (user correction 2026-11-04; `UMBRIEL_SOCKET` set, `umbriel windows --json` answers) — slice Risks and design § Verification prose stale on this, reconcile at /reconcile; jailed dispatch workers still cannot reach it ·
RV-018 instrument-routed criteria (F-6/7/9/11/14 control, F-8 probe) → plan must carry them · E1 test edited in user's working tree (now green; replaced at implementation per DEC-023) · E4 stray `t` in core/dl-keymap.el:50 (user's working tree) · upstream k:v window metadata — user raising with umbriel devs (IDE-003)
