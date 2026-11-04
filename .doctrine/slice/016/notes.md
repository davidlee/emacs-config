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

## Harvest
<!-- single-copy: updated in place each harvest; ids only, never restated content -->
fresh-as-of: 2026-11-04 · design: drafting (run rev 21) · 28a16e4 (uncommitted: slice/notes/backlog/DEC records staged or untracked)

### Produced
DEC-012..DEC-024 (accepted) · CHR-010 · IDE-003 · research addendum (socket) · slice-016.md amended (socket transport, apps/ split, keys)

### Learned
E1–E4 in § Design triage above · server one-request-per-connection + 1 s deadline (DEC-015/017 context) · window-kill kills the owning process (DEC-019)

### Open
E1 red test (resolved by DEC-023 at implementation) · E4 stray `t` in core/dl-keymap.el:50 (user's working tree) · upstream k:v window metadata — user raising with umbriel devs (IDE-003)
