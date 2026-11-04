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

- PHASE-05 (2026-11-04, in progress — VH-1 outstanding): action half of apps/dl-umbriel-buffer.el (table, macro, pure `--plan`, prompts, completion, global switch/layout, row keys); core/dl-keymap.el umbriel lines (C-c u u/w/l/f, SPC u); init.el requires dl-umbriel-buffer. 41 new tests (156 umbriel). Mutation checks: 17 mutants over EX-1/2/3/4/7, D-3 and review fixes R-1..R-7, all killed except one equivalent (nil focused output never matches). VA-1: 156/156 with UMBRIEL_SOCKET at a counting listener → 0 accepts (positive control 1); with socket vars unset → 156/156. Host `just check`: 393 tests, only baseline red `dl-policy-lint/l2-real-config` (core/dl-keybind.el:125). verify-vt PHASE-05 VT-1..5 PASS.
  DEC-025 follow-up (VH-1 finding): restore-after-act + silent move; +8 tests (164 umbriel); mutations 8/8 killed; VA-1 0 accepts (positive control 1); host `just check` 401, only baseline red.
- PHASE-04 (2026-11-04): apps/dl-umbriel-buffer.el (mode, render, header, throttle, stale, point/start/folds, my/umbriel, g, kill) + 25 tests (115 umbriel total). Mutation checks: 14/15 killed; `set-buffer-modified-p nil` removal survives because `magit-section-update-highlight` also clears the flag (kept, as magit does). VA-1: umbriel test files with UMBRIEL_SOCKET at a counting scratch listener → 115/115 pass, 0 accepts (positive control: one `dl-umbriel-stream-open` → 1 accept); with UMBRIEL_SOCKET/WAYLAND_DISPLAY/XDG_RUNTIME_DIR unset → 115/115 pass. VA-2 (live render) left for the user. Host `just check`: 352 tests, only baseline red `dl-policy-lint/l2-real-config`.

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
- PHASE-05 start (2026-11-04, user present): user removed-by-request the stray `t` in core/dl-keymap.el:50, so the file is clean (EN-2 satisfied). PHASE-04 VA-2: user loaded dl-umbriel-buffer and reports it renders; live tracking/folds/reconnect not yet checked, folded into PHASE-05 VH-1 runsheet.
- PHASE-05 VH-1 (user report, 2026-11-04): mostly pass. Focus restore (DEC-025) robust and preferred; flicker fine, glitchy only when the workspace changes. C-c u w works. Faults: `L` always targets workspace 2; `s` on a row of the already-active workspace jumps to the previous one; workspace prompt ordered by recency (prescient), not by number. Cause of `s` (verified): user's umbriel config `back_and_forth = true` (~/.config/umbriel/layout.toml:21; umbriel docs/user/workspaces.md:145) — user: don't work around it for `s`. `L` inferred same cause (its plan switches first). umbriel restart not testable without ending Emacs; `g` reconnect seen during code edits. Visual design → IMP-030 (out of scope).

## Autonomy log

- PHASE-02 · phase sheet: dropped `defcustom` for the change hook → `defvar` (internal hook, less code) · decided
- PHASE-02 · tests: asked for notify-path isolation coverage in the two waiter-signalling tests (registration-only coverage let a non-isolating notify path pass; F-16) · decided
- PHASE-02 · refresh writes per family via its own `dl-umbriel--refresh-families`, not `dl-umbriel-send-all` (which surfaces only the last reply); plan T-5 said reuse send-all · decided; design § Held state silent — audit
- PHASE-02 · waiter isolation uses `condition-case`, not the design's `with-demoted-errors` (returns a truthy message string on a signal, which would read as "predicate held") · decided; design text drift — audit
- PHASE-02 · rule added: detach (or subscribe) before announcing a status, so a hook/waiter that reconnects keeps its connection (pi review F1–F3) · decided; design § The stream connection should state it — audit
- PHASE-02 · a windows/workspaces event without `data` is skipped, not taken as empty (design § Stream lines table lacks the row; JSON null and [] both parse to nil, so only a missing key is detectable) · decided — audit
- PHASE-02 · close-on-request fails pending waiters with `(:failure closed "stream closed")` (design names no failure for it) · decided — audit
- PHASE-02 · fake transport: one handle per connection, writes to a deleted one signal · decided (test helper)
- PHASE-03 · `dl-umbriel-model-workspace-label WORKSPACE &optional COUNT`: design table has one argument; COUNT (from the join) is how EX-3's "count from the join, not window_count" is met; choices pass none · decided; design § Functions table — audit
- PHASE-03 · DEC-013 (accepted) still lists `window_count` in the workspace label; plan EX-3 / design § Display strings reverse it; code follows plan+design · drift — audit/reconcile
- PHASE-03 · flattening (C-8) is display-only: selector and join read raw `name`/`id`/`output` (pi review F2, seat's own read concurred) · decided; design § Display strings could say so — audit
- PHASE-03 · named workspace with no name selects `""`, not a fallback to index (review F3): design says name when named; the compositor's rejection stays visible · decided
- PHASE-03 · non-alist / nil entries in held state (review F4/F5) → ISS-012, fix at the stream parse boundary, not the model · deferred
- PHASE-03 · sorting via Emacs 30+ `sort :key` (stable, copying, `value<`) instead of a hand-rolled comparator · decided (refactor)
- PHASE-04 · kill hook added by `my/umbriel` beside the stream open, not in the mode body (who opens registers the close; mode stays display-only) · decided
- PHASE-04 · `dl-umbriel-buffer-mode-map` created now as an inline `defvar-keymap` holding only `g`; PHASE-05 adds the row keys inline · decided
- PHASE-04 · per-window point AND window-start restore (magit-mode's refresh pattern); design names goto-successor only, but erase-buffer resets every window-point and window-start (reviews VERIFIED) · decided; design § Repaint — audit
- PHASE-04 · design § Repaint "Keeping folds … without extra code" is wrong: the cache sets `hidden` but only `magit-section-show` on the root makes the overlays; repaint also resets magit's highlight state and the modified flag, as `magit-refresh-buffer` does (both reviews, VERIFIED) · decided; design drift — audit
- PHASE-04 · kill hook closes the stream first, then cancels the repaint timer (close announces → hook would re-arm after a cancel) · decided
- PHASE-04 · every entry point uses `dl-umbriel-buffer--live` (named *and* in the mode): a foreign buffer named *umbriel* is never drawn into · decided
- PHASE-04 · header `%` doubling checked by evaluating the `:eval` form: `format-mode-line` returns "" in batch · decided (test)
- PHASE-04 · a window moved to another workspace gets a new ident, so point falls to a sibling (design accepts; Opus review: DEC-022 rationale "ids keep point on the same window" oversells it for drags between workspaces) · drift — audit
- PHASE-04 · init.el require and keys left to PHASE-05 as planned; CHANGELOG tells the user to `load-library` until then · decided
- PHASE-04 · VA-2 (live render against the compositor) left for the user per charter · deferred
- PHASE-05 · `dl-umbriel-buffer--plan` takes a 4th arg WORKSPACES (design names three) so it stays pure while finding the window's workspace and the focused output · decided; design § Planning is pure — audit
- PHASE-05 · `active-workspace` refuses unless exactly one held workspace is `focused` (none → cannot check; two → ambiguous). umbriel marks at most one (ipc_commands.cpp:831), so this is defence in depth (pi review R-1) · decided
- PHASE-05 · the plan's refusal is checked before any prompt, and again after (a refused row never prompts; a refusal never reaches send-all) · decided
- PHASE-05 · global `C-c u w` prompts from held state only while the stream is open and workspaces are held; otherwise refresh → `run-at-time 0` → prompt, or a message if still none (design keyed this on "no buffer") · decided; design § Prompts never run inside a process callback — audit
- PHASE-05 · `C-c u l` prompts at once (static layout list, no held state) · decided
- PHASE-05 · empty `completing-read` input (allowed even under REQUIRE-MATCH) is a user-error; unknown prompt kind / addressing signal (fail closed) · decided
- PHASE-05 · kill prompt built from `dl-umbriel-model-window-label` (one line; a title with a newline cannot forge prompt text), says "Kill the process of …"; emacs-pid compared numerically (pi review R-3/R-4) · decided
- PHASE-05 · keys resolved by `declare-function` + symbol binding (dl-keymap.el has no autoload convention); EX-6 subprocess test shows both load orders resolve · decided
- PHASE-05 · no Claude review of the trust boundary: pi review covered kill/F-19/F-6/EX-4 with probes, all its findings accepted and mutation-tested; seat read every boundary function · decided
- PHASE-05 · VH-1 (user runs the mutating actions live) outstanding; phase left in_progress · deferred
- PHASE-05 · DEC-025 (user, during VH-1): `focused` window rows restore the previous focus; previous = `focused_window` of the one focused held workspace, unknown when it is absent/nil/"" or zero/two workspaces are focused (same reading as `--off-pointer-p`, now sharing `--focused-workspace`); row move is `window-move-to-workspace-silent` · decided; drift: design.md § Addressing table and DEC-016's consequence ("-silent not in v1", focus stays on the row) superseded by DEC-025 — audit
- PHASE-05 · VH-1 fault `L`: `active-workspace` plan omits `workspace-switch` when the target is the held focused workspace (id match with `--focused-workspace`; off-pointer refusal already pins the output). Cause verified in umbriel source: `actionWorkspace` → `WorkspaceGroup::select` returns to `m_previous` when the target is already active and `back_and_forth` (actions.cpp:1597, workspace.cpp:3568); `workspace-set-layout` acts on the active workspace (actions.cpp:1658). `s` unchanged (user ruling) · decided; drift: DEC-016 "switches to it first" and design.md § Addressing — audit
- PHASE-05 · VH-1 fault prompt order: workspace and layout prompts use `--ordered-table` (metadata `display-sort-function`/`cycle-sort-function` = `identity`); vertico prefers metadata over `vertico-sort-function` where prescient sits (vertico.el:221-225; `vertico-prescient-override-sorting` nil, unset in config). No completion config touched · decided
- PHASE-05 · DEC-026 (user): scroll row actions and C-<left>/[/C-<right>/] removed from table and buffer map; negative test `scroll-keys-are-gone`; CHANGELOG entry updated · decided; drift: design.md § Keys table, DEC-024 key list, VH-1 runsheet step 10 — audit

### pi passes (PHASE-02)

| run | profile | cost | outcome |
|---|---|---|---|
| form probe ×2 | write | $0.008 | first: no emacs (machine form) → project form df0b4b5; second: emacs/ERT/paren/byte-compile ok |
| phase sheet | implement | $0.035 | good; C-1..C-5 checked against design, sound. Byte-compile command compiled in place — fixed by seat |
| red tests | implement | $0.090 | 26 tests, all void-function red, reproduced on host. Missed notify-path isolation (registration-only) |
| test gap fix | implement (same session) | $0.023 | notify-path isolation added in both signalling tests |
| implementation | implement | $0.062 | 49/49 green; 5 deviations, all sound. Missed: stream-close no-op after a server close (design failed→never); a >80-col docstring; reported byte-compile rc from `tail` |
| review | review | $0.057 | 6 findings, all accepted: 3 announce-before-detach reentrancy bugs (VERIFIED by probe), missing-`data` silently empties, docstring width, sheet wording. Good value |

### pi passes (PHASE-03)

| run | profile | cost | outcome |
|---|---|---|---|
| red tests | implement | $0.071 | 22 tests; stub run: all assertion failures, no test-code errors. Docstring with unescaped `""` (seat fixed) |
| implementation | implement | $0.035 | 22/22 first try; over-built (hand-rolled lexicographic comparator, index tiebreaks, hash tables, 237 lines) |
| refactor | implement (same session) | $0.009 | `sort :key`, 202 lines, green |
| review | review | $0.084 | 13 findings, all VERIFIED or reasoned: 4 mutants surviving the tests (id-order, choices count, floating order, label part order), selector flattened raw name. Good value |
| test gaps | implement (test session) | $0.031 | +8 tests (30); noticed the specified `\n` near-miss was not sensitive and added a tab/space pair |
| code fixes | implement (impl session) | $0.009 | raw addressing, owner computed once |

### pi passes (PHASE-04)

| run | profile | cost | outcome |
|---|---|---|---|
| red tests | implement | $0.041 | timed out at 15 min wall clock after 18 requests probing `format-mode-line` in batch (returns ""); no file written |
| red tests (cont.) | implement (same session) | $0.052 | 18 tests; validated against a /tmp reference stub (all passed), red on missing feature |
| test gaps | implement (same session) | $0.005 | +3: kill cancels timer, due-after-kill harmless, no buffer schedules nothing |
| implementation | implement (fresh) | $0.046 | 21/21 first try, 233 lines, zero warnings |
| review | review | $0.071 | 14 findings; fold overlay missing (HIGH, VERIFIED), highlight lost, modified flag, kill re-arm, fold test too weak. Good value |
| Claude review | Opus general-purpose | ~113k tokens | concurred on all of pi's majors; added window-start reset (VERIFIED), foreign-buffer guard, cross-workspace point fallback |
| review tests | implement (test session) | $0.046 | +4 tests, 5 red for the right reasons; timer stubs made discriminating (full-suite fragility the seat found) |
| review code | implement (impl session) | $0.021 | R-1..R-7, 115/115 green incl. under global-auto-revert-mode |

pi misses: the timer stubs failed on any `cancel-timer`, so the full suite (auto-revert on `after-change-major-mode-hook`) went red though targeted ERT was green — only `just check` showed it. The fold test asserted the `hidden` slot, not invisibility. Neither reviewer nor the seat's mutations caught the fold defect before the probes; design text had asserted "no extra code".

### pi passes (PHASE-05)

| run | profile | cost | outcome |
|---|---|---|---|
| red tests | implement | $0.128 | 27 tests; all red for missing functions, validated against a /tmp stub. Good EX-2/F-19 negative controls |
| implementation | implement (fresh) | $0.053 | 142/142 first try, zero warnings. Missed: empty completing-read input sends a bogus selector/layout; "Switch to workspace" prompt reused for move; kill prompt didn't say "process" (seat fixed + 1 test) |
| Sonnet capsule-worker | — | ~60k tokens | dl-keymap.el (2 hunks, umbriel-only), init.el require, 5 key tests incl. EX-6 two-order subprocess. Clean |
| review | review | $0.080 | 7 findings, all accepted: two-focused F-6 fail-open, unknown prompt kind sends unconfirmed kill, newline in title forges kill prompt (VERIFIED), float pid, unguarded second plan, no addressing fallback, empty workspaces prompt |
| review tests | implement (test session) | $0.035 | +8 tests; 6 red for the right reason, 2 pin current behaviour |
| review code | implement (impl session) | ~$0.03 | R-1..R-7, 156/156 |
| DEC-025 red tests | implement | $0.041 | 8 tests + table/move update; 6 red for the right reason. Two docstrings with unescaped `""` (seat fixed) |
| DEC-025 green | implement (fresh) | $0.015 | 164/164 first try; shared `--focused-workspace` with `--off-pointer-p`. Mutations 8/8 killed (omitted, prev==row, after failed action, workspace row, non-silent, "" known, two focused, window addressing) |
| VH-1 fix red tests | implement | $0.028 | 3 tests + 2 updated; 4 red for the right reason |
| VH-1 fix green | implement (fresh) | $0.032 | 167/167 first try; retargeted legacy `completion-stops-at-the-first-failure` to the DP-1:2 row (assertions unchanged). Mutations 6/6 killed (focused still switches, other omits switch, no metadata, no cycle sort, no display sort, `s` skips switch); sanity mutant red |
| DEC-026 red+green | implement | $0.012 | 168/168; also pruned scroll keys from the motion-shadow test's list. Mutant (rebind `[`) killed |

pi misses: implementation trusted `completing-read`'s REQUIRE-MATCH to exclude empty input. Test writer fed a workspace label to the layout prompt in one loop test (masked until the empty-input guard). Seat's own miss: first mutation runner put the mutant dir last on `-L` (the first `-L` wins), so every mutant "survived" — a sanity mutant caught it.

## Harvest
<!-- single-copy: updated in place each harvest; ids only, never restated content -->
fresh-as-of: 2026-11-04 · PHASE-02 completed, PHASE-03 next · fbcaf5d

### Produced
design.md (locked, run rev 41) · RV-018 (design review; F-6/7/8/9/11/14 routed into plan criteria) · DEC-012..DEC-024 · CHR-010 · IDE-003 · plan.toml/plan.md (PHASE-01..06) · RV-019 (plan review, codex; done) · PHASE-01: apps/dl-umbriel.el (client), apps/dl-umbriel-focus.el, lisp/test/dl-umbriel{,-focus}-test.el · PHASE-02: stream/state/hook/waiter/refresh in apps/dl-umbriel.el, 31 tests · project quotient forms (df0b4b5) · commits af416dc, 643f68a, deb8ab9, fbcaf5d

### Learned
E1–E4 in § Design triage · § Progress PHASE-01 (connect-error mapping re-observed; F-9 mutation check; `dl-umbriel-echo-failure` added beyond design) · compositor reachable from the in-session agent (user, 2026-11-04; Claude auto-memory) — read-only live probes are agent checks, mutating actions are the user's

### Open
slice Risks + design § Verification say "no compositor reachable" — stale, fix at /reconcile · design § Files "provides" list lacks `dl-umbriel-echo-failure` — reconcile · `just check` red only from the user's uncommitted core/dl-keybind.el:125 remap (policy lint L2) — theirs to resolve · E4 stray `t` core/dl-keymap.el:50 (user's) · PHASE-05 EN-2: user's dl-keymap.el edits · upstream k:v window metadata (IDE-003) · PHASE-02 design drift for audit: see § Autonomy log (send-all, condition-case, detach-before-announce, data-less events, close-on-request failure) · CHANGELOG entry deferred to the first user-facing phase
