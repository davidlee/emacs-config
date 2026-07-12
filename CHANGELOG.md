# Changelog

Notable changes to this Emacs config. Loosely dated; not versioned.

## 2026-07-12 — chore: denote link-follow perf (exclude satan tree)

Following a `denote:` link stalled ~10s (fans up). Root cause: denote re-walks
the entire `denote-directory` tree, uncached, on every id→path resolution
(`denote--directory-all-files-recursively`), and `~/notes/satan/` holds ~10k
model-facing files that are never denote notes. `denote-excluded-directories-regexp`
was nil, so nothing was pruned.

- **`org/dl-denote.el`** — set `denote-excluded-directories-regexp` to prune the
  `satan` path segment `(rx (or bos "/") "satan" (or eos "/"))`. Cuts the scan
  from ~10k files to the note corpus; a note named `…-satan.org` is unaffected.
- Surfaced by SL-013 VH (retrieval was dead before, so nobody paid the tax);
  fix is denote global config, outside the slice's promote/review code.

## 2026-07-12 — SL-013 PHASE-03: review gap-fill

Revive three dead review surfaces; dedupe the `protocol.org` path.

- **`org/dl-review.el`** — `my/review-journal-open` (+ work) surfaces open
  (not-done) journal + weekly headings via org-ql `(todo)`; `my/review-protocol`
  opens `protocol.org` at the first TODO; `my/review-recent-notes` (+ work)
  Direds the newest durable notes (projects/areas/sources/slips) as an explicit
  file list. New pure seams: `my/review--org-files-in`, `--journal-files`,
  `--durable-dirs`, `--recent-note-files`. `protocol.org` joined the scanned
  notes set.
- **`core/dl-notes-paths.el`** — `dl-notes-protocol-file` defconst; both
  org-protocol capture templates in `dl-org-capture.el` deduped onto it.
- Bindings: `C-c n v {j,p,n}` (personal), `C-c n W v {j,n}` (work).
- Tests: `org/dl-review-test.el` — VT-1 journal-open keyword filter (TODO/NEXT
  in, DONE out), VT-2 recent-note-files mtime order + N-cap. 2/2 green (batch;
  org suites are off the `just check` scan path per ISS-007).
- Gotcha: `org-ql-select` does **not** expand directories (opens them as
  Dired) — journal-files returns concrete `.org` files, unlike `--notes-files`
  which feeds `org-ql-search`.

## 2026-07-12 — SL-013 PHASE-02: subtree promotion command

One-keystroke promotion of an Org subtree to a durable denote note.

- **`org/dl-denote-promote.el`** — `my/denote-promote-subtree` (`C-c n p`):
  prompts for a curated class dir (`my/denote-promote-targets`, 10 durable
  personal+work dirs), extracts the subtree via `denote-org-extract-org-subtree`
  into a new denote note there, saves it, and leaves a level-preserving stub
  heading `*… → [[denote:ID][title]]` at the origin. Quit-at-prompt aborts
  cleanly; wraps upstream rather than reimplementing title/keyword derivation.
- Tests: `org/dl-denote-promote-test.el` — e2e (note created, subtree gone,
  stub links the ID, tags → keywords) + quit-byte-identical, `skip-unless`
  denote-org. 7/7 green.
- **Gate fallout (SL-012 satan extraction):** removed orphan
  `lisp/test/dl-sleipnir-doctor-test.el` — it hard-required the deleted
  `satan-memory-evidence`, LOADERR-aborting the whole `just check` harness. The
  gate now scans an empty `lisp/test/` (org suites were never in its scan
  path); filed **ISS-007** to re-anchor coverage.

## 2026-07-12 — SATAN extraction: `satan/` and `docs/satan/` deleted

SATAN moved out to its own package (`davidlee/satan`). Deleted the in-tree
copy (`satan/`, `docs/satan/`) from `.emacs.d`.

- Verified before delete: only gitignored content under `satan/` was build
  cruft (`dl-satan-run.elc`, two `__pycache__/` dirs) — no untracked source.
  `docs/satan/` had zero gitignored/untracked files; all 39 docs already
  tracked and present verbatim (module-prefix rename `dl-satan-` → `satan-`
  aside) in the package's `docs/`. Nothing stranded.

## 2026-07-11 — SL-011: SATAN tick performance — observe and bound

Bounded and instrumented the perception tick so a slow probe can no longer hang it silently.

- **`dl-satan-trace.el`** (new) — per-tick telemetry: one `kind:"tick"` row (stage timings, budget, outcome, skip list) plus a `kind:"subprocess"` ledger row per external call, day-bucketed JSONL under `$XDG_STATE_HOME/satan/`. Kill switch `dl-satan-trace-enabled`.
- **Bounded choke points** — db / git / bough / sway subprocess calls route through `dl-satan-trace-call` with per-probe deadlines; read-only git carries `GIT_OPTIONAL_LOCKS=0` so a tick never collides with your own `git` on `index.lock`.
- **Tiered tick wall budget** (`dl-satan-trace-tick-budget-seconds`, default 10) — over budget, optional stages (bough recent/day, content probe, resonance, recent-runs) shed and degrade honestly (nil slots, `budget_skipped` sensor status); core stages and watermark commits never skip.
- **Patch-worktree confinement** — every mutating git op asserts its target is under the patch-worktree root (`file-truename`, symlink-escape proof; hard error), and patch git routes through the ledger.

## 2026-06-10 — SATAN backlog waybar widget (DE-010 follow-up)

New `custom/satan-backlog` waybar module showing ingest backlog depth (`head −
cursor` = unconsumed evidence) from `dl-satan-ingest-cursor-backlog-depth`.
Mirrors `custom/satan-inbox`: hidden when zero, degrades silently when the emacs
server is down (non-numeric / empty output → `empty` class).

- `~/.config/waybar/scripts/satan-backlog.sh` — new; emits waybar JSON
  `{text,class}`. The read fn returns a **plist**, and its feature is **not
  auto-loaded** in a running emacs, so the eval form does
  `(require 'dl-satan-ingest-cursor)` then `(plist-get … :total)` — returning a
  bare integer keeps the bash guard identical to satan-inbox.
- `~/.config/waybar/config.jsonc` — module declared (60s interval), placed in
  `modules-right` next to `custom/satan-inbox`.
- `~/.config/waybar/style.css` — `#custom-satan-backlog` added to the muted-pill
  group; shares satan-inbox's `.empty` collapse rule.
- No click action (read-only; manual consume trigger tracked as IMPR-012).

**Deploy correction:** the DE-010 phase-02 note claimed this config lives in
`~/flakes` / needs `home-manager switch`. Verified false — `~/.config/waybar/`
is a plain editable dotfile (tracked only by the home repo). Edit in place +
`systemctl --user reload waybar`. The 2026-05-19 satan-inbox entry was right.

## 2026-06-10 — DE-010: decouple SATAN perception from the agent run

The SATAN tick is cut into **perceive** (deterministic sensing, runs
unconditionally before the session/budget gates) and **consume** (the gated LLM
run carrying all effects, attribute charges, and consumption state). Perception
is now budget-independent and effect-separated — fixing ISSUE-001 (budget-denied
ticks no longer skip `percept.json`). Replayability is *not* delivered here
(→ IMPR-013).

### Phase 1 — perceive/consume seam

- `dl-satan-run-perceive` (percept-build + persist + probe **read-snapshot**) is
lifted out of `dl-satan-broker--spawn` to **before** the gates in `broker-run`.
`assemble-context` retained as the exact `enrich∘perceive` composition.
- Probes split read/commit: perceive takes a pure snapshot (native high-water);
consume charges + advances the watermark to that high-water, not wall-clock `ts`
(curiosity out-of-order bugfix; mirrors content). `-probe = commit∘read`.
- Shared `--write-no-child-run STATUS REASON` helper. **session-blocked** →
`failed`/`session_blocked`, **no `.FAILED`, no announce** (verify-clean bundle);
budget-denied + perceive-failed keep `.FAILED`+announce. All denial paths mirror
`:percept` into `bundle.json`.

### Phase 2 — per-source intra-day ingest cursor

- **NEW `satan/dl-satan-ingest-cursor.el`** — the evidence-assembly frontier
(distinct from per-sensor probe watermarks), per source `(:focus :browser
:content)` keyed on native ts (`end_ts` / `captured_at`); **git excluded**;
intra-day. Advance = `max(current, head)`, idempotent, verbatim native ts.
`consume` advances on success only; perceive + denial paths never do.
- Additive / low-risk: missing or zero cursor ⇒ consume-from-head.
- `dl-satan-ingest-cursor-backlog-depth` (`head − cursor`, emacsclient-callable)
surfaces backlog depth for a waybar widget (read fn built; widget wiring in
`~/flakes` assessed, not built).
- +18 VTs across both phases; `just check` 982/991 → 990/999, zero regressions.

## 2026-06-03 — DE-007: adversarial review of Phase-4 boot context (AUD-008) + fixes

Adversarial review of the DE-007 Phase-4 commits (interactive pi MCP boot
context) surfaced six findings (AUD-008), all reconciled in-delta.

### Fixes

- **DEC-8 mutual exclusion (F-001)**: `dl-satan-broker--spawn-running` was
cleared by an `unwind-protect` at the *synchronous* launch of the async
`make-process`, so the flag was nil for the entire live run — the
scheduled-run→refuse-session guard was vacuous (the very R11 bug Phase 4 was
meant to fix). Replaced with a `condition-case` that clears only on sync spawn
failure; the child sentinel clears on exit. Broadened the sentinel regex to
match `killed`/`deleted` (`delete-process` emits `"killed\n"`), which it
previously missed — so timeout/kill paths now finalise *and* clear the flag.
- **boot-context cache (F-002)**: the cache fast-path was a `when` whose value
was discarded, so every `satan_boot_context` call rebuilt the capsule.
Restructured to a real `if`/early-return.
- **DRY (F-003)**: `boot-context` reimplemented `dl-satan-context-interactive`
inline; now delegates to it as the single capsule source.
- **Session mutation (F-004)**: `dl-satan-context-interactive` destructively
`plist-put` the session-frozen `time_now`; now copies run-ctx first.
- **Tests (F-005)**: +5 tests — producer flag-lifecycle, sentinel exit events,
per-session cache, context-interactive non-mutation + graceful-degrade. Suite
976→981, zero regressions.
- **Repo hygiene (F-006)**: 48 build artefacts (`result`, `.direnv/`,
`.cache/`, `.envrc`) were committed by a dispatch worker's `git add -A` in a
worktree that didn't honour `~/.gitignore_global`. Untracked (`git rm
--cached`), kept on disk. Remaining `just check` red is ISSUE-005 (stale
`bough` binary missing the `read` subcommand — separate subsystem).

## 2026-06-03 — DE-009: SATAN pattern records and scars — outcome-linked pattern-local learning

SATAN's outcome observer now accrues counters and scars against curated
*pattern* definitions — the missing epistemic half of outcome learning.
Each intervention carries an immutable snapshot of the percept handles
present when it fired; at tick end, a guarded SQL projection rebuild
attributes every mature outcome to the patterns whose cue-shape was
contained in that snapshot.

### Changes

- `satan/memory/migrations/0007_patterns.sql` — `satan_patterns` (curated
definitions), `satan_pattern_outcomes` (rebuildable projection),
`satan_pattern_stats` view; `satan_interventions.percept_handles_json`
column with GIN index for JSONB containment matching
- `satan/patterns.eld` — 3 seed pattern definitions, grammar-validated
- `satan/dl-satan-pattern.el` — parse/sync (idempotent, grammar-validated),
containment-join rebuild (single tx + advisory lock, mature/non-unknown
only, head-only), read accessors (`stats`, `list`, `scars`)
- `satan/dl-satan-intervention.el` — stamps `percept_handles_json` from
tool-ctx at `intervention.created`
- `satan/dl-satan-broker.el`, `satan/dl-satan-run.el` — threads
`:percept-handles` into tool-ctx
- `satan/dl-satan-observer.el` — guarded/isolated `dl-satan-pattern-rebuild`
at tick end (condition-case swallows all errors including require/migration
failures; pattern subsystem degradation cannot abort the tick or block
classification)
- 19 new ERT tests (percept snapshot, containment match, grammar-validated
sync, rebuild projection, rebuild guard, global-attr regression)
- `docs/satan/epistemics-roadmap.md` — step 1 marked complete

### Design decisions

- Projection/rebuild over live listener (derive-don't-push)
- JSONB containment subset match over immutable percept snapshot
- Definitions in checked-in `patterns.eld`, grammar-validated sync
- Structural non-regression of global-attribute path via guard + isolation

## 2026-06-02 — DE-008: SATAN git-activity perception 24h feed window (Phase 01)

SATAN's git-activity feed was starved by the 10-minute attention window
shared with focus/browser signals. Commits are bursty; every tick returned
`git_commits={}`, `sensor_status:git="missing"`. The misleading "last commit"
line was live `git log` from the broker's incidental cwd (`git_state`).

### Changes

- `dl-satan-memory-evidence-git-window-minutes` defcustom (default 1440 = 24h)
- Git feed gets its own window: `[git-start, end]` computed from
  `end - git-window-minutes`, un-clamped by `run_started`. Focus/browser
  unchanged.
- `:git_window_start_at` exposed in the evidence plist, distinct from
  `:window_start_at`.
- `--git-feed-paths` rewritten to calendar-day enumeration via calendar
  arithmetic (DST-immune); was endpoint-only, silently dropping intermediate
  days at 24h+ horizons.
- `--git-commits-status`: sort by `:end_ts` before `(last filt limit)` so the
  newest entry is genuinely the last; per-file JSONL parse tolerance so one
  bad day-file doesn't blank good rows from siblings.
- 7 new ERT tests (git window, multi-day paths, DST, sort, malformed tolerance,
  window field).

## 2026-06-01 — DE-007: SATAN interactive pi.dev MCP harness (Phase 3)

SATAN can now be driven interactively from a `pi.dev` session instead of only
via scheduled batch runs. An Emacs-hosted MCP server exposes SATAN tools over
a unix-domain socket; pi connects via a TS extension (node-net UDS, no socat).

### New

- `satan/dl-satan-mcp.el` — MCP server (initialize, tools/list, tools/call,
  ping) over hardened UDS. Reuses `dl-satan-tool-dispatch`, schema emitter,
  audit infrastructure. Per-session run lifecycle with synthetic audit bundle.
- `.pi/extensions/satan.ts` — pi Extension bridging MCP→pi tools. JSON Schema
  → TypeBox conversion, error handling, ping command for diagnostics.
- `satan/prompts/interactive.txt` — static system prompt (Option A).
- `satan/dl-satan-run.el` — extracted shared run infrastructure (struct,
  mint-id, tool-ctx) required by both broker and MCP server.
- `satan/test/dl-satan-mcp-test.el` — 15 ert tests (JSON-RPC, tools/list,
  tools/call, session lifecycle, startup guards).
- `flake.nix` — MCP socket bind-mount in jailed-pi profile.

### Fixes

- `dl-satan-tools.el` — Elisp regex → JS regex translation for `:pattern` args
  in JSON Schema emission.
- `dl-satan-mcp.el` — test tools excluded from interactive mode union;
  deterministic socket filename for flake bind-mount.

## 2026-05-31 — SATAN: test suite fixes (DE-003 refactor regressions)

### DE-006 — DB host isolation: read SATAN_DB_HOST env var

Resolve the Postgres host once at the `dl-satan-db` chokepoint via a
dynamic carrier seeded from `SATAN_DB_HOST`.  Batch (`just check`) redirects
to the test DB through the env var; interactive (`just check-interactive`)
redirects by `let`-binding the carrier for the suite's extent.  The
production broker is never disturbed.

- `satan/dl-satan-db.el` — `dl-satan-db-host-override` carrier,
  `dl-satan-db-resolve-host` (single resolution point + batch prod-guard),
  `dl-satan-db-database-url`, `dl-satan-db-test-db-available-p`
- `Justfile` — `check` is now batch (was `check-batch`);
  `check-interactive` is the emacsclient path (was `check`)
- `dev/dl-test.el` — pre-flight check refuses batch against prod socket
- All DB-touching tests route through the shared predicate or resolver
- 5 migrate tests now pass against test DB (were hitting prod socket)
- Chokepoint VT: 10 new tests, 21/21 passing

Closing the suite exposed two issues the batch rename un-masked (the old
emacsclient `check` was interactive and tolerated both silently):

- **`dev/dl-test.el`** — the suite loop `load`ed test files that an
  earlier-sorting sibling had already `require`d for fixture macros; in batch
  `ert-deftest` errors on "redefined (or loaded twice)". Loop now skips files
  whose feature is already `provide`d. Also cleared 4 flaky failures that were
  running against the half-loaded second copy.
- **`satan/dl-satan-patch-store.el`** — restored the `(consp commits)` guard in
  `dl-satan-patch--build-review-commands` (dropped by DE-003's unification), so
  queued jobs again return empty `:review_commands` per the tool's contract.

Suite green: 920/923, 0 unexpected, 3 skipped (real-PG / real-pi integration).

DE-003 (655b71e) removed `dl-satan-audit--read-jsonl` and `dl-satan-patch-store--json`
but left stale call-sites in broker tests and patch-worktree. Additionally, the
`defun` with `&key` lambda-list in `dl-satan-jsonl-read-file` byte-compiles to
arity `(3 . 3)` — callers with one arg hit `wrong-number-of-arguments`.

- **`dl-satan-jsonl-read-file`**: `defun` → `cl-defun` (fixes arity trap; ~15 tests
  in activity, evidence, sleipnir-doctor, percept restored)
- **broker tests**: `dl-satan-audit--read-jsonl` → `dl-satan-jsonl-read-file
  :null-object :null` (4 tests restored)
- **patch-worktree**: `dl-satan-patch-store--json` → `json-serialize
  (dl-satan-jsonl-prepare ...)` (7 tests restored)

Post-fix: 748/857 pass. 26 remaining failures pre-existing (attribute void-function,
DB socket, bough NixOS, missing docs/tick prompt).

## 2026-05-31 — SATAN: panopticon.content percept rule (DE-005 P03)

Captures now shape resonance: the evidence window carries a `:content_recent` slice (last-N articles.jsonl, metadata only — no bodies), and a new `panopticon.content` canon rule emits `content_domain:<d>` handles that admit the §S2 resonance gate automatically. Per DEC-2, this is percept-shaping only — no write into the memory store.

- **Evidence probe** (`dl-satan-memory-evidence--content-probe`): reads articles.jsonl tail via P01's lenient reader, returns hash/domain/url/title/captured_at metadata only. Wired into `assemble-with-bounds` as `:content_recent` (raw) + `:content` (sensor_status). Defcustom `dl-satan-memory-evidence-content-limit` (default 10).
- **Canon defrule** (`panopticon.content`): deduplicates captures by domain, emits `content_domain:<domain>` per unique domain. Follows `panopticon.current.app` pattern.
- **Resonance** — `panopticon.content` is NOT in the §S2 exclude list (`ctx.mode`/`time.day_week`/`cwd.project`/`cwd.file_kind` only), so capture-domain handles admit the cue automatically.
- **Tests**: 9 new ert (probe shape/empty/limit/malformed, defrule dedupe/empty/missing, admittability). 40/40 pass.

## 2026-05-31 — SATAN: content-backlog sensor (DE-005 P02)

New `panopticon_content_backlog` sensor emits attribute signals when uninspected page captures accumulate — near-clone of the curiosity (segment-backlog) sensor.

- **Sensor** (`dl-satan-sensor-content.el`): walks `articles.jsonl` via P01's lenient reader, counts captures newer than watermark, enqueues attribute payload, advances watermark. Disable switch `dl-satan-sensor-content-enabled`. Scheduled alongside curiosity in the broker probe loop.
- **DEC-5 watermark**: stores max `captured_at` string verbatim (UTC-millis-Z), NOT formatted `now()` — broker ts uses local offset (`+10:00`), so lexical comparison between formats is meaningless.
- **Tests**: 8 new ert (backlog detect, no-backlog, DEC-5 format, disabled→no-op, empty store, malformed-line skip, run-id guard, initial watermark). 31/31 pass (23 P01 + 8 new).

## 2026-05-30 — SATAN: inline recalled trace payload in the resonance block

Auto-resonance injected each prior trace as `trace_id + score + matched handles` only — to actually read the recalled context the model had to spend a `memory_show_trace` round-trip against a tight tick budget (≤4–15 tool calls). Phase 2 had cut the payload text the design intended. Closed the loop by carrying the payload inline.

- **Store — one query, no migration.** `dl-satan-memory-store-resonate` widened its SELECT to `JOIN traces t ON t.id = r.trace_id` and return a 4th column: the trace's own payload, newline/tab-collapsed server-side via the same `REPLACE(REPLACE(…, E'\n', ' '), E'\t', ' ')` as `-recent`/`-show`. That collapse is load-bearing — it keeps the payload single-line so the `\t`-split / `\n`-row parser can't misframe; the parse guard bumped `(= 3 …)` → `(= 4 …)` and each row gained `:payload`. No change to the `memory_resonate` SQL function.
- **Renderer — third line.** `dl-satan-resonance-render-block` now pushes an indented, quoted `"<payload>"` line per match, truncated to 120c (`--payload-max`, mirrors the attention-title cap) so one trace can't blow the capsule. Self-suppresses on nil/empty payload — no empty quotes. `derive` needs no logic change; `:payload` rides through `:matches` verbatim. No new framing key (rides under the existing resonance header).
- **Build fix (drive-by).** The broker test was missing `(require 'dl-satan-tools-vcs)`, so `morning`-mode manifest assembly errored `unknown tool: vcs_log` once vcs_log entered the hand-written modes — a gap the earlier vcs_log commits left red. Added the require.
- **Tests** — 2 store tests (payload returned; newline/tab collapse round-trips) against the live `satan_memory_test` DB; 3 render tests (payload line, nil/empty suppression, long-payload truncation), red→green via TDD. 151/151 across resonance/store/broker/memory-tools/context/percept; changed files byte-compile clean. No new `.el` → no `home-manager switch`.

## 2026-05-30 — SATAN: browser/tab sight in the tick capsule (+ tick-agent co-location)

SATAN reported being "blind" to browsing during agent ticks despite panopticon capturing full url/tab/title. Two independent gaps, plus the structural root cause that let one of them persist.

- **Root cause — `tick-agent` spec was stranded.** `tick-pulse` is registered in `dl-satan-tick.el` (beside `dl-satan-tick-pool`); `tick-agent` was registered 600 lines into `dl-satan-tools-atsatan.el`, next to the @satan tool *handlers* it names. Two tick modes, two files → editors patched one and missed the other (this was the second such miss in an hour — `vcs_log`, then `activity_read`). Moved the `tick-agent` mode *spec* to `dl-satan-tick.el` under `tick-pulse`; tool *handlers* stay in atsatan/patch. Dropped atsatan's now-dead `(require 'dl-satan-tick)`. Safe because the only consistency gate, `dl-satan-mode-check-tool-references`, runs at the *end* of `dl-satan.el` load (after every tool file), and `dl-satan-mode-register` stores tool-name strings without register-time validation — so naming atsatan/patch tools from tick.el resolves fine even though those files require tick.el.
- **Gap 1 — `tick-agent` couldn't query behaviour at all.** Its `:tools` override omitted `activity_read` (`recent_browser`/`recent_focus`/`today`/`current` scopes), so agent ticks had no tool to read any panopticon segment. Added `"activity_read"` (now in the moved spec; `:risk read`, no capability).
- **Gap 2 — the capsule never rendered tab detail, any mode.** The `# Percept` block emits only canon *handles*, and the browser canon rules are deliberately closed-world (MVP: a docs→non-docs `domain_transition` + one `domain_kind:docs`) — right for the *memory* layer (handles persist as scars; must stay low-cardinality), wrong as the gate for *live* sight. The rich `evidence_window.browser_segments` (full url+title) sat in `percept.json` unrendered. Added a new **`# Recent attention`** block (`dl-satan-percept-render-attention-block`) that renders `evidence_window.{focus,browser}_segments` verbatim — interleaved by `start_ts`, capped at `dl-satan-percept-attention-limit` (12), titles truncated 80c — bypassing canon entirely. Memory stays disciplined; both tick modes now *passively* see recent tabs+apps with no tool-call budget tax. Browser-app focus segments are dropped (the browser tab segments cover those spans at per-URL grain, reusing `dl-satan-memory-canon--app-surface`). Self-suppresses when empty or the header is absent; `attention_block_header` added to `~/notes/satan/system/framing.txt` (mind owns headers). Wired into `dl-satan-context--render-prompt` after the percept block.
- **Tests/verify** — 4 new render tests (interleave+url+title, browser-app-focus drop, framing-absent suppression, limit cap), red→green via TDD. Affected suites 54/54 (percept/mode/context/tick/atsatan); `check-tool-references` passes; live-data smoke against today's real segments renders ghostty-task + firefox-tab timeline correctly; changed files byte-compile clean. No new `.el`/package → no `home-manager switch`.

## 2026-05-30 — SATAN: expose vcs_log in the tick cadence modes

The git-activity sensor's `vcs_log` tool was registered and added to the five hand-written modes (morning, motd, ruminate, self-edit-mech/mind) but **not** to the two tick modes that actually run on the ~30 min cadence — `tick-pulse` (tick defaults in `dl-satan-tick.el`) and `tick-agent` (override in `dl-satan-tools-atsatan.el`). Both run `dl-satan-context-tick`, which surfaces the sensor's `project:<slug>` handles, so the model saw active-repo handles in its percept but had no `vcs_log` to drill in — the percept→tool loop the sensor was built for never closed at the prompt.

- Added `"vcs_log"` to both tick tool lists (`:risk read`, no capability — no other wiring). Verified live (`emacsclient`): `tick-pulse`, `tick-agent`, `morning` all expose it; `dl-satan-mode-check-tool-references` passes; both files byte-compile clean.
- Pre-existing, still open: the broker manifest tests are red because their temp descriptions-dir fixture lacks `vcs_log.md` (the file is present at runtime under `~/notes/satan/tools/`). Logged in `follow-ups.md`.

## 2026-05-30 — SATAN: capability enforcement moved to dispatcher (inbox/hippocampus/memory)

Follow-up off `docs/satan/follow-ups.md` — finish the Phase 0.2 capability rail. `inbox`, `hippocampus`, and `memory` tools guarded capability handler-side (or, for `memory_mark`, not at all); enforcement now lives single-point in the dispatcher via spec `:capability`, matching the `notify`/`motive-write` pattern.

- **Specs** — `:capability` added to `inbox_append` (`inbox-write`), `hippocampus_{write,overwrite,delete,rename}` (`hippocampus-write`), `memory_mark` (`memory-write`).
- **Handlers** — removed the 5 `(memq '…-write caps)` gates + their now-unused `caps` bindings. The `hippocampus_write` handler keeps `caps` for its *separate* `memory-write` auto-rule cross-ref (§10.7) — that check is unrelated to the write gate and stays handler-side.
- **Gap closed** — `memory_mark` had no gate at all: `memory-write` was declared on modes but enforced nowhere. The spec `:capability` is the first actual enforcement. New `memory/mark-capability-required` test locks it.
- **Behaviour deltas (intended)** — capability error text shifts `"mode lacks capability X"` → `"capability denied: tool T requires X"`; capability check now precedes arg-schema validation (dispatcher order). All 5 modes verified to declare the needed capability wherever the tool is allowed — no access regression.
- **Tests** — the 5 capability-required tests rerouted handler→`dl-satan-tool-dispatch` (the only place enforcement now lives); assertions unchanged (the dispatcher error still contains the capability name). Fixed a latent string-vs-symbol bug in the memory test ctx (`:capabilities ("memory-write")` → `(memory-write)`) that `memq` only cared about once a gate existed. inbox+hippo+memory+dispatcher suites 86/86 green; `dl-satan-mode-check-tool-references` passes; changed files byte-compile clean.
- **Pre-existing, out of scope** — surfaced two red broker manifest tests (`vcs_log.md` description missing from the test fixture, from the earlier git-activity commit). Logged in `follow-ups.md`, not fixed here.

## 2026-05-30 — SATAN: follow-up cleanups (jsonl reader collapse + dead branch)

Two mechanical items off `docs/satan/follow-ups.md`. No behaviour change.

- **`satan/dl-satan-tools-activity.el` / `dl-satan-memory-evidence.el`** — deleted the private `dl-satan-tools-activity--read-jsonl` (a byte-for-byte duplicate of the public `dl-satan-jsonl-read-file` lifted out in Phase 5.2 but never removed). Four call sites (activity ×2, evidence ×2) redirected to the public reader; explicit `(require 'dl-satan-jsonl)` added to both consumers rather than leaning on transitive load.
- **`satan/dl-satan-motive.el`** — removed the unreachable `(when (and (not :dormant) :dormant_reason) … nil)` branch in `dl-satan-motive-validate-for-write`; `:dormant`/`:dormant_reason` move in lockstep so it never fired. Was the only byte-compile warning in the file.
- **Tests** — motive + activity + evidence suites green (99/99, incl. the invalid-cue precedence cases that exercise the changed validator). All three files byte-compile clean.

## 2026-05-30 — SATAN: git-activity sensor (commits perceived across all repos)

SATAN had no commit-history visibility *at the prompt*. Git was read
(`--git-state`) but only fed the `project:<slug>` handle + outcome attribution, never the model; and capture was anchored to Emacs `default-directory`, so commits made via Claude in a terminal (the common case) reflected the wrong repo or nothing. Closed with a pwd-independent git-activity sensor in the existing sensor shape (current/focus/browser/bough → +git).

- **`satan/bin/satan-git-post-commit`** (new, tracked) — tiny POSIX hook. Appends one JSONL line per commit to `${SATAN_BEHAVIOUR_DIR:-~/.local/state/behaviour}/segments/git-%F.jsonl` (keyed by commit date, mirroring `focus-%F`/`browser-%F`). Row: `{repo, slug, remote, sha, subject, author, files_changed, start_ts, end_ts}`; `start_ts==end_ts` = commit instant (`%cI`, ISO8601+offset) so the existing `--filter-segments` / `--newest-segment-end` machinery consumes it verbatim. Single `printf … >> file` (one `write()`, line ≪ PIPE_BUF — concurrent commits interleave safely); every failure path `exit 0` so a commit is never blocked. JSON-escapes quotes/backslashes/tabs.
- **`satan/dl-satan-memory-evidence.el`** — new `--git-commits-status` probe (+ `--git-feed-paths`). Reuses `--filter-segments` but **inverts freshness**: commits are bursty, so a days-old newest commit is NORMAL — verdict is only `ok`/`missing`/`malformed`, **never `stale-Nm`**, and the slice is never age-dropped (the one place blind DRY against `--segments-status` would have been wrong). Reads today's feed plus yesterday's when the window crosses midnight. Adds `:git_commits` to the evidence window and `:git` to `:sensor_status`; CWD-anchored `:git_state` is left untouched for outcome attribution.
- **`satan/dl-satan-memory-canon.el`** — new `vcs.recent_commit` rule emits `project:<slug>` (origin `observed`) per repo in `:git_commits`, deduped in-rule. Deliberately **reuses the open-world `project:` namespace** — per `memory/design.md §7.1`, no grammar version bump, no migration, no `handle_weights`/sync-test churn. "Repo has a recent commit" *is* "this project is active"; sourcing it from the feed instead of `default-directory` is the whole decoupling. This is what surfaces commit activity into the model's prompt (canon `:handles` → percept).
- **`satan/dl-satan-sensor-alerts.el`** — `:git` added to `--source-order` + `--source-label`; render line gains `git=ok`/`MISSING`/`MALFORMED`. **No alert cause** (`--causes` untouched): focus/browser staleness = broken capture (page-worthy); a quiet/broken git feed = no recent commits (normal), so a stale-alert would be daily noise. Any "hook regressed" guard belongs in `sleipnir-doctor`, not the per-tick path.
- **`satan/dl-satan-tools-vcs.el`** (new) + `dl-satan.el` require + `dl-satan-mode.el` allowlists — `vcs_log` tool (`:risk read`). Runs `git -C REPO log` (authoritative full history, independent of the feed and of `default-directory`); `repo` is an abs path or a bare slug resolved against `~/dev`, `~/.emacs.d`, `~/flakes`; `limit` clamped 1..200. Added to `morning`, `motd`, `ruminate`, `self-edit-mech`, `self-edit-mind`. Description at `~/notes/satan/tools/vcs_log.md` (documents slug-acceptance so the percept→tool loop closes: the model never sees `:git_commits`, learns active repos from `project:<slug>` handles, then drills in by slug).
- **Tests** — 4 suites green: evidence 39/39 (incl. reliably-red `git-commits-bursty-old-still-ok` — old commit stays `ok`, *not* `stale`, the divergent-freshness contract; + cross-midnight, missing, malformed), canon 36/36 (deduped `project:<slug>`, origin `observed`), sensor-alerts 21/21 (render shows `git=`, degraded git dispatches **no** alert), vcs-tool 4/4 (pwd-independent log with `default-directory` elsewhere, not-found/not-a-repo errors, limit clamp). Changed files byte-compile clean. `vcs_log` registers and `dl-satan-mode-check-tool-references` passes with the new allowlists.
- **Deploy / manual caveats** — needs `git add` of the new `.el` + script then `home-manager switch` (untracked `.el` is invisible to the Nix parser; changed `.el` must rebuild into the closure). The hook itself is a **one-time manual** machine setup (like the panopticon units), `~/.gitconfig` not being Nix-managed: `ln -sf ~/.emacs.d/satan/bin/satan-git-post-commit ~/.config/git/hooks/post-commit && git config --global core.hooksPath ~/.config/git/hooks`. **CAVEAT:** a global `core.hooksPath` *disables every repo's local `.git/hooks/`* — audit `~/dev/*/.git/hooks/post-commit` before enabling.

## 2026-05-29 — sleipnir-doctor: sensor-freshness check

Regression guard for the focus-sensor staleness incident below: a tick reported `STALE (1011m)` and nothing surfaced it until a manual dig. Added a `satan-sensors` check to `lisp/dl-sleipnir-doctor.el`.

- **`sleipnir-doctor--satan-sensors`** — probes the three panopticon feeds the observer gates classification on (§S6): `current/sway.json` and today's `focus-`/`browser-` segment JSONLs. Reuses the evidence module's own `--current-window-status` / `--segments-status` (single source of truth — the doctor sees exactly what the classifier would), so both staleness (`stale-Nm`) and silence (`missing`/`malformed`) trip. Worst feed sets overall status; detail string carries per-feed status (`current=ok, focus=stale-1011m, …`).
- **`sleipnir-doctor--sensor-status->doctor`** — maps the §S6 status vocabulary to OK/WARN/CRIT. New `sleipnir-doctor-sensor-stale-crit-minutes` (default 120) escalates stale WARN→CRIT: transient capture lag stays WARN, a feed frozen for hours (the 1011m shape) reads CRIT.
- **Tests** — `lisp/test/dl-sleipnir-doctor-test.el` (first ert for the doctor): pure mapping cases incl. the reliably-red `stale-1011m → CRIT`, plus fixture-backed end-to-end (fresh→OK, missing→WARN, deep-stale focus→CRIT, mild-stale→WARN) driving the real probe code against a tmp behaviour tree with controlled mtimes / `end_ts` ages. 10/10 green; byte-compile clean (warnings-as-errors). Verified live against `~/.local/state/behaviour/` → `current=ok, focus=ok, browser=ok` (new 10-min segmentizer cadence confirmed running).

## 2026-05-29 — SATAN: fix focus-sensor false-stale + panopticon intraday cadence

Follow-on from the cold-pipeline work: a tick reported the focus sensor `STALE (1011m)`. Two distinct causes, both closed.

- **`satan/dl-satan-memory-evidence.el`** — `--newest-segment-end` selected the freshest segment by **string** comparison of ISO `:end_ts` (`string>`), which is only valid at a single UTC offset. Segment files are mixed-offset right now (the firefox plugin's `Z`→local-offset fix, panopticon `5a6499f`/0.1.1, left `Z` and `+10:00` entries side by side); a `Z` instant ahead of local wall-clock sorts *lower* as a string, so the selector could pick an older entry and report a false `stale-Nm`. Now compares by parsed `date-to-time` instant — offset-agnostic. Same bug class as the timestamptz fix above. Tests: `dl-satan-memory-evidence/newest-segment-end-{single-offset,mixed-offset,empty}` (mixed-offset is reliably red pre-fix). 172/172 intervention+observer+evidence ert green.
- **`~/flakes/modules/home/nixos/behaviour.nix`** (separate repo) — the real reason the sensor was stale: `panopticon-segmentize` ran **nightly** (`OnCalendar 03:30`), but the observer classifies an intervention against the focus/browser segments in the 30-min window *after* it fired, and ticks run intraday. Nightly derivation left segments stale all day, so the P1–P4 predicates (which gate on `sensor_status :focus = ok`) could never confirm a positive outcome. Switched the timer to `OnBootSec=2min` + `OnUnitActiveSec=10min`; the job is idempotent (atomic full rewrite of each day's segments from raw) and cheap (~640 ms), retention is a no-op until its horizon. Needs `home-manager switch` to take effect. (The firefox TZ bug itself was already fixed + deployed; it was not the staleness cause.)

## 2026-05-29 — SATAN: fix cold outcome pipeline — psql timestamptz was unparseable by `date-to-time`

Root-caused why `satan_intervention_outcomes` had stayed empty (and Doubt/Shame pinned at 0.50): not an unwired classifier, but a timestamp parse bug. `dl-satan-intervention-pending` dumps the `ts` `timestamptz` via `psql -A` as the space-separated `YYYY-MM-DD HH:MM:SS+00` form. Emacs `date-to-time` cannot parse that — the space defeats `parse-time-string`, which drops the time-of-day and mis-shifts the date ~1.5 days into the past. Every intervention therefore read `:stale` in `dl-satan-observer--maturity-state` → `classify-for-motives` returned nil → `observer-process` skipped it without persisting an outcome. The (correct, Postgres-side) pending SQL kept re-surfacing the row each tick until its own 24 h window closed, then orphaned it. The classifier wiring (every tick via `dl-satan-broker--spawn`, ~30 min cadence) and the `@satan-intervention-*` manual fallback were never at fault — the input was malformed.

- **`satan/dl-satan-intervention.el`** — new `dl-satan-intervention--normalize-pg-timestamp` (replaces the first space with `T`; nil/empty pass through). Applied at the DB-row boundary in `--row-to-intervention` (`:ts`) and `--row-to-outcome` (`:next_revisit_at`, `:classified_at`) so every downstream `date-to-time` (maturity, P1–P4 predicate windows, revisit calc) sees a parseable instant. Audited the other broker-side `date-to-time` sites — all consume broker-produced ISO-`T` strings or JSONL, not `psql -A` timestamptz columns; the intervention pipeline was the only hazard.
- **Tests** — `dl-satan-intervention/{normalize-pg-timestamp-*,row-to-intervention-ts-parses}` (the reliably-red unit: a psql-shaped cell parses to the right instant) + `dl-satan-observer/process-classifies-hours-after-emit` (end-to-end guard locking the realistic wire shape through pending → classify). The whole bug existed because every prior fixture used the `T`-separated form, so the suite was green while production never classified once. 140/140 intervention+observer ert green; `dl-satan-intervention.el` byte-compiles clean.
- **Docs** — `follow-ups.md` "Outcome pipeline cold" flipped to resolved with the root cause; `observer-classify.md` corrected (the `:stale` branch was claimed "production never lands here" — it did, for months).
- Two pre-fix orphan interventions (05-24, 05-27) are SQL-stale and left unrecovered (clean break, per refactor plan.md open-Q6); the two 05-29 rows were still in-window and classify on the next tick.

## 2026-05-29 — SATAN: T-attr-2f shipped (per-UTC-day seq Counter resumes from MAX(seq)+1) + lint baseline cleared

Closes the restart-while-disabled `(run_id, seq)` collision T-attr-2e surfaced, and clears the long-standing baseline `just lint` failure. Daemon-only changes (`~/dev/satan-attrd`) plus this doc pass; no broker code touched. **T-attr-2 is now feature-complete.**

Daemon (`~/dev/satan-attrd`):

- **`satan-attrd b4ceee1`** — T-attr-2f structural fix. `src/decay.rs` `acquire_day_counter` now resumes the per-UTC-day `Counter` from the persisted `MAX(seq)+1` for that day's `run_id` on each UTC-day rotation (which includes the first tick of a fresh process), so a mid-day restart while disabled allocates a fresh seq range instead of re-emitting `1..=N`. New `store::max_seq_for_run(pool, run_id) -> Option<i32>` + `Counter::resuming_from(prior_max)`. **Scope refinement vs the card:** resume runs lazily on the first due tick rather than literally in `DecayScheduler::new` — equivalent for the guarantee (nothing emits between construction and first tick), keeps `new()` sync/IO-free, and covers genuine day-rolls uniformly. The loud `Error::DecaySeqCollision` guard is retained as defence-in-depth. The 2e probe flips from "collides loudly" to "resumes cleanly" (`tick_restart_while_disabled_same_day_resumes_cleanly`: 2 ticks → 2N distinct rows); + 2 `Counter::resuming_from` unit tests. design-contract §17.8 "Restart-while-disabled seq collision" flipped known-gap → resolved.
- **`satan-attrd b99d8b3`** — baseline lint debt cleared. The 4 pre-existing `clippy::expect_used` denials on `clock.rs`/`decay.rs` mutex locks now recover from poisoning via `unwrap_or_else(PoisonError::into_inner)` instead of `expect` — sounder for mutexes guarding plain data (a timestamp, a `{date, Arc<Counter>}` pair) with no invariant a panicking holder could corrupt. `FakeClock`'s three sites collapse behind a private `guard()` helper. `just lint` is now green at baseline.
- 107 daemon tests green (69 unit + 38 integration). `just lint` + `cargo fmt` clean.

## 2026-05-29 — SATAN: T-attr-2e shipped (decay integration test matrix + restart-while-disabled collision guard)

Closes the four integration concerns T-attr-2d deferred (catch-up, disable-switch, restart, replay-determinism) and surfaces one design finding. Daemon-only changes (`~/dev/satan-attrd`) plus this doc pass; no broker code touched.

Daemon (`~/dev/satan-attrd`):

- **`satan-attrd c54c242`** — `tests/decay.rs`, five new tests (7 → 12 in the binary): `tick_catch_up_emits_single_event_for_multi_day_gap` (5-day gap → one −0.01 event, `days_since_last=5` preserved, delta NOT multiplied — §8); `tick_disabled_inserts_event_and_audit_but_skips_projection` (disabled → `disabled=true` event + audit row, no UPSERT, no `last_decay_at` bump; re-enable → next tick fires — §17.5/§17.8); `tick_survives_scheduler_restart_via_last_decay_at` (fresh scheduler same UTC day is a no-op, next day re-fires under a new `run_id`); `rebuild_clears_last_decay_at_so_decay_rearms` (§10.5/§17.8 — rebuild zeros `last_decay_at` so decay re-arms; replay is deterministic); and the `tick_restart_while_disabled_same_day_collision` probe. New helpers `force_target` (seed a global target to a known value / NULL `last_decay_at`) and `enable_attribute_updates` (pin the disable-switch true at test entry so a panicked predecessor can't leak `false` — the setting is shared DB state the `DECAY_TEST_LOCK` does not roll back).
- **`satan-attrd 29d6902`** — `src/error.rs` + `src/decay.rs`, restart-while-disabled seq-collision guard. The per-UTC-day `seq` Counter is in-memory and resets on restart (§17.7); on the disabled path `last_decay_at` is never bumped, so cold targets stay due and a same-day restart re-emits identical `(run_id, seq)` rows. Because the event `id` derives from `(run_id, seq)`, the primary-key constraint trips first. `tick()` now maps that violation (PK or the `(run_id, seq)` UNIQUE) to a loud, attributed `Error::DecaySeqCollision { run_id, seq }` with a `tracing::error!` naming the cause, and aborts the tick — no projection mutated, no silent corruption. Structural fix (resume the Counter from `MAX(seq)+1` for today's `run_id` on construction) deferred to **T-attr-2f**.
- 105 daemon tests green (was 100). `cargo fmt` clean. (Pre-existing `clippy::expect_used` denials on `clock.rs`/`decay.rs` mutex locks predate this PR and are untouched.)
- **Scope note (DRY):** generic rebuild skip-disabled / replay-all coverage already lives in `tests/store.rs`; the new replay test asserts only the decay-specific `last_decay_at`-reset + re-arm rather than duplicating it.

## 2026-05-29 — SATAN: T-attr-2d shipped (idle decay applies, audit emits, disable gate wired)

§15 Q7 resolved → option A (persistent `satan_attribute_settings` table broker-writes-daemon-reads). T-attr-2d lands across 2 broker commits + 5 daemon commits. Idle decay now fires daily on the 4 negative-pole attributes (shame, doubt, brooding, metamorphosis) through the same EventInsert apply pattern the source-event loop uses; disable switch threads through `MaintenanceInput.enabled` so `attribute-updates-enabled=nil` writes `disabled=true` event rows without UPSERTing the projection (per §17.5). Disable-switch / catch-up / restart / replay-determinism integration tests deferred to T-attr-2e per theme doc §"Migration sketch".

Broker commits (this repo):

- **`d7b9836`**: docs(satan) — T-attr-2d Q7 resolved → option A. `docs/satan/attributes/design-contract.md` §15 Q7 flipped resolved (strikethrough + decision text); §17.5 "Open: decay path" rewritten as normative "Decay path" pinning migration shape (`name TEXT PK, value JSONB NOT NULL, updated_at TIMESTAMPTZ`), broker write trigger (`add-variable-watcher` on `dl-satan-attribute-updates-enabled`), daemon read point (`DecayScheduler::tick` SELECT → `MaintenanceInput.enabled` → `EventInsert.disabled`), and the disabled-row apply rule (skip UPSERT + skip `last_decay_at` bump). §16 row added; `docs/satan/refactor/T-attr-2-decay.md` §"Open decision before 2d" flipped to "resolved (option A)" with rejected alternatives preserved as rationale.
- **`e9c3494`**: feat(satan) — broker write-on-toggle for `attribute_updates_enabled`. `satan/dl-satan-attribute.el` gains `--write-enabled-setting` (psql upsert on `satan_attribute_settings`) + `--on-enabled-change` (`add-variable-watcher` callback, fires only on `set` ops, swallows DB-write errors via `condition-case` so `customize-set-value` never blocks). No explicit first-load seed — the 0012 migration seeds the row at the defcustom default (`true`); `custom-set-variables` at emacs init also triggers the watcher, so operator-customised values reach the row without a separate sync step. design-contract §15 Q7 + §17.5 wording corrected to reflect the actual mechanism. 9/9 broker ert tests (was 6, +3: SQL-binding, set-only filter, error swallowing).

Daemon commits (`~/dev/satan-attrd`):

- **`satan-attrd ef1fbfd`**: feat(store) — `0012_attribute_settings.sql`. New `satan_attribute_settings(name TEXT PK, value JSONB NOT NULL, updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW())` table. Seeded with `('attribute_updates_enabled', 'true'::jsonb)`. Name-keyed JSONB so future settings reuse the surface without further migrations.
- **`satan-attrd d7f4025`**: feat(store) — `get_setting_bool` + `set_setting_bool` helpers wrapping the new table. `get_setting_bool` returns a caller-supplied default on absent row; surfaces `Error::InvalidArgument` if the JSONB `value` is not a JSON boolean. `set_setting_bool` upserts with server-side `to_jsonb($2::boolean)` cast so the stored value is JSON `true`/`false`, not a stringified boolean. 94/94 daemon tests green (was 93, +1 integration test).
- **`satan-attrd 7e69765`**: feat(decay) — tick-prep surface. `Source::Maintenance` variant (IMPLEMENTED in T-attr-2d, wire string `"maintenance"` per §17.8) + new `MaintenanceReason::IdleDecay` enum (wire string `"idle_decay"`) mirroring `HippocampusReason`/`SensorReason` shape. `build_audit_payload` flipped private → `pub(crate)` so decay can reuse the run-loop's audit-payload shape DRY. `bump_last_decay_at(pool, scope, name, now)` helper added. `lib.rs` re-exports for symmetry. 95/95 daemon tests green (+1 `maintenance_reason_round_trip`).
- **`satan-attrd f3f8260`**: feat(dispatcher) — `dispatch_maintenance(input, counter) -> Vec<EventInsert>`. Mirrors `dispatch_sensor`/`dispatch_hippocampus` shape. Per §17.8: `source="maintenance"`, `reason="idle_decay"`, delta `-0.01` (module const `DECAY_DELTA`, distinct from `decay_threshold()` which is the 24h staleness `chrono::Duration`), lower-only clamp to `0.0` with `caps_applied=[Cap::RangeClamp]`. `MaintenanceInput` carries `target: AttributeName` (one row per call) plus `days_since_last: i64` for evidence rendering; per §8 the delta is single-tick and NOT multiplied by the gap. `snapshot` carried for shape parity with sibling inputs; v1 decay does not consult it. 99/99 daemon tests green (+4 maintenance dispatcher unit tests: golden delta, floor clamp, disabled flag, evidence shape).
- **`satan-attrd 34d1386`**: feat(decay) — `DecayScheduler::tick` rewritten from T-attr-2c skeleton to full apply. Per due row: read `attribute_updates_enabled` via `get_setting_bool`, build `MaintenanceInput`, call `dispatch_maintenance`, then for each event apply the EventInsert pattern (`insert_event` → conditional `upsert_attribute` → `enqueue_audit_event` → conditional `bump_last_decay_at`). Non-bump on disabled rows is essential — bumping would silently skip the next tick after re-enable. Per §17.7 the scheduler owns its own per-UTC-day `Counter` under `std::sync::Mutex<DayCounterState>` (rotation check + Arc clone is sub-microsecond; lock never held across `.await`). Sentinel `NaiveDate::MIN` initialisation forces the first tick to rotate into a fresh counter for today's UTC date — keeps `FakeClock`-driven tests deterministic. T-attr-2c skeleton-boundary test `tick_does_not_mutate_state` replaced by `tick_applies_decay_and_bumps_last_decay_at` (golden: 0.50 → 0.49 across all 4 targets + audit inbox rows + bump) and `tick_clamps_floor_to_zero_with_range_clamp_cap` (Shame 0.005 → 0.0 with `caps_applied=["range_clamp"]`). Tests use `Scope::Global` serialised via new `DECAY_TEST_LOCK` (`Scope` is single-variant by §3 design; writers must share global). 100/100 daemon tests green.

## 2026-05-29 — SATAN: T-attr-2d pre-flight — open §15 Q7 + handover

- `docs/satan/attributes/design-contract.md`: new §15 Q7 (**Daemon-side decay-disable mechanism**) — surfaces the gap that §17.5's "broker stamps `:enabled` per source-event payload" model breaks for decay (daemon-originated events have no incoming payload). Three options with recommendation: (A) persistent `satan_attribute_settings` table broker-writes-daemon-reads (recommended); (B) `pg_notify` push channel + daemon cache; (C) skip decay-disable in v1. §17.5 amended with "Open: decay path" paragraph cross-linking to §15 Q7. §16 row added.
- `docs/satan/refactor/T-attr-2-decay.md` §"Decay application (T-attr-2d)" rewritten with the post-T-attr-2c cold-start brief: required code touchpoints (`src/types.rs`, `src/dispatcher.rs`, `src/decay.rs`, `src/store.rs`, `src/run_loop.rs`, `tests/decay.rs`), reference to the source-event apply pattern at `run_loop.rs:586-601`, the §15 Q7 decision-shape, the single-tick catch-up rule, and the per-UTC-day Counter strategy recommendation (own `Mutex<(NaiveDate, Counter)>` in `decay.rs` rather than thread the RunLoop's LRU).
- `~/dev/satan-attrd/handover.local.md` (gitignored): replaced with current 2d cold-start brief — repos at session end, blocking decision (§15 Q7), reference apply pattern, synthetic event shape (§17.8 + §5.1 widening), catch-up rule, local truisms.
- No code change. T-attr-2d is blocked on the §15 Q7 decision.

## 2026-05-29 — SATAN: T-attr-2c daemon scheduler skeleton (Clock + decay.rs, no firing yet)

- **`satan-attrd d7f8b89`**: feat(decay) — T-attr-2c. New `src/clock.rs` (`Clock` trait, `SystemClock`, `FakeClock` with `set`/`advance`) and new `src/decay.rs` (`DecayScheduler<C: Clock>` over `DECAY_TARGETS = [Shame, Doubt, Brooding, Metamorphosis]`, hourly `tokio::time::interval` with `MissedTickBehavior::Delay` per §8 single-tick rule). `check_due()` returns rows where `(now - last_decay_at) ≥ 24h OR last_decay_at IS NULL`. `tick()` logs the due set + returns count — **no firing yet** per §17.8 skeleton/firing split; T-attr-2d will extend `tick` to dispatch synthetic `(maintenance, idle_decay)` events + bump `last_decay_at`. `main.rs` `run` subcommand spawns scheduler alongside `RunLoop` via `tokio::select!`. New `tests/decay.rs` (6 tests including `tick_does_not_mutate_state` skeleton-boundary guard). 93/93 daemon tests pass.
- `docs/satan/attributes/design-contract.md`: §16 row for T-attr-2c code landing.
- `docs/satan/refactor/T-attr-2-decay.md`: PR log entry for T-attr-2c; next-step footer flipped 2c → 2d.
- `docs/satan/refactor/plan.md`: row 44 next-step pointer updated.

## 2026-05-29 — SATAN: T-attr-2b daemon schema migration + `last_decay_at`

- **`satan-attrd 58e7bba`**: feat(store) — T-attr-2b. `migrations/0011_attribute_decay.sql` adds `last_decay_at TIMESTAMPTZ NULL` to `satan_attributes` with backfill `SET last_decay_at = NOW()` on existing rows (prevents the first T-attr-2c hourly scheduler tick from synthesising a multi-day catch-up against pre-migration values, per design-contract §17.8). `AttributeRow` gains `last_decay_at: Option<DateTime<Utc>>`; `lookup_attribute` SELECT extended; `rebuild_projection` §10.5 zero-step now resets `last_decay_at = NULL` (resolves the deferral from `fb2b33d`). Migration slot renamed from contract-pinned `0008_` to `0011_` because slot 8 was already taken by `0008_outcome_inbox.sql` between 2a and 2b. 85/85 daemon tests pass.
- `docs/satan/attributes/design-contract.md`: §17.8 + §16 row updated for the slot rename + T-attr-2b code landing.
- `docs/satan/refactor/T-attr-2-decay.md`: PR log entry for T-attr-2b; next-step pointer flipped 2b → 2c.
- `docs/satan/refactor/plan.md`: row 44 next-step pointer updated.

## 2026-05-29 — SATAN: trace_marked curiosity −0.05 → −0.025 (daily-cancellation fix)

- **`satan-attrd 2d7c2b7`**: tune(dispatcher) — option (b) from the snapshot-review follow-up. `HippocampusReason::TraceMarked` Curiosity delta reduced from −0.05 to −0.025 (TINY). Sensor `segment_backlog` (+0.05) was cancelling `trace_marked` (−0.05) at identical daily cadence, pinning global Curiosity at 0 for 3 days. New daily net is +0.025 — Curiosity can now accumulate from real signal. Symmetric with Brooding (also −0.025 on trace_marked).
- `docs/satan/attributes/design-contract.md`: new §6H footnote 6 + new §16 row dated 2026-05-29 documenting the production-observation amend.
- `docs/satan/attributes/wiring-status.md`: Curiosity row updated to −0.025; new change-history row.
- `docs/satan/follow-ups.md`: snapshot-review finding crossed out as resolved; per-segment backlog scaling (option (a)) deferred to T-attr-1e-percept; long-term ceiling problem flagged as requiring T-attr-2 decay.

## 2026-05-29 — SATAN: daemon T-attr-1e catch-up commit + observability follow-ups

- **`satan-attrd e66ce17`**: feat(daemon) — T-attr-1e (hippocampus + sensor sources + `tuning.rs` extraction). Catches up the daemon-side code for work shipped broker-side in `T-attr-1d-hc` (2026-05-24) and `T-attr-1e-sensor` (2026-05-25). Both sources were already operational in production via path-flake builds of the dirty working tree; this just lands the source. 84 daemon tests green (60 unit + 8 dispatcher + 5 run_loop + 11 store). `clippy 1.95.0` newly flagged pre-existing `unwrap_err` in `rpc.rs` test mod; silenced via `#[allow(clippy::unwrap_used)]` on the test module.
- `docs/satan/refactor/T-attr-1-attribute-layer.md`: PR log's `T-attr-1e` row split into per-source sub-rows (hc + sensor ticked, percept/resonance/tool_error pending).
- `docs/satan/attributes/wiring-status.md`: typo `T-attr-1d-hc` → `T-attr-1e-hc` in source-status table; hippocampus reason count corrected from 5 to 6 (`trace_marked` was added with sensor work for Curiosity decay).
- `docs/satan/follow-ups.md`: new sections capturing two observability findings (curiosity-cancellation tuning, outcome-pipeline cold) and two daemon contract pins (audit-payload `{}` rendering, non-idempotent rebuild) that should be resolved before T-attr-1d ships.

## 2026-05-28 — keys: lift `crux-open-with` into `my-file-map`

- `core/dl-keymap.el`: bind `crux-open-with` at `C-c f o` (mnemonic: file → open external).
- `editing/dl-crux.el`: drop the foreign `C-c O` global-set-key flagged by `my-policy-lint` (`foreign-command`). Pointer comment left behind.

## 2026-05-28 — org-gcal: working end-to-end

- `org/dl-org-gcal.el`: rewrite. Stray outer paren removed (made the whole file one unevaluable list). `org-gcal-fetch-file-alist` switched from quote to backquote so `my/op-read` actually fires. Added `(org-gcal-reload-client-id-secret)` in `:config`. `:commands` defer so the three `op read` calls don't block startup with a biometric prompt.
- Pin `oauth2-auto-plstore` to a fully expanded absolute path. Default uses unexpanded `user-emacs-directory` (literal `~`), tripping oauth2-auto's `insert-break-on-secret-entries` guard on some call paths.
- Workaround for oauth2-auto's first-save crash: pre-create an empty parseable plstore (`(plstore-open … plstore-save)`). The guard calls `file-equal-p`, which returns nil when either path doesn't exist, so the very first `plstore-save` always misfires and leaves a half-written file (envelope written, secrets unencrypted).
- `epg-pinentry-mode 'loopback` + `plstore-cache-passphrase-for-symmetric-encryption t` — no pinentry binary or GPG key on this host; passphrase is entered in the minibuffer and cached for the Emacs session.
- `init.el`: uncomment `(require 'dl-org-gcal)`.
- Outside-repo: `~/.gnupg/gpg-agent.conf` set to `allow-loopback-pinentry` (gpg 2.4 requires the agent opt-in even when the client requests loopback).

## 2026-05-28 — lambda-line: org-clock modeline arity bug

- `core/dl-modeline.el`: `:override` advice on `lambda-line-org-clock-mode`. Upstream calls `lambda-line-compose` with 4 args instead of 5 (missing `secondary`, stray `nil` inside the tertiary `concat`), so every redisplay errors and floods `*Messages*` whenever `org-mode-line-string` is non-nil (e.g. an active `org-clock-in`). Override matches the `lambda-line-prog-mode` shape: tertiary `nil`, clock string + position rolled into secondary. Upstream lambda-line @ `ba749fb`.

## 2026-05-27 — Bough snapshot adapter

- `apps/dl-bough.el`: elisp adapter exporting org-mode headings and denote notes as Bough snapshot JSON (version 1 contract).
- **Org export** (`my/bough-export-org`): uses org-ql with configurable predicate (default `(todo)`), extracts org-id (auto-creates if absent), title, status, tags, scheduled/deadline, file locator, outline path. Defaults to `my/org-agenda-combined-files`.
- **Denote export** (`my/bough-export-denote`): enumerates `denote-directory-files`, extracts identifier, title, keywords, file locator. All items get `kind_hint: "ref"`.
- **Sync commands** (`my/bough-sync-org`, `my/bough-sync-denote`): export + async `bough sync import`.
- **After-save hook**: opt-in via `dl-bough-auto-export` — re-exports org snapshot when saving in-scope files.
- **Keybindings**: `C-c n m b` (bough export org), `C-c n m B` (bough export denote).
- Self-contained — no SATAN dependency. Uses `json-serialize` with plist construction.

## 2026-05-25 — SATAN: T-attr-1e-sensor — wire Curiosity + Hunger to real signals

- **ATTR_ORDER expanded from 7 to 8**: Curiosity added to the daemon's dispatch loop. All delta tables widened from `[f64; 7]` to `[f64; 8]` (leading 0.0 for Curiosity in existing tables). Existing behaviour unchanged.
- **New `tuning.rs`**: centralised magnitude constants (TINY/SMALL/MEDIUM/HIGH), confidence multipliers, and all delta tables (outcome, hippocampus, sensor). `dispatcher.rs` delegates to tuning module — knobs discoverable in one file.
- **Hippocampus `trace_marked` reason**: Curiosity −0.05 + Brooding −0.025 on trace persistence via `dl-satan-memory-store-mark`. All 3 callers (observer, manual mark, memory_mark tool) emit automatically. Soft-fail; only fires during active SATAN runs (broker sets `dl-satan-memory-store--current-run-id`).
- **Sensor source implemented** (`Source::Sensor` flipped to `is_implemented`): 3 reasons — `segment_backlog` (Curiosity +0.05), `typing_active` (Hunger +0.05), `typing_idle` (Hunger +0.025). No confidence weighting, no revision. Daemon: `SensorReason` enum, `dispatch_sensor`, `SensorPayload` parser + router arm. Broker: `dl-satan-attribute-build-sensor-payload`, audit validator widened.
- **Curiosity probe** (`dl-satan-sensor-curiosity.el`): counts panopticon focus segments newer than last-inspected timestamp. Emits `segment_backlog` signal. State file at `~/.local/state/satan/sensor-curiosity.json`.
- **WPM probe** (`dl-satan-sensor-wpm.el`): reads `~/notes/satan/log/wpm/YYYY-MM-DD.tsv`, classifies last 10 minutes as active (>50% active_seconds) or idle (<5%). Emits on state transitions only. State file at `~/.local/state/satan/sensor-wpm.json`.
- **Broker wiring**: both probes called in prepare phase after sensor-alerts-check, wrapped in `condition-case` for soft-fail.
- **Design contract** amended: §6S (sensor source), §6H trace_marked row, §5 sensor flipped to implemented, ATTR_ORDER expansion noted.
- Daemon unit tests: 50→60, all green.

## 2026-05-25 — sleipnir-doctor: SATAN + Patch + Org health checks

- `lisp/dl-sleipnir-doctor.el` expanded from 2 checks (server uptime, LSP) to 16 via a registry pattern. Each check is a named function, individually callable via `M-x sleipnir-doctor-check-one`, wrapped in `condition-case` so a crash produces its own CRIT entry without aborting the report.
- **SATAN runtime** (6 checks): mode-registry consistency, daily token budget (% used), memory DB connectivity (psql), today's run success rate, consecutive failure streak, last tick age.
- **Patch pipeline** (4 checks): runner enabled/active, queue depth, proposals awaiting review, active worktree count.
- **Org / Notes** (4 checks): notes root exists, org-roam DB age (falls back to `dl-notes-root/.org-roam.db` when org-roam not loaded), agenda file count, inbox file exists.
- No new dependencies — SATAN/org modules accessed only through `fboundp`/`boundp`/`featurep` guards with `declare-function` for clean byte-compilation.

## 2026-05-24 — SATAN: progressive token exhaustion + resilience

- **Progressive tier degradation** (harness `runloop.py`): 3-tier tool withdrawal system driven by token budget consumption. Tier 0 (full tools) → Tier 1 at 70% (drop survey tools: docs, activity, hippocampus_grep) → Tier 2 at 85% (drop reads: org, bough, memory_resonate, patch, proposal) → Tier 3 at 95% or 85% timeout (satan_final only). System messages injected on each transition. Replaces binary `warned` boolean.
- **Error classification** (harness `runloop.py`): `classify_error()` heuristic categorises provider exceptions (rate_limit/auth/server/timeout/unknown). `emit_error` now emits structured JSON payload with class, detail, token totals, turn count.
- **Crash context event** (broker `dl-satan-broker.el`): `dl-satan-broker--crash-context` emits a `crash-context` audit record on every non-done terminal path (failed/timed-out/invalid-protocol). Payload: status, tool_calls_done/budget, budget_tokens, max_budget_tokens, elapsed/timeout, pre_spawn_completed.
- **Hard backstop** (broker + harness): `SATAN_MAX_BUDGET_TOKENS` env var (default 1M) provides absolute token ceiling independent of tier system. Fires before any tier check.
- **Tank integration** (`dl-satan-tank.el`): LAST RUN section shows tier transitions and crash-context diagnostic block on non-done runs. Event summaries render `tier_changed` and `crash-context` events.
- **Budget/timeout revision** (`dl-satan-mode.el`): morning 300K/1800s (was 100K/90s), motd 100K/1800s (was 80K/45s), self-edit-* 300K/1800s (was 100K/180s), ruminate 400K/1800s (was 180s). Tool-call budgets set to 100 across the board (effectively uncapped, machinery retained).
- **Design doc** (`docs/satan/resilience-design.md`): §2 rewritten for token-only triggers (rate-limit deferred — 0/91 recent failures were 429s). All open questions resolved.
- Tests: harness 52 (was 39), broker 20, tank 27, audit 13 — all green.

## 2026-05-24 — SATAN: T-attr-1d-hc — hippocampus → attribute signals

- `docs/satan/attributes/design-contract.md` — new §6H: hippocampus source added to §5 reserved + implemented sources.  Reason enum (written/overwritten/deleted/renamed/searched), delta table (tiny=0.025: Brooding down on mutating ops, Shame down on overwrite/delete, Suspicion up on empty grep), no confidence weighting (§6H.3), no revision semantics (§6H.4), evidence shape (tool_name + filename, §6H.5), payload shape with explicit `source` field (§6H.6), self-manipulation analysis (§6H.7).
- `satan/dl-satan-audit.el` — `"hippocampus"` added to both reserved + implemented source lists.  New `dl-satan-audit-attribute-hippocampus-reasons` constant (5 reasons).  `dl-satan-audit--attribute-reasons-for-source` gains hippocampus branch.  New `dl-satan-audit--validate-attribute-hippocampus-evidence` (requires `evidence.tool_name` + `evidence.filename`).  `dl-satan-audit--validate-attribute-delta-applied` dispatches evidence validation by source (was outcome-only).
- `satan/dl-satan-attribute.el` — existing `dl-satan-attribute-build-outcome-payload` now stamps `source: "outcome"` explicitly.  New `dl-satan-attribute-build-hippocampus-payload` (§6H.6 shape).  `dl-satan-attribute-enqueue-outcome` renamed to `dl-satan-attribute-enqueue` (old name kept as defalias).
- `satan/dl-satan-tools-hippocampus.el` — new `dl-satan-tools-hippocampus--emit-attribute-signal` helper (mirrors `--cross-ref` soft-fail pattern).  Wired into all 5 emit points: write→written, overwrite→overwritten, delete→deleted, rename→renamed, grep(0 matches)→searched.  Gates on `dl-satan-attribute-updates-enabled`.
- Sibling daemon (`~/dev/satan-attrd`): `types.rs` adds `Source::Hippocampus` (implemented), `Source::supports_revision()` method, `HippocampusReason` enum (5 variants).  `dispatcher.rs` adds `hippocampus_base_deltas` (§6H.2 table), `HippocampusInput` struct, `dispatch_hippocampus` (no confidence weighting, caps still apply) + 8 unit tests.  `run_loop.rs` adds source-routing (`parse_inbox_payload` checks `source` field, backwards compat: absent → outcome), `HippocampusPayload` struct + parser, `process_outcome_row` routes by `InboxPayload` variant.  `lib.rs` re-exports new types.  No migration needed.  Daemon unit tests 42→50 (all green); integration tests require DATABASE_URL.
- Tests: broker ert 32/32 (was 26), daemon unit 50/50.
- `docs/satan/attributes/hippocampus-attribute-signals.md` — status draft → contracted; open questions resolved.

## 2026-05-24 — SATAN: hippocampus v1 — full tool suite + ruminate mode

- `satan/dl-satan-tools-hippocampus.el` — expanded from write-only to 7 tools: `hippocampus_list` (read, newest-first entries), `hippocampus_read` (body by filename, path-sandboxed), `hippocampus_write` (existing, denote org + cross-ref), `hippocampus_overwrite` (replace body, keep metadata), `hippocampus_delete` (remove file), `hippocampus_grep` (rg-backed search), `hippocampus_rename` (update slug + #+title).  All mutating tools require `hippocampus-write` capability; read tools are tool-allowlist-only.
- `satan/dl-satan-mode.el` — all hippocampus tools wired into all 5 modes (morning, motd, self-edit-mech, self-edit-mind, ruminate).  `hippocampus-write` capability added to modes that lacked it (motd, self-edit-mech, self-edit-mind).  New `ruminate` mode: inward-facing memory upkeep — hippocampus + memory + motive_read + bough_read + notes_recent + docs.  No org, no notify, no proposals, no sway.  Output handler stages everything, auto-applies nothing.
- `satan/dl-satan-output.el` — `dl-satan-output/ruminate` added (all actions staged for review).
- `~/notes/satan/prompts/ruminate.txt` (new) — prompt guiding memory review, consolidation, staleness detection, and attribute-driven prioritisation (high Shame → review past mistakes; high Curiosity → scan for gaps; high Brooding → trace chains).
- `~/notes/satan/tools/` — all 7 hippocampus tool descriptions rewritten with when/why/when-not guidance, hippocampus-vs-memory_mark distinction, and encouragement toward active use.  Key framing: hippocampus is the *knowledge* surface (editable prose, recalled by list/grep); memory_mark is the *moment* surface (evidence-grounded, recalled by resonance).
- Tests: 25 ert in `dl-satan-tools-hippocampus-test.el` (18 new for list/read/overwrite/delete/grep/rename + 7 existing write/cross-ref).  All 25 green.  Broker test description alists updated for new tool names.

## 2026-05-24 — SATAN: T-attr-1d — capsule attribute bar render (broker-only)

- `satan/dl-satan-attribute-render.el` (new) — snapshot query (`SELECT name, value FROM satan_attributes WHERE scope='global'`) via existing `dl-satan-attribute--query` psql plumbing + bar block renderer.  Render shape: `█/░` 10-wide bars with 2-decimal numeric right of bar, fixed vocabulary order from design-contract §2 (curiosity → metamorphosis), `:friction` mapped to public label "Cruelty".  When `dl-satan-attribute-updates-enabled` is nil, renders single `"Attributes: disabled"` marker per §9.  Block self-suppresses (returns nil) on query failure or missing framing key.
- `satan/dl-satan-context.el` — attribute block wired into `dl-satan-context--render-prompt` between `# Now` and `# Percept` (metabolism before perception).  `dl-satan-context--finalize-prompt` fetches the attribute snapshot once and attaches it to the bundle as `:attributes` before rendering, so every mode (morning, motd, tick, self-edit) gets the block without per-mode duplication.
- `docs/satan/attributes/capsule-contract.md` (new) — pins 5 open shape choices from handover: (1) direct SELECT, no daemon RPC; (2) `"Attributes: disabled"` single-line marker; (3) `█/░` bars, 10-wide, numeric, vocabulary order; (4) `caps_applied` silent (audit-only); (5) after Now, before Percept.
- `satan/test/dl-satan-attribute-render-test.el` (new) — 21 ert: bar rendering (zero, full, half, banker's rounding at 0.5, clamp above/below), row formatting + alignment, vocabulary order + `:friction→Cruelty` mapping, block entry point (all-zero, mixed, disabled, disabled-nil-snapshot, nil-suppression, missing-framing-key), snapshot parse (happy, empty, nil), boundary values (0.0/0.1/0.9/1.0).  All 21 green.  Gate suites unchanged: audit+attr+listener 88/88, patch-listener 12/12+1 skipped, intervention 18/18, daemon 68/68.

## 2026-05-24 — SATAN: T-attr-1c (slice 2/2) — wiring (broker enqueue + daemon run loop + broker LISTENer)

- `docs/satan/attributes/design-contract.md` §17.1 — broker now owns the daemon → broker audit-event LISTENer; sentinel reports subprocess death via `notifications-notify` with critical urgency, mirroring `dl-satan-patch-listener.el`.  New defcustoms `dl-satan-attribute-listener-enabled` (default `t`) and `dl-satan-attribute-listener-notify-app` (default `"SATAN"`) gate + name the listener.  §17.3 expanded with: queue table DDL (`satan_outcome_inbox` broker→daemon, `satan_audit_inbox` daemon→broker) + `pg_notify` channel naming; the broker → daemon outcome payload v1.0 shape (verbatim JSON); `schema_version` major-rejection rule (consumers reject unknown major, accept minor differences forward-compatibly); single-thread run-loop concurrency note (no `SELECT FOR UPDATE` needed in v1 because dispatch is serialized; flagged as a future multi-worker concern).  §17.4 expanded with the **reject reply transport** — new `satan_audit_replies` table + `satan_audit_reply` channel; rejects-only (broker simply DELETEs the inbox row on accept, INSERTs a reply row + NOTIFYs on reject).  §16 change-history gains a 7th row recording these pins.
- `satan/dl-satan-attribute.el` (new) — broker-side surface that classify-path calls after writing the audit + outcome projection rows.  Owns `dl-satan-attribute-updates-enabled` defcustom (§9 disable switch; default `t`), the v1.0 payload builder (`dl-satan-attribute-build-outcome-payload`), and the enqueue helper (`dl-satan-attribute-enqueue-outcome`) — INSERT INTO `satan_outcome_inbox` + `pg_notify('satan_outcome_inbox', id::text)` in one transaction.  JSON serialiser preserves `t`/`:false` for round-trip JSON booleans (had to special-case before reaching the `symbolp → symbol-name` branch).
- `satan/dl-satan-attribute-listener.el` (new) — postgres `LISTEN satan_audit_inbox` subprocess.  On notify: atomic claim via `UPDATE … RETURNING`; `schema_version` major check (rejects mismatched major like `"2.0"`); audit-validator pass via `dl-satan-audit-validate-attribute-event` (§5.1 — already shipped in T-attr-1b); on accept appends one `attribute.delta_applied` line to the matching run's `transcript.jsonl` (located via `dl-satan-broker-locate-run-dir`, parsed from the payload's `id` field `<run-id>.attr<NNN>`); on reject INSERTs `(inbox_id, error_msg)` into `satan_audit_replies`, DELETEs the inbox row, NOTIFYs `satan_audit_reply <inbox_id>` — daemon LISTENs that channel + logs at `tracing::error!` per §17.4 log-and-drop.  Sentinel-death notification path mirrors patch-listener verbatim.  Auto-starts when `dl-satan-attribute-listener-enabled` is `t`.
- `satan/dl-satan-intervention.el` — classify path now also enqueues onto `satan_outcome_inbox` after the audit-record + outcome UPSERT.  New helper `dl-satan-intervention--enqueue-attribute-outcome` looks up the intervention row for cue-dimension fields (`:kind`, `:related_motive_id`, `:cue_handles`), builds the v1.0 payload, calls the enqueue helper; failures log via `message` and do NOT signal — the broker's audit + outcome projection write already succeeded, and a missed enqueue is recoverable.  `(require 'dl-satan-attribute)` added.
- `satan/dl-satan.el` — `(require 'dl-satan-attribute-listener)` added so the listener auto-starts alongside `dl-satan-patch-listener` on broker init.
- Tests: 17 new ert across `satan/test/dl-satan-attribute-test.el` (7 — payload builder, disabled-flag stamping, JSON round-trip, --prep-value normalisation) + `satan/test/dl-satan-attribute-listener-test.el` (10 — happy-path accept writes transcript line + deletes inbox row, reject on schema-major mismatch, reject on validator out-of-range failure, race-when-already-claimed is no-op, filter dispatches on known channel + ignores unknown + buffers partial lines, --check-schema unit, run-id extraction from payload).  All 17 green.  Sibling audit + audit-attribute suites re-run 71/71 — no regression.
- Sibling daemon commit (`~/dev/satan-attrd`): migrations `0008_outcome_inbox.sql` + `0009_audit_inbox.sql` + `0010_audit_replies.sql`; `src/rpc.rs` (constants for channels + payload schema, `enqueue_audit_event` helper, `check_schema_major` validator, `with_schema_version` payload stamp + 6 unit tests); `src/run_loop.rs` (`RunLoop` struct, single-thread loop using `tokio::select!` between `PgListener`s on outcome + reply channels, per-run `LruCounterMap` capacity 64 with `tracing::info!` on evict per §17.7, outcome payload parser, snapshot + projection read from `satan_attributes`, `attribute.delta_applied` payload builder, daemon-side prior-classification derivation from latest event's `reason` column, drain-on-startup for both inboxes + 7 unit tests); `src/main.rs` gains `satan-attrd run` subcommand.  Daemon test count rises 46 → 65 (41 unit + 8 dispatcher integration + 5 run_loop integration + 11 store integration).  Broker `dl-satan-audit-*` + new attribute ert at 88/88 (was 71/71).

## 2026-05-24 — SATAN: T-attr-1c (slice 1/2) — daemon dispatcher + contract pin

- `docs/satan/attributes/design-contract.md` — two pre-implementation pins absorbed into §17.  §17.4 gains an **RPC error policy on validator reject**: daemon logs at `ERROR` and drops the event, no retry — validator rejects are deterministic and retry burns cycles on contract violations; transport-layer errors remain retryable with backoff and are out of scope for this slice.  §17.7 (new) **Per-run Counter eviction**: bounded LRU at capacity 64 with `tracing::info!` on evict; explicit `intervention.run_ended` broker signal deferred until the LRU heuristic is shown wrong.  §16 change-history gains a 6th row recording these pins.  `metadata.status` flips **draft → merged** per the T-attr-1a precedent (contract becomes canonical with first code-bearing implementation PR; the daemon dispatcher is that PR).
- Sibling daemon commit ships the dispatcher + tests + the flake fix that surfaced during 1c preflight (`tests/store.rs::prior_event_lookup_uses_expression_index` was choosing Seq Scan over the expression index because the table had only 3 rows; bulk-seed 500 events + ANALYZE before EXPLAIN makes the planner pick the index reliably).  See `~/dev/satan-attrd` commit log for the daemon side: `src/dispatcher.rs` (pure §6 base-delta table + §6.1 confidence weighting with upper-bound magnitude clamp only + §6.3 pre-dispatch snapshot + §7 caps + `dispatch_outcome` first-emit + `dispatch_revision` against actually-logged prior deltas + `gather_prior_actuals` helper closing around `lookup_prior_events_by_intervention`); `tests/dispatcher.rs` (8 integration covering the §12 surface — golden 15-case delta table across 5 classifications × 3 confidences, multi-attribute snapshot freezing, range_clamp upper + lower via integration round-trip, disable-switch propagation with prior-actual filtering, revision-against-actually-logged-prior-delta with cap-clamped seed, revision chain summing prior_actuals, `friction_cap` direct-store forward-compat fixture); `src/dispatcher.rs` carries 16 unit tests for the pure-function core.  Daemon test count rises from 22 → 46 (27 unit + 8 dispatcher integration + 11 store integration).  Broker `dl-satan-audit-*` ert sister suites unchanged at 71/71.
- No broker (elisp) code in this PR.  T-attr-1c slice 2 (wiring) is the next sub-PR: broker writes outcome events to a PG queue table (`pg_notify` channel) and runs an RPC inbox handler that calls `dl-satan-audit-validate-attribute-event` before `dl-satan-audit-record`; daemon gains `satan-attrd run` (LISTENer + per-run Counter LRU) + `src/rpc.rs` (daemon→broker NOTIFY on a `satan_audit_inbox` channel); broker gains `dl-satan-attribute-updates-enabled` defcustom + forwards the switch state in every source-event payload.

## 2026-05-23 — SATAN: T-attr-1b broker side — `attribute.delta_applied` audit validator

- `satan/dl-satan-audit.el`: new section "Attribute event validators (T-attr-1b)" widens the broker's audit-record validator for the `attribute.delta_applied` event the `satan-attrd` daemon RPCs back to the broker for transcript write (per design contract §17.4).  Closed-set defconsts live in lockstep with the daemon's typed enums in `~/dev/satan-attrd/src/types.rs`: `dl-satan-audit-attribute-events` (one event in v1); `dl-satan-audit-attribute-names` (8 attribute names); `dl-satan-audit-attribute-scopes` (only `"global"` in v1); `dl-satan-audit-attribute-sources-reserved` (6 reserved sources); `dl-satan-audit-attribute-sources-implemented` (only `"outcome"` today — widens per T-attr-1e source); `dl-satan-audit-attribute-outcome-reasons` (5 outcome reasons); `dl-satan-audit-attribute-caps` (`friction_cap` + `range_clamp`).  Two new helper predicates: `dl-satan-audit--iv-require-number-in-range` (closed numeric interval) and `dl-satan-audit--iv-require-bool` (`t` / `:false` JSON boolean).  `dl-satan-audit--validate-attribute-delta-applied` enforces every key in the contract §5 payload shape: `id` non-empty string; `scope`/`name` against their closed sets; `old`/`new` ∈ `[0, 1]`; `delta` ∈ `[-1, 1]` AND `|delta − (new − old)| < 1e-9` (float-epsilon coherence); `(source, reason)` pairing with reserved-but-unimplemented rejection per §5.1; `evidence` is an object; for `source=outcome` `evidence.confidence` ∈ `low|medium|high` + `evidence.intervention_id` non-empty + `evidence.classification` from the existing `dl-satan-audit-intervention-classifications` set; `caps_applied` is an array of strings drawn from the cap closed set; `disabled` is JSON boolean.  Dispatcher `dl-satan-audit-validate-attribute-event` routes by event name and returns nil on success / error string on failure (mirrors the existing `validate-intervention-event` shape).
- `satan/test/dl-satan-audit-attribute-test.el` (new file): 26 ert covering the validator end-to-end.  Six happy-path tests (canonical contradicted; worked-with-tiny-shame-delta exception; each of 5 outcome reasons; each of 8 attribute names; disabled=t; caps_applied populated).  Eight closed-set rejections (unknown event; unknown source; each of 5 reserved-but-unimplemented sources; unknown attribute name; unknown scope; bad source/reason pairing; unknown cap name).  Four range + coherence cases (`old` > 1; `new` < 0; `delta` does not match `new − old`; float-epsilon delta still accepted).  Eight required-key cases (missing `id` / `disabled`; missing each of `evidence.confidence` / `evidence.intervention_id` / `evidence.classification`; bad `confidence` enum value; bad `classification` enum value; bad `disabled` type; non-array `caps_applied`).  All 26 green.  Sister suites (`dl-satan-audit-test.el` + `dl-satan-audit-intervention-test.el`) re-run 45/45 — no regression.
- No callers yet.  The daemon's RPC-event-back path (which will invoke this validator before `dl-satan-audit-record`) lands with T-attr-1c.  T-attr-1b ships the validator on its own so the audit boundary is in place before the dispatcher writes its first event.
- Sibling daemon commit: `~/dev/satan-attrd` commit `d46d93b` (`feat(store): T-attr-1b — migration + store + rebuild driver`) ships the daemon half — migration `0007_attributes.sql`, store API, per-run seq counter, projection rebuild driver, 22 tests (11 unit + 11 integration against `satan_memory_test`).  The contract `metadata.status` will flip `draft → merged` in the next contract amendment alongside T-attr-1c.

## 2026-05-23 — SATAN: T-attr-1 locus pivot — attribute layer extracted into `satan-attrd` (Rust daemon)

- New project at `~/dev/satan-attrd` (initial commit `d8a6a10`) — first Rust beachhead extracted from `~/.emacs.d/satan/` per the [extraction policy](docs/satan/refactor/extraction-policy.md) §"Active beachhead".  Scaffold only: `Cargo.toml` (`sqlx` + `tokio` + `thiserror` + `tracing` + `chrono` + `serde`, lifted from `~/dev/vk/db`'s deps), single-binary crate (no workspace), `src/main.rs` + `src/lib.rs` stubs, `migrations/` skeleton, `Justfile` lift of bough's lint/format/test gates (`-D clippy::unwrap_used -D clippy::expect_used`), `README.md` / `HANDOVER.md` / `AGENTS.md` pointing back into this repo for the design substance.  No schema or store code yet — T-attr-1b is the first code-bearing slice.  `cargo check --offline` green; rustfmt + clippy deferred to the devshell.
- `docs/satan/attributes/design-contract.md` — **language-neutralising pass**: §4 / §4.2 / §4.3 / §5 / §5.1 / §9 / §10 / §11 / §12 rewritten to remove elisp-specific implementation references (`dl-satan-attribute-store.el`, `dl-satan-attribute-dispatcher.el`, `dl-satan-attribute-rebuild`, `dl-satan-audit--validate-record`, `dl-satan-attribute-updates-enabled`, `dl-satan-attribute-confidence-weights`, specific ert file names) and rephrase in broker / daemon role-language.  Test surface (§12) split by side — daemon owns Rust integration tests against live Postgres; broker keeps elisp ert for the audit-validator widening + capsule render.  Forward references to broker UX (`my/satan-attribute-zero`, `my/satan-mark-intervention-*`) intentionally kept — they describe broker-side surfaces, not daemon implementation.  Substantive content (schema verbatim, deltas, caps, rebuild semantics, A3 boundary, multi-attribute pre-dispatch snapshot, revision-against-actual-prior-deltas) carries over unchanged.
- `docs/satan/attributes/design-contract.md` §17 (new) — **Implementation locus + pinned daemon design choices**.  Adopts (a) daemon writes `satan_attribute_events` row then RPCs `attribute.delta_applied` back to the broker for transcript writing (preserves "transcript.jsonl is audit truth"); (b) PG queue table + `pg_notify` between broker and daemon (matches the existing patch-listener pattern); (c) daemon-side disable-switch check (broker forwards `attribute-updates-enabled` state in the source-event payload; daemon writes `disabled: true` events without UPSERT — `--include-disabled` rebuild can replay them).  These three were previously pinned only in the theme-doc amendment + `extraction-policy.md`; they are now contract-level.  §17.1 / §17.2 split owns the broker/daemon line normatively; §17.6 documents forward references to broker UX.
- `docs/satan/attributes/design-contract.md` §16 — new change-history row (5th) records the locus pivot + language-neutralising pass.  `metadata.status` stays `draft` for one more row; flips to `merged` when T-attr-1b's first code-bearing PR lands (T1.5a precedent — contract becomes canonical with first impl PR).
- `docs/satan/refactor/T-attr-1-attribute-layer.md` — `Implementation locus` section rewritten: locus-split table extended to call out the broker-side audit-validator widening that lands alongside daemon-side T-attr-1b; scaffolding-source line points at `~/dev/vk/db` (bough's data crate) with the scaffold-commit pointer (`d8a6a10`); "Contract status" sub-section added clarifying that the language-neutralising pass is done + `draft → merged` flips on first code-bearing T-attr-1b PR; three-pinned-choices block cross-links to contract §17.3–§17.5.  PR-log: T-attr-1a ticked (substance settled); T-attr-1b entry expanded with the daemon-side store API + broker-side validator widening split.
- `docs/satan/refactor/extraction-policy.md` §"Active beachhead" — status line updated to reflect scaffold landing (commit `d8a6a10`) + locus pivot timing; contract reference rewritten in past tense ("was language-neutralised") with the §17 pointer.
- No broker (elisp) code in this PR.  T-attr-1b will ship the daemon's migration + store + integration tests in `~/dev/satan-attrd`, alongside this repo's audit-validator widening for `attribute.delta_applied`.

## 2026-05-23 — SATAN: T-attr-1a — attribute layer design contract + theme doc (doc only)

- `docs/satan/attributes/design-contract.md` (new): 16-section design contract for the attribute layer (the first theme in the attributes core tranche per `refactor/plan.md`).  Defines: vocabulary (8 attrs, internal `:friction` / public Cruelty); scope (`global` only — see global-by-architecture below); storage (`satan_attributes` projection + `satan_attribute_events` append-only log per brief §5, plus `seq INTEGER` UNIQUE `(run_id, seq)` for deterministic intra-run replay ordering + `disabled BOOLEAN` for rebuild-filter); event schema (`attribute.delta_applied` in audit transcript with closed-set `source` + per-source `reason` enums); outcome→delta map (5 classifications × 7 affected attributes; magnitudes `small=0.05 / medium=0.15 / high=0.30` per brief §6 with `worked shame` exception at −0.025 + `contradicted suspicion` reduced to −0.05 + `harmful suspicion` held at 0 — rationales in §6 footnotes 1–5); confidence weighting (`0.5 / 1.0 / 1.5`, upper-bound clamp only — `:low` produces sub-`small` deltas by design; operator-tunable via `dl-satan-attribute-confidence-weights` defcustom); revision handling against **actually-logged** prior deltas (lookup via `evidence_json->>'intervention_id'`, indexed; revision chains sum across the chain — theoretical-minus-theoretical would over-/under-reverse under caps); multi-attribute pre-dispatch snapshot (one source event's deltas are order-independent because cap inputs `(doubt, shame)` freeze at event start); caps (`friction_cap` per brief §1 invariant `friction ≤ 1 - doubt - shame`, positive-only — outcome-only v1 never raises friction so the cap needs synthetic test fixtures; `range_clamp` to `[0,1]`); disable switch (`dl-satan-attribute-updates-enabled` defcustom — `t` emits + UPSERTs, `nil` emits `disabled: true` + skips UPSERT + capsule renders `Attributes: disabled` not stale frozen values); rebuild semantics (projection derivable from event log by `ORDER BY ts, run_id, seq` — `id`-string lexicographic sort is broken; default-replay skips disabled events for actual history, `--include-disabled` reconstructs hypothetical post-rollback state); A3 boundary (inherits T1.5b's break, no new sanction); validator widening (per-source reason pairing + required `evidence.confidence` for outcome + reserved-but-unimplemented source rejection); explicit "v1 deliberately does not implement" list (pattern-specific attribute vectors; pattern records themselves; automatic decay; cross-attribute cascade rules; repeated-neutral micro-Shame; `harmful→suspicion` penalty; non-zero baselines; Brooding force-action guardrail; sources beyond outcome; manual override path; model-side `attribute_get` tool; maintenance/decay/manual events with no run-id); 6 open questions (confidence-weight magnitudes; decay schedule; episode-local additive bias scope; event-source-vs-upsert authority; repeated-neutral; evidence-json shape).
- `docs/satan/attributes/patterns_attributes.design_note.md` (new): the architectural rebuttal to "global Shame/Suspicion is too blunt — make them scoped" — global attributes ARE the right architecture, not a v1 narrowing.  The compact principle: "Global attributes are the animal's metabolism. Patterns are its prey-shapes. Scars are where the prey bit back."  Pattern-specific consequences (cooldowns, success/ignored/contradicted/harmful counters, scars, intrusion ceilings, preferred interventions, blocked interventions) live in **pattern records** — a separate, parallel structure governed by its own theme.  Outcomes update both surfaces; the attribute layer never grows a `pattern × attribute` matrix and never gets `hypothesis:<id>` scopes.  Referenced from the design contract §3 + §3.1 + §13 + §6 footnotes 2 + 3.
- `docs/satan/refactor/T-attr-1-attribute-layer.md` (new): the theme doc — current shape (no attribute storage exists in code), why-it-hurts (outcome verdicts feed nothing without the dispatcher; no Cruelty cap; no operator rollback switch; capsule does not surface attribute pressure), target shape (5-PR breakdown a/b/c/d/e for contract → state → dispatcher → capsule render → other sources), considered+rejected alternatives (single-PR dispatcher without contract; skip projection / replay events on every read; decay in v1; per-scope storage in v1; `shame.applied` event-name), PR log (1a checked here; 1b–1e pending).  Adopts the T1.5a/b precedent for theme split.
- `docs/satan/refactor/plan.md`: T1.5 flipped `in-progress → merged` (T1.5b PR 4 + follow-ups all landed); new T-attr-1 row added (`in-progress`); Sequence block updated with actual landing order (T1.5b before attributes per the bracket-out, not after); A3 note widened to note T-attr-1 inherits the T1.5b break (no new sanction).
- `docs/satan/INDEX.md`: new "Attribute layer" section — `attributes.brief` + `attributes/outcome-semantics` (already-merged contract, was unindexed) + the two new docs above.  Refactor line widened to mention T-attr-1.
- Contract underwent two pre-implementation review rounds + an architectural reframe.  Round 1: 20 reviewer findings dispositioned (disable-switch frozen≠zero; disabled-event rebuild semantics; friction_cap forward-compat note; confidence lower-bound clamp removed; global-Suspicion/Shame-blunt caution; deterministic-dispatcher softening; replay ordering with `seq INTEGER`; pre-dispatch snapshot for multi-delta events; `worked shame` reduction; `harmful suspicion` rationale; reserved-vs-implemented source distinction; doc-hierarchy block; evidence_json scope clarification; zero-seeded baselines noted; replay-order index; per-source reason pairing; `evidence.confidence` required for outcome).  Architectural reframe: reviewer's "scope Shame for cue specificity" rejected per the design note — global is by-design, pattern records carry cue-specific consequences.  Round 2: revision handling rewritten to use actually-logged prior deltas (theoretical-minus-theoretical was wrong under caps); column-order reading note added (reviewer misread `contradicted hunger`); `worked doubt` + `contradicted hunger` interpretations clarified in footnotes; scope wording sharpened ("never `pattern:<id>` or `hypothesis:<id>`").  Full disposition trail in contract §16 (4 change-history rows).
- No code; T-attr-1b (migration `0007_attributes.sql` + `dl-satan-attribute-store.el` + audit-validator widening) is the next PR.  Contract `metadata.status: draft` will flip to `merged` when 1b lands (T1.5a precedent — contract is canonical from first impl PR).

## 2026-05-23 — SATAN: T1.5b PR 4 follow-ups (smoke + §11 cleanup)

- `satan/test/dl-satan-tools-atsatan-test.el`: new `notes-at-satan-intervention/end-to-end-smoke` ert — the live-broker integration the PR 4 handover deferred.  Exercises `notes_at_satan_intervention_done` against a real `dl-satan-intervention-create` + real `dl-satan-intervention-write-manual-outcome` + real `dl-satan-intervention-lookup` against the projection + real `dl-satan-audit-reopen` on the iv's own run-dir.  Only `dl-satan-broker-locate-run-dir` is stubbed (returns the audit handle's dir — same shape the broker would resolve via its denote chain) and `dl-satan-memory-store-mark` is stubbed (records call args without requiring the memory-store DB write).  Asserts: tool returns `ok` with the expected classification + iv-id + `intervention.outcome_classified` event name; projection row carries `:source "manual"` / `:marked_by "notes-directive"`; outcome event lands in the iv's *original* transcript (not the consuming tick's); counter-memory mark fires once with `:valence "negative"` + cue-handle inheritance verbatim from the intervention; rewritten notes file carries `@satan-was-here:` (not the broken `@satan-was-here-intervention-`) plus `#+BEGIN_QUOTE satan <consuming-run-id>,iv-harmful`.  Suite header requires `dl-satan-intervention-test` non-erroring (matches the mark-test precedent) so the smoke skips when the intervention-test fixture file is absent; otherwise gates on db reachability via `dl-satan-intervention-test--with-db`'s skip-unless.  Atsatan suite is now 19 ert (was 18) — all green; sister `dl-satan-intervention-test` + `dl-satan-intervention-mark-test` + `dl-satan-audit-intervention-test` suites green at 55/55 (no regression).
- `docs/satan/attributes/outcome-semantics.md` §11: strike-through Q#2 (notes-vs-auto ordering) with resolution note — latest-write-wins by `:classified-at`; the directive's `:classified-at` is the consuming tick's `:time-now`, and `intervention-classify` already orders by that field so no special-case in the writer was needed.  Strike-through Q#3 (counter-memory writer) — shipped in PR 4 via `dl-satan-intervention--write-counter-memory` calling `dl-satan-memory-store-mark` with `:trace-origin "auto_rule" :kind "observation" :source "intervention.manual_mark" :valence "negative"`; trace handles inherit the intervention's `:cue_handles` verbatim with `:rule_id "intervention.manual_mark" :origin "derived"` provenance.  Note added: dedicated `outcome:*` grammar handle-values are deferred to the attribute-layer build, not a one-off PR.  Q#1 (model-side `intervention_id` exposure) remains open.  Change history row added.

## 2026-05-23 — SATAN: T1.5b PR 4 — manual override path (T1.5 merged)

- `satan/dl-satan-audit.el`: new `dl-satan-audit-reopen DIR` returns an append-only audit handle for an existing run-dir.  Unlike `dl-satan-audit-open`, it does NOT truncate `transcript.jsonl` or rewrite `manifest.json` / `bundle.json` — `audit-record` simply appends.  Errors if DIR lacks a `transcript.jsonl` (manual marks must attach to a real prior run, not mint a new one).  Used by both manual-mark surfaces below so `intervention.outcome_classified` / `outcome_revised` events land in the iv's *original* run, keeping projection rebuild attribution stable.
- `satan/dl-satan-intervention.el`: new `dl-satan-intervention-write-manual-outcome` is the single writer behind interactive + notes surfaces (outcome-semantics §7).  Validates `:classification` ∈ `{harmful,contradicted}` and `:marked-by` ∈ `{interactive-command,notes-directive}` (auto-emitted `:harmful` / `:contradicted` remain rejected at the audit validator + at the existing `intervention-classify` boundary).  Builds the §5 evidence plist per-classification: `:harmful` carries `(:source_events () :reason :marked_by :evidence_pointer)`; `:contradicted` carries `(:source_events () :prior_suspicion :user_artifact :marked_by)`.  Delegates to `dl-satan-intervention-classify` with `:source "manual"` (auto-detects revision via prior outcome row → emits `outcome_revised` with `:revises` set, else `outcome_classified`).  After a successful classify, writes the §3.4 counter-memory trace via `dl-satan-memory-store-mark`: `:kind "observation"` / `:trace-origin "auto_rule"` / `:source "intervention.manual_mark"` / `:valence "negative"`; payload follows the contradicted template (`"SATAN suspected <reason>, but the user produced <evidence-pointer> from that activity. (intervention <iv-id>)"`) or the harmful template (`"harmful intervention <iv-id>: <reason> (<evidence-pointer>)"`); handles inherit the intervention's `:cue_handles` (per the PR 4 decision — resonance surfaces the counter-memory whenever the same cue re-fires) with provenance `(:rule_id "intervention.manual_mark" :origin "derived" :evidence_pointer "/intervention/<iv-id>")`.  Test-injectable via `:memory-mark-fn`; defaults to `dl-satan-memory-store-mark`.
- `satan/dl-satan-intervention.el`: new `dl-satan-intervention-recent NOW &key include-stale (limit 50)` backs the interactive completing-read.  Returns up-to-LIMIT interventions ordered `ts DESC`; default filter excludes `:stale` (per §6.3 — past auto-revision horizon); `:include-stale t` recovers them for the prefix-arg case where the user wants to manual-mark a frozen verdict (§7.4 allows manual marks in every lifecycle state).  Cue-handle null-from-DB guard (`:null` → nil) covers the empty-array round-trip.
- `satan/dl-satan-intervention-mark.el` (new file): `my/satan-mark-intervention-harmful` + `my/satan-mark-intervention-contradicted` ship the §7.1 interactive command.  Flow: prefix-arg toggles include-stale; completing-read over `intervention-recent`; `read-string` for reason; `read-string` for evidence-pointer (defaults to `<abbreviate-file-name buffer-file-name>:<line>`); `completing-read` over `low|medium|high` (default `medium`); optional notes.  Parses `<run-id>` from `<run-id>.iv<NNN>`, calls `dl-satan-broker-locate-run-dir`, `audit-reopen`s the on-disk run-dir, derives maturity via `dl-satan-observer--maturity-state` + window-close via `created_at + outcome_window_minutes`, dispatches to the manual writer with `:marked-by "interactive-command"`.  Broker dependency is soft (`declare-function`) so ert batch runs don't drag in `dl-satan-tools-org` / denote.
- `satan/dl-satan-tools-atsatan.el`: `--rewrite-line` is now mark-aware.  A new `--intervention-mark-re` (`@satan-intervention-\\(?:harmful\\|contradicted\\)`) is matched before the bare `@satan` fallback so the full prefix is replaced atomically — without this, `@satan-intervention-harmful: …` rewrote into `@satan-was-here-intervention-harmful: …` (not caught by `--claimed-re`, so the line stayed in scan results forever).  New `--parse-intervention-kv` + `--parse-intervention-directive` parse the §7.2 grammar (`iv_id=<id> reason="<freeform>" [conf=low|medium|high] [evidence=<path>:<line>]`); conf defaults `low` per §4; missing `iv_id` / `reason` → error; bad `conf` → error.  New tool `notes_at_satan_intervention_done` (registered + added to the `agent` tick's tool list) reads the matched line, parses the directive, locates the iv's run-dir via `dl-satan-broker-locate-run-dir` (soft `declare-function` for the same ert-isolation reason), `audit-reopen`s it, calls the manual writer with `:marked-by "notes-directive"`, then stamps the directive consumed by reusing `--rewrite-line` with an `iv-<cls>: <comment>` tag so the rendered block header carries `satan <consuming-run-id>,iv-<cls>` and `--claimed-re` filters the line from future scans.  Requires capability `write-notes` (same as `notes_at_satan_done`).
- Tests: 18 new ert across four files.  `dl-satan-audit-test.el` (3): `reopen-appends-without-truncating` (write a run, capture transcript bytes, reopen + append, assert bytes preserved + new event present), `reopen-rejects-missing-dir`, `reopen-rejects-dir-without-transcript`.  `dl-satan-intervention-test.el` (5): manual-writer rejects bad classification + bad marked-by, harmful first-emit + projection round-trip (asserts evidence shape + cue-handle inheritance on the counter-memory call), contradicted revises auto-`:ignored` (asserts `:revises` self-reference + `prior_suspicion` / `user_artifact` mapping + §3.4 payload template).  `dl-satan-intervention-mark-test.el` (5, new file): run-id-of extracts prefix / rejects malformed; window-close derivation from `ts + minutes`; recent newest-first + include-stale toggle (DB); dispatch end-to-end with stubbed `completing-read` + `read-string` + `dl-satan-broker-locate-run-dir` + `dl-satan-memory-store-mark` (asserts projection + counter-memory both written, `:cue_handles` inherited).  `dl-satan-tools-atsatan-test.el` (7): parser happy / conf-default-low / missing-iv_id / bad-conf / wrong-prefix; rewrite-preserves-intervention-prefix (asserts result starts `@satan-was-here:` not `@satan-was-here-intervention-`); scanner-includes-and-rewrites end-to-end (scanner returns directive line; handler writes via stubbed broker + writer; rescan returns 0); done-refuses-without-capability.  221 ert green across audit + intervention + intervention-mark + atsatan + observer suites.
- Audit validator unchanged: manual `:harmful` / `:contradicted` were already in the accepted set since T7 PR 1; PR 4 needed no closed-set widening.
- T1.5 brief PR log ticks PR 4 merged; `metadata.status` flips to `merged` on both `T1.5-outcome-semantics.md` and `outcome-semantics.md` (contract held verbatim through all four sub-PRs).  Outcome semantics §11 open questions resolved: id-only model visibility (T7 PR 3), latest-write-wins for notes vs auto (writer routes through classify which already orders by `:classified-at`), counter-memory writer scope (shipped in PR 4 with `:cue_handles` inheritance).
- **A3 boundary.** Manual marks are human-triggered; they were already outside the byte-identical-rerun envelope before PR 4 and remain so.  PR 4 introduces no new auto code paths.

## 2026-05-23 — SATAN: T1.5b PR 3 — lifecycle coordinator

- `satan/dl-satan-observer-classify.el`: new `dl-satan-observer--maturity-state intervention now` returns `:pending` / `:mature` / `:stale` from `(:ts, :outcome_window_minutes)` against the broker's frozen `:time_now` (outcome-semantics §3 + §6.2; the `:stale` cutoff is window-close + `dl-satan-observer-stale-after-seconds` = 24 h, matching the existing scan horizon).  `dl-satan-observer-classify` gains `&optional NOW`: nil → maturity check skipped (test-fixture convenience; verdict still carries `:maturity :mature`); `:pending` short-circuits to `(:classification :unknown :confidence :low :reason :pending :maturity :pending)` without consulting motive / baseline / predicates (§2 invariant 3 satisfied at construction time); `:stale` returns nil so the caller skips persist (§6.3 — auto re-pass forbidden past the cutoff); `:mature` runs the existing dormant / midnight / no-baseline / P1–P4 flow with `:maturity :mature` injected into every verdict.  `dl-satan-observer-classify-for-motives` threads `NOW` through, hoisting the same dispatch ahead of motive ranking so `:pending` and `:stale` skip the bundle.json read.  `--assert-auto-classification` lets nil pass through (the `:stale` short-circuit has no classification to assert against).
- `satan/dl-satan-intervention.el`: `dl-satan-intervention-pending` SQL adds the 24 h stale exclusion alongside the existing maturity filter — `i.ts + (i.outcome_window_minutes * INTERVAL '1 minute') + INTERVAL '24 hours' >= NOW::timestamptz`.  Production never reaches the classifier's defensive `:stale` branch; the in-Emacs check is belt-and-suspenders for direct callers (tests, manual driver use).
- `satan/dl-satan-observer.el`: `--verdict-classify-args` drops the hardcoded `:maturity "mature"` and reads the verdict's `:maturity` slot, lowercase-snakecasing at the audit boundary (per outcome-semantics §9).  `dl-satan-observer-process` threads `NOW` into `classify-for-motives`, treats a nil verdict as `(:skipped :stale)` in the summary rather than calling persist, and now records each kept verdict's `:maturity` for audit visibility.
- Audit validator unchanged: `:maturity` enum already accepted `pending|mature|stale` since T7 and the §2 invariant 3 guard (`pending ⇒ unknown`) was already enforced; no widening required.
- Tests: 11 new ert in `dl-satan-observer-test.el` — `maturity-state-{pending, mature-at-boundary, mature-inside-24h, stale}`; `classify-pending-short-circuits`; `classify-stale-returns-nil`; `classify-mature-injects-maturity`; `classify-without-now-defaults-mature` (backward-compat for fixtures that call classify without NOW); `classify-for-motives-pending-skips-bundle` (asserts unreachable `:run_dir` does not surface, proving the bundle read is skipped); `classify-for-motives-stale-returns-nil`; `pending-sql-excludes-stale` (DB — mint past stale cutoff, confirm pending returns empty); `persist-pending-writes-maturity-pending` (DB — verdict carrying `:maturity :pending` lands as `maturity="pending"` in `satan_intervention_outcomes`).  117 observer ert green; 46 intervention + audit-intervention sibling ert green (PR 3 did not touch their surfaces).
- **A3 boundary.** PR 3 narrows the byte-identical-rerun break already sanctioned by T7 PR 5: maturity transitions all use the broker's frozen `:time_now`, so two ticks at the same prepare-time produce the same verdict (per §6.1).  T7 (id randomness) and T1.5b (wider verdict shape) remain the only two themes permitted to break A3.
- T1.5 brief PR log ticks PR 3 merged; §10 contract held without amendment.  PR 4 (manual override path — interactive cmd + notes directive) is next.

## 2026-05-23 — SATAN: T1.5b PR 2 — classify-negative

- `satan/dl-satan-observer-classify.el`: new `dl-satan-observer-classify-negative` dispatches the no-fire branch on the intervention's `:kind` / `:target_surface`.  User-facing kinds (`dl-satan-observer-user-facing-kinds` = `inbox` / `notify` / `visible_sign` / `proposal` / `patch_job` / `accuse` / `ask` / `surface`) with no positive predicate fire → `:ignored` (`:medium` confidence when AFTER's panopticon focus probe status is `ok` + zero post-emit focus segments; `:low` when the probe is unverified) with evidence `(:target-surface :no-positive-predicates :acknowledgement-checked :ack-events-found)` per outcome-semantics §5.  Non-user-facing kinds (`delay` / `quarantine` / anything else) → `:neutral :low` with evidence `(:target-surface :no-positive-predicates)`.  User-facing + `:ack-events-found > 0` falls through to `:unknown :low :reason nil` (per §1 — `:ignored` requires no acknowledgement event in window; v1 punts here rather than extending the `:reason` vocabulary, avoiding contract amendment).  `dl-satan-observer--assert-auto-classification` rejects auto verdicts with `:harmful` / `:contradicted` via `cl-check-type`; the guard wraps both `dl-satan-observer-classify` and `dl-satan-observer-classify-for-motives` returns so manual-only invariants (§2 invariants 1+2) cannot leak through the auto path.
- `satan/dl-satan-observer.el`: `--verdict-classify-args` widens to map the new verdict shapes onto audit-event evidence: `:ignored` emits `(:source_events () :target_surface STR-or-:null :no_positive_predicates t :acknowledgement_checked t-or-:false :ack_events_found N)`; `:neutral` emits `(:source_events () :target_surface STR-or-:null :no_positive_predicates t)`; `:unknown` keeps the legacy `(:source_events () :reason STR-or-:null)` shape (reached both from the maturity / baseline / motive guards AND from `classify-negative`'s ack-events-found > 0 fall-through).  Kebab-case keys in the verdict's `:evidence` plist translate to snake-case on the audit boundary per outcome-semantics §9.
- Tests: classifier fixture `dl-satan-observer-test--intervention` now takes optional `:kind` / `:target-surface` keywords (defaulting to `"notify"` / `"sway-mainbar"`); existing no-fire ert repointed — `classify-no-fire-yields-unknown` becomes `classify-no-fire-user-facing-yields-ignored`, `classify-a12-fs-coincidence-does-not-fire` asserts `:ignored`, `classify-for-motives-tie-file-order` asserts `:ignored`.  Six new ert: `classify-no-fire-non-user-facing-yields-neutral`, `classify-no-fire-ack-checked-zero-yields-medium`, `classify-no-fire-ack-checked-found-yields-unknown`, `persist-ignored-classifies-ignored`, `persist-neutral-classifies-neutral`, `classify-auto-rejects-harmful`.  Two new persist helpers — `--ignored-verdict` (defaults to `:low` + unchecked ack) and `--neutral-verdict`.  105 ert green; intervention (24) + audit-intervention (22) + audit (10) sibling suites unaffected (56 total).
- T1.5 brief PR log ticks PR 2 merged; the §10 contract held without amendment (`:ignored` / `:neutral` / `:unknown` were already in the closed classification set since T7).  PR 3 (lifecycle coordinator — `:pending` / `:mature` / `:stale`) is next.

## 2026-05-23 — SATAN: T1.5b PR 1 — verdict shape extension

- `satan/dl-satan-observer-classify.el`: `dl-satan-observer-classify` returns the outcome-semantics §2 plist (`:classification :worked|:unknown`, `:confidence :low|:medium|:high`, `:predicates LIST-of-KW`, `:reason KW`) instead of the legacy `(:verdict :predicate :reason)` shape.  Step 4 now runs every P1–P4 (not first-fire-wins) and collects the firers list; confidence derives from the count — `:medium` on a single fire, `:high` on ≥2.  Guard rails (`:motive_dormant`, `:crosses_midnight`, `:no_baseline`, no-fire) all route through a new `--unknown` helper that emits `:unknown :low` with the appropriate `:reason`.  `dl-satan-observer-classify-for-motives` keeps the `:motive_id` augmentation and emits the same `:unknown` shape with `:reason :no_correlation` when no motive overlaps.  PR 2 will refine the no-fire branch into `:ignored` / `:neutral` based on intervention surface; PR 3 will wire the maturity lifecycle (`:pending` / `:mature` / `:stale`); PR 4 will land the manual-override path.
- `satan/dl-satan-observer.el`: `--verdict-classify-args` consumes the new shape and emits the audit-event kwargs — `:classification` / `:confidence` strings derived via the existing `--keyword-to-string` helper, `:evidence :predicates` widened to the full firer list (was always a single-element list), `:evidence :reason` preserved on `:unknown` branches.  `--persist-positive` trace metadata renamed: `:predicate` → `:predicates LIST`, plus new `:classification` / `:confidence` slots; payload string drops the implicit `(plist-get verdict :verdict)` lookup and joins firers with a comma.  `persist-verdict` positive-check now matches against `:worked` keyword.  `dl-satan-observer-process` summary verdicts widen from `:verdict`/`:predicate`/`:reason` to `:classification`/`:confidence`/`:predicates`/`:reason`.
- Tests: `dl-satan-observer-test.el` helpers `--positive-verdict` / `--negative-verdict` rebuilt around the new shape (positive helper now accepts an optional `confidence` arg for PR-1's `:high` case).  Classifier-direct ert and `classify-for-motives` ert retrofit; new `classify-multi-fire-yields-high-confidence` ert exercises the `:high` path (P2 + P3 firing together); the no-fire test renamed to `classify-no-fire-yields-unknown` and asserts `:unknown :low` plus an empty `:predicates`.  `persist-positive-bumps-motive-and-classifies` trace-metadata assertions check the new `:predicates` / `:classification` / `:confidence` slots; `process-no-correlation-classifies-unknown` and `process-positive-bumps-motive-and-projects` summary assertions widen to the new keys.  99 ert green; intervention (14) + audit-intervention (32) + audit (10) + percept (12) + broker (17) sibling suites unaffected (184 total).
- T1.5 brief PR log ticks PR 1 merged; the §10 contract has held without amendment.

## 2026-05-23 — SATAN: T7 PR 5 — observer read-path swap (T7 merged)

- `satan/dl-satan-observer.el`: delete `applied-interventions-in-run`, `scan-prior-interventions`, `mark-classified`, the `dl-satan-observer-state-file` defcustom + atomic `--read-state`/`--write-state`/`--classified-p`/`--key-of` dedup path, `--mature-p`, `--in-scan-window-p`, `--run-id-from-dir`, `--run-started-at`, `--failed-suffix`, plus the now-unused `intervention-tools` + `scan-window-hours` defcustoms.  `dl-satan-observer-pending` is now a thin wrapper over `dl-satan-intervention-pending`: it resolves each projection row's `:run_dir` via `dl-satan-broker-locate-run-dir`, mirrors `:ts` into `:intervention_emitted_at`, and derives `:applied_index` from the `ivNNN` counter so the classifier + persist code keep their existing slot reads.
- `dl-satan-observer-persist-verdict` drops `mark-classified` and instead writes the verdict through `dl-satan-intervention-classify`.  Mapping (PR 5; T1.5b widens this): classifier `verdict "positive"` → classification `"worked"`, confidence `"medium"`, evidence carries `:source_events ()` `:predicates (STR)` `:motive_id`; classifier `verdict "none"` (any reason, including no-fire) → classification `"unknown"`, confidence `"low"`, evidence carries `:source_events ()` `:reason STR`.  Every verdict commits `:maturity "mature"`, `:next_revisit_at` (created_at + outcome_window_minutes), `:source "auto"`, `:classified_at` (broker `:time_now`).  Motive bump + observation/auto_rule trace remain on positive; trace metadata now carries `:intervention_id` instead of `:applied_index` + `:tool_name`.
- `satan/dl-satan-broker.el` opens the audit handle BEFORE `observer-process` so the observer can emit `intervention.outcome_classified` / `outcome_revised` into the current run's transcript.  Audit-open now accepts a nil bundle (deferred); `dl-satan-audit-attach-bundle` writes `bundle.json` once the context-fn has produced it.  `dl-satan-broker--prepare` stamps `:mode_name` onto prepare so `dl-satan-observer--ctx-from-run-ctx` can build the tool-ctx the intervention API requires.
- Observer test rewritten around `dl-satan-intervention-test--with-db` (skip-unless reachable + reset-and-migrate; reset list prepends `satan_intervention_outcomes, satan_interventions`).  Classifier + multi-motive ert preserved verbatim (they live in `dl-satan-observer-classify.el`).  New ert exercise the projection-shaped pending, the worked/unknown mapping, revision auto-detect, and the end-to-end `observer-process` write paths (positive + no-correlation + per-iv error containment).  98 ert green (154 with audit + intervention).
- **A3 determinism boundary.** Per CODE_REVIEW.md §6 Q7 and outcome-semantics §6.1, T7 PR 5 is the sanctioned break of byte-identical transcript reruns: the current run's transcript now grows by one `intervention.outcome_classified` (or `outcome_revised`) event per matured prior intervention, with `:classified_at` set to the broker's frozen `:time_now`.  No transcript-level golden test exists; the percept A3 ert (`dl-satan-percept-test`) is unaffected.
- T7 metadata.status flipped to `merged` in `T7-intervention-records.md` + `plan.md`.  T1.5b (negative classifier in `dl-satan-observer-classify.el`) is now unblocked.



- `satan/dl-satan-tools-inbox.el` (`inbox_append`, kind=`inbox`, target=inbox-file path, window=30, severity=`medium`), `satan/dl-satan-tools-org.el` (`proposal_stage`, kind=`proposal`, target=proposal-file path, window=120, severity=`medium`), `satan/dl-satan-tools-patch.el` (`patch_job_create`, kind=`patch_job`, target=job-id, window=120, severity=`medium`), `satan/dl-satan-tools-sway.el` (`sway_border_set`, kind=`visible_sign`, target=`sway-mainbar`, window=30, severity=`low`) all route through `dl-satan-intervention-create` after their primary side-effect succeeds; the minted `intervention_id` surfaces on each `tool_result` alongside the pre-existing handler-specific keys (no replacement).
- Per-handler ert mirror `dl-satan-tools-notify-test.el`'s `--with-stubs` macro: each stubs `dl-satan-intervention-create` to a fixed id and asserts (i) the kwarg shape against §3.3 defaults and (ii) `:intervention_id` carriage in `tool_result`. Existing handler tests retrofitted with enriched tool-ctx (`:audit` / `:id` / `:mode-name` / `:time-now`). +9 ert across the four files.
- Side-cleanup of T7 gotcha #3 omitted by PR 2: `satan_intervention_outcomes, satan_interventions` prepended to the DROP TABLE list in `dl-satan-memory-store-test.el`, `dl-satan-tools-memory-test.el`, and `dl-satan-tools-hippocampus-test.el`. `satan/test/dl-satan-sensor-alerts-test.el`'s `silence-notify` and "successful dispatch" `cl-letf` now also stub `dl-satan-intervention-create`, fixing the regression introduced when PR 3 made `notify_send` require a live audit handle.
- `docs/satan/refactor/T7-intervention-records.md` PR log ticks PR 4 merged; T7 status remains in-progress until PR 5 (observer read-path swap) lands.

## 2026-05-23 — SATAN: T7 PR 3 — intervention write/read API + `notify_send` cutover

- Extend `satan/dl-satan-intervention.el` with the write+read surface T7 needs: `dl-satan-intervention-create` (mints a stable `<run-id>.iv<NNN>` id via a per-run session-local counter, emits `intervention.created` into the run's transcript, INSERTs the projection row with `ON CONFLICT (id) DO NOTHING` for retry-idempotency); `dl-satan-intervention-classify` (auto-detects revision via projection-lookup, emits `outcome_classified` or `outcome_revised` accordingly, UPSERTs the latest verdict); `dl-satan-intervention-lookup` (returns `(:intervention :outcome)` plist with JSONB columns reparsed); `dl-satan-intervention-pending` (returns interventions whose maturity window has elapsed and lack a verdict).
- `satan/dl-satan-broker.el` exposes the live audit handle on tool-ctx (`:audit`) so handlers can route writes through the intervention API; handlers must NOT call `dl-satan-audit-record` with arbitrary event names — the only sanctioned channel is the intervention module.
- `satan/dl-satan-tools-notify.el` is the first handler cutover: after firing the D-Bus notification it calls `dl-satan-intervention-create` (kind=`notify`, target_surface=`dbus`, severity mapped from urgency, 30-min outcome window per §3.3), and surfaces the minted `intervention_id` in the `tool_result` alongside the existing notification `:id` (per outcome-semantics §11.1: id-only, no live verdict).
- Tests: `dl-satan-intervention-test.el` gains 6 ert covering create→audit+projection round-trip, monotonic counter, classify→outcome_classified then revised on second call (auto-detected), auto-`harmful` rejection through the API, pending gating + post-classify removal, missing lookup. `dl-satan-tools-notify-test.el` adds 4 ert (stubbing `dl-satan-intervention-create`) for intervention_id surface, kwarg shape, severity mapping, and default; existing tests retrofitted with the enriched tool-ctx.
- **Open question resolved (PR 3 decision):** `intervention_id` in `tool_result` is id-only — the model sees the id but not the live classification. A future `intervention_status` tool can expose verdict state on explicit query.

## 2026-05-23 — SATAN: T7 PR 2 — intervention projection + rebuild CLI

- Add migration `satan/memory/migrations/0006_interventions.sql` — `satan_interventions` (immutable created-rows, kind/severity CHECK enums) + `satan_intervention_outcomes` (latest-verdict-per-intervention, `ON DELETE CASCADE`, CHECK constraints mirroring §9 invariants: auto-harmful, auto-contradicted, pending⇒unknown). Indexes on `(run_id)`, `(ts)`, `(mode, kind)`, `(classification)`, `(next_revisit_at)`, `(maturity)`.
- Add `satan/dl-satan-intervention.el` with `dl-satan-intervention-rebuild` — walks every `transcript.jsonl` under `dl-satan-runs-dir`, filters intervention events, sorts by `(ts, run-id, seq)`, runs the audit-side stream validator, replays into the projection (TRUNCATE + INSERT/UPSERT) inside one `psql --single-transaction`. Idempotent: rebuild twice ⇒ byte-identical rows. Validation failure leaves the projection untouched. `my/satan-rebuild-interventions` interactive entrypoint; `satan/bin/satan-rebuild-interventions` shell wrapper invoking it via `emacsclient`.
- New `satan/test/dl-satan-intervention-test.el` (8 ert) covers: nested-runs transcript discovery, intervention-event filtering against other transcript records, sort tiebreaker, empty-runs rebuild, end-to-end projection, idempotency across two runs (created + classified + revised + harmful-manual), head-reflects-latest-revision (`ignored` → `worked` via outcome_revised), validation refusal (outcome before created leaves projection untouched). DB-touching tests `skip-unless` `satan_memory_test` reachable.
- Update `dl-satan-memory-migrate-test.el` (`applies-real-migrations`: 5→6) and the reset-db DROP lists in migrate + renormalize tests to include the new tables; no other call-site changes.
- **Open question resolved (PR 2 decision):** rebuild is operator-demand only — `0006_interventions.sql` itself just creates the tables; population happens via the CLI. Matches the `dl-satan-memory-renormalize` precedent.

## 2026-05-23 — SATAN: T7 PR 1 — intervention audit-event validator

- Add three intervention audit-event names (`intervention.created`, `intervention.outcome_classified`, `intervention.outcome_revised`) + closed-set constants (`classifications`, `confidences`, `maturities`, `sources`, `severities`, `kinds`) + `dl-satan-audit-validate-intervention-event` / `dl-satan-audit-validate-intervention-stream` in `satan/dl-satan-audit.el`, encoding the §9 invariants from `outcome-semantics.md` (auto-harmful / auto-contradicted rejection; pending-maturity ⇒ unknown classification; replay-safety against the per-stream created-id set).
- New `satan/test/dl-satan-audit-intervention-test.el` (32 ert) covers valid payloads (all kinds; null `related_motive_id`; pending + unknown; manual harmful/contradicted; revised supersedes prior) and rejections (auto harmful/contradicted; pending + non-unknown; missing prior `created`; missing/dangling `revises`; closed-set violations on every enum; non-integer + negative `outcome_window_minutes`).
- `docs/satan/protocol.md` gains an "Audit log event types (broker-internal)" section documenting the three payload shapes verbatim; flags these as broker-internal (`:dir broker`) rather than membrane messages.
- No callers wired yet — PR 2–5 land the projection, write API, handler cutovers, observer read-path swap.

## 2026-05-23 — SATAN: T1.5a outcome-semantics design contract (doc only)

- Land `docs/satan/attributes/outcome-semantics.md` (~400 lines) defining the closed verdict vocabulary, lifecycle (`:pending|:mature|:stale`), verdict-plist shape, `:low|:medium|:high` confidence enum, per-classification evidence handles, clock + window semantics (broker `:time_now` frozen at `--prepare`; 24 h `:stale` cutoff), revision policy, manual-mark workflow (interactive command + `@satan-intervention-{harmful,contradicted}` notes directive), and the explicit list of what v1 refuses to infer (causal harm; auto contradiction; fine-grained ignored-vs-pending; cross-intervention amplification; continuous-float confidence).
- Encodes T7's three audit-event shapes (`intervention.created`, `intervention.outcome_classified`, `intervention.outcome_revised`) so T7 can land the validator + projection migration without re-litigating vocabulary.
- T1.5b implementation (4 PRs in `dl-satan-observer-classify.el`) remains blocked on T7's substrate.

## 2026-05-23 — SATAN: T4 drop tool-spec `:modes` field

- Delete the documentary `:modes` field from every `dl-satan-tool-register` site (22 occurrences across 14 tool modules) — the broker never consulted it; the mode-spec `:tools' allowlist (`dl-satan-mode.el`) is the only source of truth.
- Add `dl-satan-mode-check-tool-references' (`dl-satan-mode.el') that signals at load if any mode-spec's `:tools' names an unregistered tool; call it from `dl-satan.el' after all tool/mode modules are required.
- Rewrite `dl-satan-org/update-owned-block-only-registered-for-morning' to assert the mode `:tools' allowlist (renamed `…only-listed-by-morning'); drop the `:modes`-nil assertion in `dl-satan-tools-memory/registered'.
- New `dl-satan-mode-test.el' covers the consistency check (passes on live registry; signals on a planted typo).
- Update `docs/satan/patch/handover.md' + `docs/satan/at-satan/design.md' snippets to drop `:modes`.

## 2026-05-23 — SATAN: T1 observer file-split (PR 1)

- Extract pure classifier + §S5 P1–P4 predicate registry + classifier defcustoms (`window-mature-seconds`, `emacs-title-suffix-re`) into new `satan/dl-satan-observer-classify.el` (~387 LOC). `dl-satan-observer.el` retains coordinator concerns (scan, dedup, maturity gate, verdict persistence, broker entry) and `(require 'dl-satan-observer-classify)`s the leaf. Symbol names preserved verbatim — no test churn. Observer drops from 859 → 503 LOC; tests 126/126 green.

## 2026-05-23 — SATAN: T6 test monolith split

- Extract `dl-satan-jsonl-test.el` (6 tests) from `satan/test/dl-satan-test.el` monolith.
- Extract `dl-satan-block-test.el` (4 tests).
- Start `dl-satan-tools-test.el` with schema validator subsection (12 tests).
- Append dispatch capability guard tests to `dl-satan-tools-test.el` (+5 tests).
- Start `dl-satan-broker-test.el` with capability-denial cross-cutter (1 test).
- Extract `dl-satan-tools-notify-test.el` (4 tests).
- Extract `dl-satan-tools-inbox-test.el` (4 tests).
- Merge 3 file-side hippocampus tests into existing `dl-satan-tools-hippocampus-test.el`.
- Extract `dl-satan-tools-org-test.el` (3 tests).
- Merge 7 self-edit context-fn tests into existing `dl-satan-context-test.el`; helpers renamed to `dl-satan-context-test--*`. Shared helpers temporarily restored in monolith for two later sections still using them.
- Append 4 JSON Schema builder tests to `dl-satan-tools-test.el`; `with-tool-descriptions` helper migrated.
- Append 3 `dl-satan-broker--prepare` (Phase 0.1) tests to `dl-satan-broker-test.el`.
- Append 9 broker tool-ctx + run-dir enumeration + announce-failure + locate-run-dir tests to `dl-satan-broker-test.el`.
- Spin out `dl-secret-test.el` for the `scrub-op-refs-env` test (subject is dl-secret, not SATAN broker).
- Append broker manifest-assembly test to `dl-satan-broker-test.el`; pull in tool-module requires so registrations land before the manifest build.
- Append `self-edit/output` test to `dl-satan-context-test.el` alongside the other self-edit lifecycle tests.
- Extract `dl-satan-tick-test.el` (7 tests).
- Extract `dl-satan-tools-agenda-test.el` (7 tests + `with-gcalcli-stub` macro).
- Extract `dl-satan-tools-activity-test.el` (11 tests + fixture macros).
- Extract `dl-satan-tools-notes-test.el` (7 tests + fd-stub macro + touch helper).
- Extract `dl-satan-budget-test.el` (4 tests + transcript/usage helpers). The cross-cutter `dl-satan-broker/refuses-spawn-when-budget-exceeded` relocates to `dl-satan-broker-test.el` (assertion subject = broker; secondary = budget).
- Start `dl-satan-audit-test.el` with the verifier-ok smoke test; the `write-run` helper migrates renamed (`dl-satan-audit-test--write-run`). Monolith retains its copy until the pre_spawn section extracts.
- Append 2 broker pre_spawn threading (Phase 4.4) tests to `dl-satan-broker-test.el` — `finalize` copies `:pre_spawn` from prepare into `actions.json`, omitting the key when nil.
- Append 7 audit pre_spawn (Phase 0.3) tests to `dl-satan-audit-test.el`; monolith drops its `write-run` helper as the audit sections are now consolidated.
- Append 4 context `:now` tests (now-plist shape; motd/tick/self-edit bundles carry `:now`) to `dl-satan-context-test.el` — reuses the existing `dl-satan-context-test--write-framing` helper.
- Append 8 context framing rendering tests (parse-framing, render-prompt now/today/sources/ordering) to `dl-satan-context-test.el`; helper renamed `dl-satan-context-test--with-framing`. Monolith drops the three orphan top-of-file helpers (`path-suffix-p`, `write-framing`, `with-tool-descriptions`).
- Finalize: extract 5 wire-protocol tests into new `dl-satan-protocol-test.el`; cross-cutter the 2 actions-fixtures tests (subject = `dl-satan-audit-validate-actions`) to `dl-satan-audit-test.el`. Monolith `satan/test/dl-satan-test.el` deleted. T6 status flipped to `merged`. `docs/satan/governance.md` references updated.

## 2026-05-23 — SATAN: extract refactor themes into `docs/satan/refactor/`

`CODE_REVIEW.md` (309 lines, 8 themes) was a frozen point-in-time
review document — wrong shape for execution. Extracted each theme
(T1, T1.5, T2, T3, T4, T6, T7, T8) into its own brief under
`docs/satan/refactor/`, plus a living `plan.md` index with a status
table, sequence, open questions, and the working procedure for
flipping status as PRs land. Mirrors the existing
`docs/satan/patch/{brief,plan}.md` precedent. `CODE_REVIEW.md` stays
in place as the frozen artifact with a one-line pointer up top;
`docs/satan/INDEX.md` gained a tracking link.

No code changes.

## 2026-05-23 — SATAN: fix `dl-satan-jsonl-prepare` chokes on alists

Live tick crashed inside `dl-satan-audit--write-json` with

    (wrong-type-argument consp 1)

because `dl-satan-context--tally-tool-calls` returns a `(NAME . COUNT)`
alist that gets embedded under `:tools` in every `:recent_runs` bundle
entry.  The wire layer previously walked it via the
`(consp v) (listp (cdr v))` branch and emitted a vector of dotted-pair
conses — a shape `json-serialize` rejects.  Every tick fired after the
first run with tool-call records in its transcript (i.e. from
2026-05-23 01:09 onward) until this fix.

Same chokepoint philosophy as `547ef003b` (symbol coercion): handle
the shape at the encoder so producers stay free to use natural elisp
data types.

- **`dl-satan-jsonl--alist-p`** — detect lists of `(KEY . VAL)`
  dotted pairs where each entry has a non-keyword car and a non-list
  cdr.  Excludes list-of-plists (keyword car) and list-of-2-lists
  (listp cdr) so existing JSON-array shapes still encode as arrays.
- **`dl-satan-jsonl--alist-key-to-keyword`** — coerce string /
  symbol keys to keywords so the flattened plist is acceptable to
  `json-serialize`.
- **`dl-satan-jsonl-prepare`** — new branch after the plist case
  flattens alists into plists, so they encode as JSON objects
  (`{"activity_read":1,"notes_recent":2}`).
- One new ert exercising the exact production failure plus
  guards that list-of-plists and list-of-2-lists still produce
  vectors.

## 2026-05-23 — SATAN: perceptual-layer v0 Phase 6 (cooldown floor)

Read-side enforcement of §S4.  When the broker renders the capsule's
motive block, motives whose `(now - :last_intervention_at:) <
:cooldown_s:` are flagged off-budget to the model rather than offered
as actionable pressure.

- **`dl-satan-motive--cooling-down-remaining MOTIVE NOW-T`** —
  pure helper returning remaining cooldown seconds (positive number)
  or nil.  Nil when `:cooldown_s:` is absent / non-positive,
  `:last_intervention_at:` is absent or unparseable, or the window
  has elapsed (motive is actionable).
- **`dl-satan-motive-render-block`** now takes an optional `NOW`
  argument (nil / ISO string / emacs time value).  When supplied,
  cooling-down motives have their `## <id>` header annotated
  `  [cooling-down (Nm remaining)]`; prose, cue, and the
  `cooldown_s / worked_count / last_intervention_at` footer line
  stay intact.  Nil NOW disables the check (legacy callers unchanged).
- **`dl-satan-context--render-prompt`** passes `(plist-get bundle
  :time_now)` to the renderer.  Bundle already mirrors `:time_now`
  from the broker's frozen `run_ctx`, so no new plumbing.
- Duration formats as `Nm`, ceil-rounded to minutes per design
  doc §7 Phase 6 verbatim.  Cooldowns >60 m render `120m remaining`.
- Four new ert covering: annotated header within window, bare
  header once elapsed, motives lacking `:last_intervention_at:`
  (never fired), motives lacking `:cooldown_s:` (no floor).

Total ert 394/394.  Pure render-side change — no schema bump, no
write path, no audit / observer change.

## 2026-05-22 — SATAN: perceptual-layer v0 Phase 5 complete

Phase 5 (outcome observer) is now end-to-end.  Sub-phases 5.5–5.8
land on top of 5.4:

- **5.5 motive footer rewriter** — `dl-satan-motive-touch-footer ID
  WORKED-COUNT LAST-AT [PATH]'.  Text-level mutation: existing
  `:worked_count:' / `:last_intervention_at:' lines edited in
  place (indentation preserved via capture group); missing lines
  appended after the section's last footer line.  Prose,
  ruminations, other footer fields, ordering preserved verbatim.
  Atomic tmp + rename.  Ten ert.
- **5.6 verdict persistence** — `dl-satan-observer-persist-
  verdict' composes the three writes a positive classification
  triggers: touch-footer (counter + ISO bump), memory-store-mark
  (observation / auto_rule trace with run/applied_index/motive_id/
  predicate metadata), and dedup mark-classified.  Negative
  verdicts record dedup only.  Dedup written last so partial
  failures retry.  Six ert.
- **5.7 multi-motive resolver** — `dl-satan-observer-classify-for-
  motives' intersects intervention's percept-handles (from
  bundle.json) against each motive's `:cue', picks highest
  overlap, file-order tiebreak.  Dormant motives skipped.  Zero
  overlap → `:reason :no_correlation'.  Nine ert.
- **5.8 broker integration** — `dl-satan-observer-process RUN-CTX'
  is the per-tick entry; `dl-satan-broker--spawn' calls it BEFORE
  percept-build and motive-read so the in-tick capsule sees
  fresh `:worked_count' / `:last_intervention_at' from prior-run
  interventions whose 30-min window matured.  Per-iv errors
  caught; loop continues.  Summary attaches to PREPARE
  `:observer' and (mirroring Phase 4.4 pre_spawn precedent)
  surfaces in `actions.json' alongside `pre_spawn'.  Four ert.

390/390 ert across all suites.  Byte-compile clean.

Carry-forward for Phase 6: cooldown floor enforcement (broker
pre-capsule check that flips motives in cooldown to a
`cooling-down (Nm remaining)' rendering — uses the
`:last_intervention_at:' Phase 5 now maintains).

## 2026-05-22 — SATAN: perceptual-layer v0 Phase 5.4 (positive predicate)

Observer gains the classification half — given a mature, undeduped
intervention and a motive, return a verdict via four substrate-derived
predicates (§S5).  Pure: no state writes (5.5 / 5.6 ship persistence).

Cross-repo work landed first:
- `~/dev/panopticon@9912e57` — `focus_segment` events now carry an
  optional `last_title` field (the title observed at segment close).
  Boundaries still collapse on `(app_id, workspace)`; window_title
  events still don't split.  175/171 pytest, ruff clean.  Old
  on-disk segments without the field are tolerated (P1 skips).
- `core/dl-interface.el` — `frame-title-format` switches `%b` for
  `(buffer-file-name)` when visiting a file, falling back to `%b`
  otherwise.  Panopticon's sway watcher captures the title; the
  observer parses the leading path back out.

Four new private helpers in `dl-satan-observer.el`:
- `--baseline-read RUN-DIR` reads RUN-DIR/`bundle.json` →
  `:percept` → `:evidence_window`.  Nil on missing / malformed /
  no-percept (budget-denied or pre_spawn-denied runs).
- `--window-end-iso INTERVENTION` adds
  `window-mature-seconds' (30 min) to `:intervention_emitted_at'.
- `--window-crosses-midnight-p INTERVENTION` guards the §S5
  watch-out — assemble-with-bounds derives `today = (substring END
  0 10)' for the panopticon segment file lookup, so multi-day
  windows would miss most of the after-state.
- `--after-state INTERVENTION MOTIVE` calls
  `dl-satan-memory-evidence-assemble-with-bounds' scoped to the
  30-min window and the motive's `:project_cwd' (default-directory
  when absent).

Four predicate primitives, all pure, all signature
`(BASELINE AFTER MOTIVE INTERVENTION)':
- P1 `--predicate-editor-edit-in-window' — editor `focus_segment'
  whose `:start_ts' is strictly after `:intervention_emitted_at'
  and whose `:last_title' resolves under `:project_cwd'.  Skips
  when `:project_cwd' absent or `:last_title' missing.  Title
  suffix is a defcustom (`dl-satan-observer-emacs-title-suffix-re')
  so users tweaking `frame-title-format' can keep parsing without
  editing code.
- P2 `--predicate-git-commit-observed' — repo-scoped (motive
  `:project_cwd' + `project:' cue), window-anchored scan of
  `after.git_commits' over the git feed (24h horizon since
  2026-06-02).  No baseline comparison — attribution window is
  the anchor.  Replaced `:git_head_changed' (live `git log` in
  broker cwd) which was starved by the 10-min attention window.
- P3 `--predicate-fs-recent-delta' — new entry under
  `:project_cwd' in AFTER's `:recent_files' absent from BASELINE's.
  Compares absolute paths (`--abs-recent') so baseline/after cwd
  mismatch is handled.  recentf semantics tracks visits not edits;
  documented v0 looseness.
- P4 `--predicate-bough-event-match' — AFTER's `:bough_recent'
  carries an event whose `:nanoid' matches a `bough_node:' or
  `bough_project:' handle in MOTIVE's `:cue'.  Fires regardless of
  `:project_cwd' (handle-only correlation per §S5).

Public surface: `dl-satan-observer-classify INTERVENTION MOTIVE'
returns `(:verdict STR :predicate KW-or-nil :reason KW-or-nil)'.
Guard order: dormant motive (A14) → midnight-crossing → missing
baseline → P1/P2/P3/P4 in declaration order, first fire wins.
Single-motive only; multi-motive overlap + file-order tiebreak
lands in 5.7.

Thirty-one new ert pin baseline-read variants, window arithmetic
including midnight rollover, every predicate's fire + skip
branches (including A12 no-coincidence invariants and silent
skips on missing `:project_cwd' / `:last_title' / cue handles),
and end-to-end classifier behaviour including a stubbed-after-state
positive via P2.  362/362 ert.

## 2026-05-22 — SATAN: perceptual-layer v0 Phase 5.3 (window-mature + dedup)

Observer gains the gating + persistence half it needs before the
positive predicate can ship.  Two new defcustoms:
`dl-satan-observer-window-mature-seconds' (default 1800 — the §S5
30-min attribution window) and `dl-satan-observer-state-file'
(default `~/.local/state/satan/observer.json`).  Two new public
entries:
- `dl-satan-observer-pending NOW [RUNS-DIR] [STATE-PATH]` returns
  intervention plists past the maturity gate (A11) and not already
  in the dedup state (A13).
- `dl-satan-observer-mark-classified INTERVENTION VERDICT NOW
  [STATE-PATH]` atomically appends a `{run_id, applied_index,
  classified_at, verdict}` record, no-op on duplicate keys.
State I/O mirrors `dl-satan-sensor-alerts` (tmp + rename, lenient
parse seeding to empty on missing / malformed).  Sixteen new ert;
331/331 green.

## 2026-05-22 — SATAN: perceptual-layer v0 Phase 5.2 (observer skeleton)

New `satan/dl-satan-observer.el` walks prior-run `transcript.jsonl`
files and surfaces every `action-applied` record whose payload
`:type` is in the new defcustom
`dl-satan-observer-intervention-tools` (default: `notify_send`,
`inbox_append`, `proposal_stage`, `org_update_owned_block`,
`sway_border_set`).  Each match becomes an intervention plist
keyed by `(run_id . applied_index)`, where `applied_index` is the
position in the unfiltered applied sequence — so tuning the
intervention-tool set does NOT re-number the dedup keys that 5.3
will persist.

Window: `dl-satan-observer-scan-window-hours` (default 24) bounds
how far back observations reach.  Lazy require of
`dl-satan-broker` avoids the load-time cycle 5.8 would otherwise
introduce.  New helper `dl-satan-jsonl-read-file` consolidates
JSONL reading (duplicate of
`dl-satan-tools-activity--read-jsonl`; that one can be
collapsed later).  11 new ert (315/315 green).  No behaviour
change anywhere outside the observer module — the broker does
not yet call the scanner.

## 2026-05-22 — SATAN: perceptual-layer v0 Phase 5.1 (evidence bounds refactor)

Behaviour-preserving split of `dl-satan-memory-evidence-assemble`
into a thin wrapper and a bounds-explicit form
`dl-satan-memory-evidence-assemble-with-bounds (start end ctx opts)`.
The wrapper now derives `[start, end]` from CTX `:time_now` and OPTS
`:run_started_at` and delegates; all existing call sites are
unaffected.  The forthcoming Phase-5 observer will call the
bounds-explicit form directly to read the panopticon / git / fs
substrate covering a single intervention's 30-min attribution window
(an arbitrary historical span, not anchored to `time_now`).  One new
ert pins the contract; full suite 304/304 green.

## 2026-05-22 — SATAN: perceptual-layer v0 Phase 5.0 (motive `:project_cwd:`)

Schema bump on `motives.org` footer ahead of the Phase 5 outcome
observer.  `dl-satan-motive-parse` now recognises an optional
`:project_cwd:` field, expands `~/` at parse, and exposes the
absolute path as `:project_cwd` on the motive plist.  Empty values
normalise to nil.  The capsule renderer is unchanged — the field
is observer-only metadata, never surfaced to the model.  Existing
motives without the field continue to parse cleanly and remain
correlatable; only the path-scoped sub-predicates of the
forthcoming observer (file edits + git ref in the motive's cwd)
will skip for them.  Five new ert (303/303 green).

## 2026-05-22 — SATAN: perceptual-layer v0 Phase 4 (sensor alerts)

Closes §S6 of the perceptual design.  Every run's evidence assembler
now computes a per-source freshness check; the broker dispatches a
loud notification through the existing `notify_send` tool handler
when a sensor degrades (cooldown + quiet-hours gated).  Each fired
or suppressed alert is recorded under a new `pre_spawn` key on the
run's `actions.json`, so the audit shows what was held back as well
as what fired.

- **4.1 freshness check** — `dl-satan-memory-evidence-assemble`
  gains per-source probes that tag the assembled evidence with a
  JSON-friendly `:sensor_status' plist:
  `(:current_window "ok"|"stale-Nm"|"missing"|"malformed"
    :focus … :browser … :bough "ok"|"unreachable")`.
  Stale slices are dropped from the evidence (set nil / '()) so
  the canonicalizer never sees stale data; the status entry
  remains so the dispatcher can see the cause.  Thresholds are
  `dl-satan-memory-evidence-current-window-stale-seconds` (5 min)
  and `--segment-stale-seconds` (30 min).  Bough reachability is
  derived from dynamic counters bumped inside `--bough-call'.
- **4.2 sensor_status threading + capsule sensor block** — new
  `satan/dl-satan-sensor-alerts.el' owns the §S6 render side:
  `dl-satan-sensor-render-block FRAMING SENSOR-STATUS' emits
  `# Sensors' / `sensors: current=ok focus=ok browser=ok bough=ok'
  with degraded statuses in uppercase (`STALE(28m)' /
  `UNREACHABLE' / etc.).  `broker--spawn' extracts `:sensor_status'
  out of the evidence and attaches it to PREPARE;
  `dl-satan-context--with-prepare' mirrors it; `--render-prompt'
  places the block between `# Motive' and `# Today (raw)'.
  Self-suppresses when framing key or status plist are absent
  (same shape as percept / resonance / motive blocks).
- **4.3 sensor-alerts dispatcher** — public entry
  `dl-satan-sensor-alerts-check' returns the list of pre_spawn
  entries for the run.  Per-cause cooldown (defcustom
  `--cooldown-seconds', default 24h) and quiet-hours suppression
  (via `dl-satan-tick-quiet-p', resolved lazily to keep the
  require graph acyclic) gate dispatch.  Dispatch routes through
  `dl-satan-tool-dispatch' on a synthetic `notify_send' tool_call
  so the capability rail enforces `notify' — removing the
  capability from the mode produces a `suppressed: true, reason:
  capability_denied' entry (A17).  Bough fires only after the
  consecutive-unreachable streak hits the threshold (defcustom,
  default 3); below it the entry records as
  `streak_below_threshold'.  Cooldown state lives in
  `~/.local/state/satan/notified.json' under `:causes' (alert
  state) + `:streaks' (bookkeeping); writes are atomic
  tmp+rename.
- **4.4 actions.json `pre_spawn' integration** — `broker--spawn'
  invokes `sensor-alerts-check' alongside percept/resonance/motive
  and attaches the entries to PREPARE `:pre_spawn'.
  `broker--finalize' threads them into the actions plist passed
  to `dl-satan-audit-close' so the run's `actions.json' carries
  the new key (Phase 0.3 already accepted it; Phase 4.4 is the
  first real producer).  A16 one-to-one — every entry stamps the
  cause's `:last_evaluated_at' in `:causes' so the invariant holds
  regardless of dispatch outcome.

`docs/satan/perceptual-design.md` §8 A15 + A16 + A17 + A18 green.
Front-matter `status:` flipped from `phase-3-shipped` to
`phase-4-shipped`.

Mind seed: `system/framing.txt` += `sensor_block_header=# Sensors'
(lands in the ~/notes repo separately — mind owns its own commit
cadence).

Tests: 296/298 ert (same two pre-Phase-0 failures), 26/26 python
unittest.  Byte-compile clean.

## 2026-05-22 — SATAN: perceptual-layer v0 Phase 3 (motive file)

Picks up where Phase 2 stopped.  A small, bounded prose file
(`~/notes/satan/motives.org`) now carries persistent intent across
runs.  The broker reads it on every tick and renders an active-
motive block into the capsule between `# Resonance` and `# Today
(raw)`.  Two new tools let the model read and atomic-replace the
file under bounded write-side guards.  No new substrate, no LLM in
the parse path; pure org-style prose + a small footer schema.

- **3.1 parser + footer schema** — new `satan/dl-satan-motive.el`
  with `dl-satan-motive-parse` / `-read` / `-render-block` /
  `-validate-for-write`.  Footer accepts `:cue:` `:cooldown_s:`
  `:worked_count:` `:last_intervention_at:`; rejects `:ceiling:`
  (v0 deferred, see §3 of the design doc).  A motive without a
  valid `:cue:` is dormant — file-tolerated, capsule-invisible,
  observer-skipped (A8).  §S3 cue admission mirrors the §S2
  resonance gate by *namespace* prefix (handle strings have no
  rule_id provenance to inspect): admitted are app, surface,
  surface_transition, domain_kind, domain_transition, bough_event,
  bough_node, bough_project, artifact, topic, phase, focal_app.
  Missing file = empty parse (silent self-suppression, mirrors
  the resonance gate-skip pattern).
- **3.2 motive_read + motive_replace handlers** — new
  `satan/dl-satan-tools-motive.el`.  `motive_read` (`risk read`,
  no capability) returns the raw file + a counts plist
  (`active_motives`, `dormant_motives`, `ruminations_count`,
  `max_active`, `max_ruminations`) so the model can judge
  headroom before proposing a replacement.  `motive_replace`
  (`risk medium`, `capability motive-write`) atomic-writes via
  tmp + rename; validation runs before any I/O so a rejected
  payload leaves the file untouched.  Capability rail (Phase 0.2)
  enforces the new `motive-write` capability — `morning` /
  `motd` / `tick-*` modes get it added to their `:capabilities`
  lists alongside `memory-write` etc.
- **3.3 broker call + capsule render** —
  `dl-satan-broker--spawn` calls `dl-satan-motive-read` after
  `dl-satan-resonance-derive` and attaches the parse to PREPARE
  `:motive`.  `dl-satan-context--with-prepare` mirrors `:motive`
  alongside `:percept` / `:resonance`; `--render-prompt`
  inserts a `# Motive` block between `# Resonance` and `# Today
  (raw)` per §S1 sequence.  Mind owns `motive_block_header` in
  `framing.txt`; `dl-satan-motive-file` /
  `dl-satan-motive-archive-file` defcustoms live in the substrate
  module so the broker doesn't need the tool-handler layer.
- **3.4 bound precedence + naming contract** — new constant
  `dl-satan-motive-bound-precedence` codifies the first-breach-
  wins order (`:forbidden-field > :too-many-active >
  :too-many-ruminations > :invalid-cue`) so a `:ceiling:` can't
  sneak through a fix-the-count edit and the author trims before
  tightening cues.  Tests pin the precedence in collision payloads
  and lock the model-facing error string to surface the bound
  name for every entry in the precedence list (A7).

`docs/satan/perceptual-design.md` §8 A7 + A8 + A9 green.  Front-
matter `status:` flipped from `phase-2-shipped` to
`phase-3-shipped`.

Mind seeds landed under `~/notes/satan/`: `motives.org` (3 motive
stubs + 2 ruminations); `motives.archive.org` (empty paper-trail
seed); `tools/motive_read.md` + `tools/motive_replace.md` (model-
facing tool notes).  `system/framing.txt` gets
`motive_block_header=# Motive`.

Tests: 201/203 ert (the same two pre-Phase-0 failures), 26/26
python unittest.  Byte-compile clean.

## 2026-05-22 — SATAN: perceptual-layer v0 Phase 2 (auto-resonance)

Picks up where Phase 1 stopped.  Every run now derives a cue from
its percept handles, applies the §S2 anti-generic-recall gate, and
when admitted calls `memory_resonate` against the existing store.
Top matches (≤3) render into the prompt capsule between `# Percept`
and the mode-specific blocks.  No new substrate, no LLM in the
path; just wiring around primitives Phase 1 and the memory
subsystem already shipped.

- **2.1 + 2.2 cue derive + gate + broker call** — new
  `satan/dl-satan-resonance.el` with `dl-satan-resonance-derive`.
  Reads the percept's `:handles` + per-handle `:rule_id`, admits the
  cue iff at least one handle's rule is NOT in the §S2 exclude
  list (`ctx.mode`, `time.day_week`, `cwd.project`,
  `cwd.file_kind`).  On admit, calls
  `dl-satan-memory-store-resonate` with `:limit 3`.  Returns a
  plist with a `:status` slot — `ok` / `gate-skip` /
  `memory-unreachable` / `no-match` — so audit can tell the four
  no-block paths apart.  `dl-satan-broker--spawn` runs derive after
  percept persist and attaches the result to PREPARE `:resonance`.
  psql errors return `memory-unreachable`, not a run failure
  (handover watch-out; design §S6 promised the same).
- **2.3 capsule render** — `dl-satan-context--render-prompt` inserts
  a `# Resonance` block after `# Percept` and before `# Today (raw)`.
  Block lines render per design §S2: `- <trace_id>  score N.N` then
  `    matched: handle1, handle2, …`.  Header text owned by mind:
  `~/notes/satan/system/framing.txt` gets `resonance_block_header`.
  Block self-suppresses unless status=ok AND ≥1 match (A4).
  `dl-satan-context--with-prepare` mirrors `:resonance` alongside
  `:percept` so bundle.json agrees with what landed in the prompt.
- **2.4 fixtures** — `satan/test/dl-satan-resonance-test.el` (19
  tests).  Unit-level tests use a stubbed store to drive
  gate-skip / no-match / psql-down paths.  Real-percept fixtures
  build percepts from frozen sensors and lock the gate to the
  canon's actual rule ids — if a canon rule renames
  (`cwd.project` → `cwd.git_project`), the test trips before the
  noise floor silently weakens.

`docs/satan/perceptual-design.md` §8 A4 + A5 green.  Front-matter
`status:` flipped from `phase-1-shipped` to `phase-2-shipped`.

Tests: 161/163 ert (the same two pre-Phase-0 failures), 26/26
python unittest.  Byte-compile clean.

## 2026-05-22 — SATAN: perceptual-layer v0 Phase 1 (percept skeleton)

The first phase that's actually visible to the model.  Every run now
builds a deterministic percept from the existing memory substrate
and folds it into the system prompt.  No new substrate, no LLM in
the path, no auto-resonance yet (Phase 2).

- **1.1 + 1.2 percept builder + persist** — new `satan/dl-satan-percept.el`.
  `dl-satan-percept-build` calls `dl-satan-memory-evidence-assemble`
  then `dl-satan-memory-canon-canonicalize` over the prepare-phase
  ctx (frozen `:time_now` / `:run_id`).  `dl-satan-percept-persist`
  writes `percept.json` next to `bundle.json` under
  `~/notes/satan/runs/<id>/` via the same atomic-rename path the
  rest of the audit bundle uses.  Threaded into
  `dl-satan-broker--spawn` so the prepare plist carries the
  `:evidence` + `:percept` slots Phase 0.1 reserved (A1).
- **1.3 capsule render** — `dl-satan-context--render-prompt` inserts
  a `# Percept` block between `# Now` and the mode-specific blocks.
  Header text owned by mind: `~/notes/satan/system/framing.txt` gets
  a new `percept_block_header` key.  Block lists only the handles
  the canon actually emitted — A6 holds because no rule emits
  absence.  Every context-fn (-morning -motd -tick -self-edit) now
  actively reads the prepare run_ctx via
  `dl-satan-context--with-prepare', mirroring `:run_id', `:time_now',
  `:percept' into the bundle so audit artifacts agree across disk
  (A2).
- **1.4 golden tests + determinism rig** — new
  `satan/test/dl-satan-percept-test.el` (12 tests).  Covers shape,
  persist (A1), bundle/percept identity (A2), byte-identical re-run
  over a frozen focus+browser fixture (A3), capsule render (A4
  partial — resonance lands in Phase 2), absent-handle suppression
  (A6).  Sensor surface quarantined the same way the evidence-test
  file does it (`:behaviour_dir' = tmp tree;
  `dl-satan-bough-program' shunted to /nonexistent/).

`docs/satan/perceptual-design.md` §8 A1–A3 + A6 green.  A4 partial
(resonance + motive blocks deferred to Phase 2/3).  A5 deferred (no
gate runs in Phase 1).  Front-matter `status:` flipped from
`phase-0-shipped` to `phase-1-shipped`.

Tests: 140/142 ert (the same two pre-Phase-0 failures from missing
`docs_list` requires), 26/26 python unittest.  Byte-compile clean.

## 2026-05-22 — SATAN: perceptual-layer v0 Phase 0 prerequisites

Lands the four sub-phase prerequisites the v0 perceptual loop sits on.
Phases 1–6 (percept, auto-resonance, motive file, sensor alerts,
observer, cooldown floor) all assume this shape; nothing visible to
the model yet.

- **0.1 broker prepare + run_ctx threading** — `dl-satan-broker--prepare`
  is now the single allocator of `run_id` + frozen `time_now`. The
  resulting run_ctx plist is threaded into context-fn (2nd arg),
  `--tool-ctx` (reads frozen time; no per-call `format-time-string`),
  and `dl-satan-audit-open` (stored on handle for later phases).
  Carries v0 placeholder slots (`:evidence` `:percept` `:sensor_status`
  `:pre_spawn` `:motive`) so later phases `plist-put` without keyword
  ordering surprises.
- **0.2 dispatch capability guard** — tool-spec `:capability` slot.
  Dispatcher rejects before the handler runs when the mode's tool-ctx
  lacks the required capability. Broker emits an `action-failed` audit
  record on every denial using the canonical
  `(:action ACTION :reason MSG)` plist shape. `notify_send` is the
  first migrated tool (`:capability 'notify`); inbox / hippocampus /
  etc still guard at handler-side as defense-in-depth, migration is
  follow-up.
- **0.3 actions.json pre_spawn schema bump** — optional `pre_spawn`
  key on actions.json carrying a list of discriminated-union entries
  (only `sensor_alert` in v0; parser shape is open). New pure
  validator `dl-satan-audit-validate-actions` and verifier predicate
  `dl-satan-audit-p/pre-spawn-shape`. Count invariants against
  `final.actions` continue to ignore `pre_spawn`.
- **0.4 python harness mirror** — `harness/protocol.py` learns
  `check_actions_json` + `validate_actions_json` mirroring the elisp
  validator. `protocol/fixtures.json` gains `direction=actions`
  exemplars (3 valid, 4 invalid). Both ert and unittest suites
  iterate them via the existing fixture loader.

`docs/satan/perceptual-design.md` §8 A0a–A0e all green. Front-matter
`status:` flipped from `draft` to `phase-0-shipped`.

Tests: 128/130 ert (two pre-existing fails predate Phase 0 —
`docs_list` missing require in the test bootstrap), 26/26 python
unittest. Byte-compile clean. Integration test still skipped (needs
`SATAN_TEST_JAIL_BIN`).

## 2026-05-21 — SATAN: `docs_*` lazy lookup over chunked docs

Follow-up to the 03398479 reshape: SATAN can now pull its own docs
on demand instead of relying on an eager canon ingest. Three new
read-only tools register through the standard broker surface:

- `docs_list` — every chunk under `docs/satan/` + `docs/emacs/` as
  `{name, description, path, type, topic, status}`; no bodies.
- `docs_search :query? :topic? :type? :status?` — same skinny shape,
  filtered by frontmatter exact-match plus a case-insensitive literal
  substring grep on the body. With no filters, returns all chunks.
- `docs_read :name` — full body for one slug.

Files:

- `satan/dl-satan-tools-docs.el` — purpose-local frontmatter parser
  (no YAML lib; shape is fixed and tiny), corpus walker over
  `dl-satan-tools-docs-roots` (default `docs/satan` + `docs/emacs`,
  resolved against `user-emacs-directory`), three handlers + three
  registrations.
- `satan/test/dl-satan-tools-docs-test.el` — 23 ert tests against a
  fixture tree under `satan/test/docs-fixtures/{satan,emacs}/`
  covering parser (happy + malformed), walker, schema validation,
  and each handler. 23/23 green.
- `satan/dl-satan.el` — `(require 'dl-satan-tools-docs)`.
- `satan/dl-satan-mode.el` — adds `docs_list`, `docs_search`,
  `docs_read` to `:tools` for `morning`, `self-edit-mech`, and
  `self-edit-mind`. `motd` and `tick-*` deliberately skipped.
- `~/notes/satan/tools/docs_list.md`, `docs_search.md`, `docs_read.md`
  — model-facing descriptions (mind/mechanism split per governance
  §Ownership): when to use each tool, params, return shape, enum
  values for `topic`/`type`/`status`. Notes repo; committed
  separately.
- `docs/satan/governance.md` — Tools table + Modes table + file map
  + notes-tree section refreshed.

Out of scope (deliberate): bumping `verified_at` on chunks not
re-read; updating `satan/dl-satan-patch-*.el` comment refs to the
old md paths; migrating loose `docs/*.md` into the frontmatter
scheme; Claude-side skill / settings.json wiring.

Live sanity: real-corpus `docs_list` smoke returns 17 chunks
matching the post-reshape `fd` count.

## 2026-05-21 — SATAN: recent-runs awareness block for tick modes

Tick runs were amnesic between invocations — useful for keeping
prompts uncontaminated, but it left them prone to looping on the
same hypothesis or re-issuing the same `inbox_append`. Filling that
gap: a `# Recent SATAN runs` block now lands in the rendered prompt
when a mode-spec carries `:recent-runs N`. Default `N = 5` for both
`tick-pulse` and `tick-agent` via `dl-satan-tick-register` defaults;
other modes unchanged.

- `dl-satan-context.el` — new `--list-recent-runs`,
  `--summarize-run`, `--tally-tool-calls`, `--render-recent-runs`
  helpers. Walks `dl-satan-runs-dir` date buckets descending,
  reads each leaf's `final.json` (summary, clipped to 280 chars)
  and `transcript.jsonl` (tool-call tally, excluding
  `satan_final`). Block rendered alongside now/today/sources
  via the existing framing-key mechanism. Silent skip when the
  runs dir is missing or empty.
- `~/notes/satan/system/framing.txt` — adds optional
  `recent_runs=# Recent SATAN runs` header. Renderer falls back
  to the default header if absent so missing-framing isn't
  load-bearing.
- `dl-satan-tick.el` — `:recent-runs 5` added to
  `dl-satan-tick-register` defaults; opt-out by passing
  `:recent-runs nil` in overrides.
- `satan/test/dl-satan-context-test.el` — new ert file (12 tests):
  list ordering, bucket / non-bucket filtering, summarizer
  extraction (time / mode / status / summary / tools), summary
  clipping with ellipsis, FAILED-without-final handling,
  `satan_final` exclusion, end-to-end tick context-fn emits or
  omits the block based on `:recent-runs`.

Standing verification: 12/12 new + 112/112 phase-3 unchanged. Live
smoke (one tick → bundle.json carries the block) and a side-by-side
behavioural check still pending the next scheduled tick.

## 2026-05-21 — docs: reshape satan + AGENTS docs into linked chunks

Consolidated satan documentation under `docs/satan/` and slimmed
`AGENTS.md` to ~80L. Every chunk now carries YAML frontmatter
(`name`, `description`, `metadata.{type,topic,status,updated_at,verified_at}`)
matching the claude-memory convention, so a future satan/claude
doc-search tool can discriminate without re-reading prose.

- `docs/SATAN.md` → split into `docs/satan/governance.md`
  (philosophy + file map + modes/tools/ops) and
  `docs/satan/architecture.md` (trust flow + 7 conceptual layers).
- `satan/HANDOVER.md` (was gitignored, memory-substrate-specific) →
  `docs/satan/memory/handover.md` (tracked).
- `satan/memory.design.md` → `docs/satan/memory/design.md`.
- `satan/patch-harness{,.plan,.handover.2}.md` →
  `docs/satan/patch/{brief,plan,handover}.md`; the older
  `patch-harness.handover.md` → `patch/archive/handover-phase3-mechanism.md`.
- `satan/protocol/PROTOCOL.md` → `docs/satan/protocol.md`.
- `satan/bough-gaps.md` → `docs/satan/bough-gaps.md`.
- `docs/{AT-SATAN,PLAN-AT-SATAN}.md` → `docs/satan/at-satan/{design,plan}.md`.
- New: `docs/satan/INDEX.md` (one-liner per chunk, canon-eligible).
- `AGENTS.md` opening doctrine preserved; trap detail, naming,
  secrets, debug commands carved out to `docs/emacs/`. AGENTS keeps
  trap names + when-change-requires-what table + link list. SATAN
  gets a top-level pointer to `docs/satan/INDEX.md`.
- `satan/harness/protocol.py` docstring path updated.
- SHAs stamped in immediate follow-up commit `6f017819`.

No elisp changes. No satan reader tooling. No content rewrites beyond
frontmatter and specific cross-ref path fixes. Section anchors
(`§N.M`) untouched — heading text unchanged.

## 2026-05-21 — SATAN: DR-116 follow-up — recent_changes consumes status_log

Bough DR-116 shipped (`node status-transitions` + `node created`).
SATAN's `recent_changes` scope drops the `updated_at` proxy and now
composes the two peer event feeds.

- `dl-satan-bough--scope-recent-changes` invokes
  `bough --json node status-transitions --since SINCE` and
  `bough --json node created --since SINCE`; returns
  `(:scope "recent_changes" :since :transitions [...] :created [...])`.
- `dl-satan-memory-evidence--bough-recent` synthesizes
  `:event "status_changed"` per transition row and
  `:event "created"` per created row; emits a flat list with
  transitions first.  The canon rule `bough.recent_status_change`
  (`dl-satan-memory-canon.el:357`) — previously dormant since the
  substrate shipped — now fires on real status moves.
- `satan/bough-gaps.md` B1 closed; `memory.design.md` §10.2 mapping
  row flipped from "degraded" to "composable".

Files: `satan/dl-satan-tools-bough.el`,
`satan/dl-satan-memory-evidence.el`,
`satan/test/dl-satan-tools-bough-test.el` (+2 ert),
`satan/test/dl-satan-memory-evidence-test.el` (+3 ert).

## 2026-05-22 — Journal links: idempotent `* Links` navigation section

New idempotent `* Links` section in daily and weekly journal notes
(both personal and work).  Inserted automatically on note creation
and updated on open.

- `my/journal--insert-links` — finds or creates `* Links` heading,
  replaces content with prev/next day (or week) links, the parent
  week link, and the cross-realm counterpart (personal↔work).
- All links use `file:` with absolute paths, not `denote:`, because
  both realms share the same `YYYYMMDDT000000` identifier for the
  same date, making bare `denote:` links ambiguous.
- Backed by new helpers: `my/journal--buffer-realm`,
  `my/journal--parse-basename`, `my/journal--slug-date`,
  `my/journal--slug-iso-week`, `my/journal--iso-week-monday`,
  `my/journal--other-file`, `my/journal--construct-path`,
  `my/journal--links-string-for-file`, `my/journal--links-string`.
- Hooked into `my/journal--ensure-file` (capture-template path) and
  `my/journal--open` (interactive path + existing-note backfill).

File: `org/dl-denote-journal.el`.

## 2026-05-20 — SATAN: patch-agent companion for satan-patcher daemon

Two small changes prepare the elisp side for the runner extraction at
`~/dev/satan-patcher`:

- `dl-satan-patch-store-insert` now wraps its INSERT in a CTE that
  fires `pg_notify('patch_jobs_new', $id)` for queued rows only.  The
  satan-patcher daemon's `LISTEN patch_jobs_new` wakes immediately
  without polling.  Non-queued inserts (seeded history) deliberately
  suppress the NOTIFY so the daemon doesn't chase already-terminal rows.
- New `dl-satan-patch-runner-enabled` defcustom (default `t`).  Flip
  to `nil` to hand the queue off to the daemon; `tick`, `kick`, and
  `start-timer` all short-circuit when nil so the elisp side stops
  competing for `claim-next` rows.

Tests: 2 new store tests (NOTIFY fires + suppressed-when-non-queued
via an async psql LISTEN session) and 1 new runner test
(disabled-short-circuits leaves the row queued).  All 248 satan tests
pass; the pre-existing grammar/db-sync-current-version failure is
unrelated.

The runner stays the default execution path until the daemon has been
side-by-side validated against `satan_memory`.  See
`~/dev/satan-patcher/docs/handover.md` and
`satan/patch-harness.handover.md` for the full cutover plan.

## 2026-05-20 — SATAN: cap self-edit bundle size; report dropped files

`dl-satan-context-self-edit` previously packed every matching
file under the mode's roots verbatim into `:sources`.  As
`~/.emacs.d/satan/` grew the mech bundle reached ~860k chars
(~215k tokens), exceeding Anthropic's 200k context window with
`400 - This endpoint's maximum context length is 200000 tokens`.

New `dl-satan-self-edit-bundle-char-budget` (default 600000 ≈
150k tokens) caps total `:sources` content.  Files are packed
alphabetically; once adding the next file would push total
content over budget, it (and all subsequent files) goes into a
new `:dropped-files` bundle field instead.  The model sees what
it didn't get and can recommend a narrower mode or use targeted
reads.

Budget is char-based not token-based to stay tokenizer-agnostic.
600k × ¼ ≈ 150k tokens leaves ~50k headroom under a 200k window
for tool schemas + model output.  Setting the defcustom to nil
restores pack-everything (e.g. for batch runs against larger
context windows).

Tests: 100-char budget over three 60-char files keeps one drops
two; nil budget includes everything.

## 2026-05-20 — SATAN: syslog + streak-aware notify on run failure

Every non-`done` terminal run now emits a
`logger -t satan -p user.warn` line — visible via
`journalctl --user -t satan -p warning`.  Format:

```
satan failed tick-pulse 20260520T143022-tick-pulse-…  child-exit-1
satan budget-exceeded tick-pulse … 425510/400000
```

Plus a D-Bus desktop notification on the **first failure of a
streak only**.  Streak = consecutive `.FAILED` run dirs walking
newest-first; once the user has been told, subsequent failures
stay quiet until at least one `done` run breaks the chain.  This
keeps the notify channel useful when scheduled ticks fire every
30 minutes and a budget-exhaustion or auth blip would otherwise
spam the desktop.

Two defcustoms toggle each channel independently:

- `dl-satan-failure-syslog` (default t)
- `dl-satan-failure-notify` (default t)

Wired from both terminal paths (`--finalize` and the budget-
denied pre-spawn gate).

## 2026-05-20 — SATAN: date-bucketed run dirs + `.FAILED` suffix

Run-dir layout under `~/notes/satan/runs/` changes from flat
`<run-id>/` to bucketed `<YYYY-MM-DD>/<run-id>/`. After 74 runs in
one day, the flat dir was already painful to `ls`; projected
thousands of entries motivated splitting on the date stamp the
run-id already carries.

Terminal runs whose status is anything other than `done` now have
their dir renamed to `<run-id>.FAILED`. Failures (broker timeouts,
provider errors, budget-denied, invalid-protocol) are visible at
a glance under each day's bucket without opening every `status`
file. The `runs/most-recent` symlink is repointed after the
rename so `cd $(readlink most-recent)` keeps working.

Backward compatible: existing 74 flat-layout dirs continue to be
read by budget enumeration and the tank's recent-events panel.
New helpers in `dl-satan-broker.el` centralise enumeration:

- `dl-satan-broker-list-run-dirs` — walks both layouts, skipping
  `most-recent` and bucket-dir-itself; returns absolute paths.
- `dl-satan-broker-run-dirs-for-date` — same, filtered to one day.
- `dl-satan-broker-run-dir-for-id` — where a fresh run-id's dir
  should be created (bucketed).
- `dl-satan-broker-locate-run-dir` — find an existing dir given a
  run-id, probing bucketed → bucketed-FAILED → legacy flat →
  legacy-FAILED in order.

`dl-satan-budget-today-total` and `dl-satan-tank--recent-runs` /
`--read-run-events` now route through the helpers; ad-hoc
`directory-files` scans gone.

Tests: helper coverage for date-bucket extraction, FAILED-suffix
stripping, list-run-dirs (both layouts + noise), locate-run-dir
(all four fallback rungs).

## 2026-05-20 — SATAN: scrub unresolved op:// refs from child env

When the broker's primary key-resolution path fell through (op
desktop locked, `op read` transiently failed), the explicit
`provider-env` entry was skipped but the same `KEY=op://…` line
still inherited from `process-environment` via the direnv merge,
reaching the child harness verbatim. The provider then returned
an opaque `401 Your api key: ****tial is invalid` — the tail of
"credential". Survey of `~/notes/satan/runs/` found two such
failures today (`14:24`, `14:59`), both after the 10:07 op heap-
cache fix landed (which closed a different leak path).

Belt-and-braces fix on both sides of the broker→harness boundary:

- `dl-satan-broker--scrub-op-refs` filters `KEY=op://…` entries
  out of the env list immediately before `make-process`. When
  resolution succeeds the provider-env entry (earlier in the list)
  is preserved; when it fails the child simply sees no key var
  and the harness raises a clean `KEY not set`.
- `build_provider` in `harness/providers/__init__.py` rejects any
  key value starting with `op://` so the harness still fails
  loudly if a ref slips through some other path in future.

Tests: `dl-satan-broker/scrub-op-refs-drops-unresolved-keys`
covers the elisp filter; `ProviderFactoryTests
.test_unresolved_op_ref_key_raises` covers the python guard.

## 2026-05-20 — SATAN: memory list command + drop payload truncation in store-recent

`my/satan-memory-list` (new) pops `*satan-memory*' with the last N
traces (default 20, prefix-arg overrides) as `TRACE-ID  KIND
OBSERVED  PAYLOAD`. `my/satan-memory-show` now `completing-read`s
over recent IDs with kind/time/payload annotation so picking an
ID from the list is one keystroke; non-interactive callers
unchanged.

`dl-satan-memory-store-recent` previously SQL-truncated payloads
at 200 chars (`LEFT(t.payload, 200)`). The original rationale
("keep tab-split parser single-line") was already satisfied by the
newline/tab → space replacement; the 200-char cap was redundant
and produced the truncated bodies visible in `my/satan-tank`'s
RECENT TRACES section. Cap removed; full payload returned. Tank
already wraps via `fill-region`, so this just lets long
observations render in full. The list command applies its own
elisp-side preview cap (120 cols, ellipsis) so the one-line table
stays readable. Regression test
`recent-returns-full-payload` locks in 400-char round-trip.

## 2026-05-20 — SATAN: scaffold evidence discipline defines observable vs interpretation

`system/scaffold.txt` Evidence discipline gains an inline definition:
observable = what you directly read (tool result, file content, memory
hit, panopticon segment); interpretation = inference from incomplete
evidence. When acting on interpretation, the model must name the
evidence it rests on. Tightens the prior "prefer observable cues"
exhortation, which left the boundary undefined.

Companion proposal "consolidate duplicated scaffold across mode
prompts" rejected: premise was false — mode prompts (`morning.txt`
30 lines, `motd.txt` 27, `self-edit-mind.txt` 52, `self-edit-mech.txt`
47, `tick/pulse.txt` 55) contain mode-specific scope/flow only, not
scaffold restatement. Broker already renders scaffold + mode prompt;
consolidation already in place.

## 2026-05-20 — SATAN: clarify owned-surface taxonomy (auto-apply vs proposal-first)

Two self-edit-mind proposals accepted in `~/notes/satan/`:

- `system/scaffold.txt` "Ownership and write boundaries" rewritten as
  "Write boundaries" with an explicit two-bucket taxonomy: SATAN-owned
  *auto-apply* surfaces (daily block, motd via `satan_final.summary`,
  hippocampus, inbox, memory tools) vs *proposal-first* surfaces
  (`~/notes/satan/proposals/` via `proposal_stage`). Each surface now
  cites the tool that writes it. Rationale baked into the prompt:
  auto-apply is working memory + inbox; proposals are the user-review
  contract. Removes the confusion where staging-via-`proposal_stage`
  could read as ownership instead of deferral.
- `prompts/morning.txt` and `prompts/motd.txt` no longer say "do not
  propose changes outside owned surfaces" (which conflicted with
  scaffold treating proposals themselves as an owned surface). Both
  now state that proposals are an available owned output and should be
  used freely for risky edits / design questions / behavioural changes.

Net effect: mode prompts and the scaffold now agree that proposals are
SATAN-owned-but-deferred, and the model is encouraged to stage rather
than second-guess whether staging is allowed.



`notes_at_satan_done` no longer collapses run-id + comment into an
inline `@satan-done(<run-id>,<comment>)` marker. It now writes
`@satan-was-here` in place of the `@satan` token and inserts a quoted
summary block on the following lines:

```org
@satan-was-here <preserved trailing text>
#+BEGIN_QUOTE satan <run-id>[,<tag>]
<body>
#+END_QUOTE
```

Markdown files render the block as `> `-prefixed lines instead of the
org quote pair. Block lines inherit the original line's leading
whitespace so list items stay aligned.

The `comment` argument is split on the first `:` — left half becomes a
tag appended to the block header (after the run-id, comma-separated),
right half becomes the body. A comment with no colon renders body-only.

Scan exclusion regex now matches `@satan-was-here`; old
`@satan-done(...)` lines are not recognized, so any pre-existing
claims will resurface on the next scan (none in the wild yet —
feature recently landed).

New ert coverage: markdown blockquote rendering, no-colon comment,
indent propagation. All seven `notes-at-satan-` tests pass.

Docs updated: `AT-SATAN.md`, `satan/patch-harness.md`. Embedded code
excerpts in `AT-SATAN.md` are now flagged as a snapshot; canonical
source is `satan/dl-satan-tools-atsatan.el`.

## 2026-05-20 — SATAN: `@satan` agent-trigger tooling (AT-SATAN)

New `tick-agent` tick mode that scans `~/notes/` for `@satan` directives
and claims them in place. Two new tools in
`satan/dl-satan-tools-atsatan.el`:

- `notes_at_satan_scan` (`:risk read`): `rg --json` for `@satan`
  substring, excludes `**/satan/**`, filters out `@satan-done` lines in
  elisp, enriches each match with `±N` context lines, walks back to the
  nearest org/markdown headline, returns a stable per-scan `id`.
- `notes_at_satan_done` (`:risk low`, needs new `write-notes` capability):
  rewrites the `@satan` token in place as
  `@satan-done(<run-id>,<comment>)`. Optimistic re-read makes the claim
  idempotent (`already-done` on a second call). Id index is per-Emacs
  session; tick-agent always scans before claiming.

Wiring: `morning` mode gains `notes_at_satan_scan` (read-only visibility,
no write capability); `tick-agent` carries both tools plus a curated
action set (inbox, hippocampus, memory, bough, agenda). Tick pool
default rebalanced to `tick-pulse:5 / tick-agent:3`.

Spec at `AT-SATAN.md`. Two deviations from the verbatim spec, both
real bugs in the spec text caught by tests / live smoke:

1. `--exclude-globs` is `!**/satan/**` not `!satan/**` — bare
   `satan/**' does not exclude when rg traverses an absolute path.
2. `--rewrite-line' uses explicit `string-match` + `substring` instead of
   `(replace-regexp-in-string ... nil 1)` — non-nil START omits any text
   before START from the returned value, which silently ate the leading
   `- ` list bullet in live tests.

## 2026-05-20 — SATAN: in-session 1Password caching for jailed harness

Per-tick 1Password biometric prompts for `my/satan-tick' are gone.
Root cause: `satan-jailed-gptel-harness' was built with the default
`useOpEnv = true', so its outer wrapper exec'd `op run --env-file=…'
on every launch, re-resolving op:// refs and bypassing the Emacs
broker's `my/op--cache' (which already caches resolved plaintext for
the session).

Fix in `~/flakes/pub/jailed-agents.nix': split secret injection into
two flags. `useOpEnv' keeps controlling the outer `op run' wrapper;
new `passApiKeysFromEnv' (defaults to `useOpEnv') controls the inner
bwrap `--setenv VAR "$VAR"' forwarding. Long-lived callers that
already cache resolved secrets can set `useOpEnv = false;
passApiKeysFromEnv = true;' to keep the env forwarding without the
per-launch biometric prompt.

`~/.emacs.d/flake.nix': `satan-jailed-gptel-harness' now opts into
that pattern. Broker pre-resolves via `my/op-read-env' once per
Emacs session; subsequent ticks hit `my/op--cache' and never call
`op'. `M-x my/op-forget' clears the cache (next tick re-prompts).

Docs: `pub/README.md' gains a "Pre-resolved secrets" subsection and
an options-table row; `_templates/agents/flake.nix' header and
inline knob list mention the new flag.

## 2026-05-20 — SATAN: tank LAST RUN section

Tank gains a fourth section between RECENT TRACES and RECENT EVENTS:
a structured summary of the newest completed run pulled from its
`transcript.jsonl' (run-id, mode, status, duration, cumulative
tokens, ordered tool calls with ok/error, fill-wrapped final
summary, action count).  Status is derived from event tags
(`final', `timeout', `protocol-error', otherwise `in-progress').

- `satan/dl-satan-tank.el': `--last-run-status', `--last-run-state',
  `--iso-duration', `--wrap-paragraph', `--gather-last-run',
  `--render-last-run'.  Refresh inserts the new section.
- `satan/test/dl-satan-tank-test.el': +5 ert covering aggregator
  status branches and renderer formatting.  Suite now 23/23.

## 2026-05-20 — SATAN: provider profiles + deepseek thinking-mode round-trip

Provider/model now live in `dl-satan-profiles' (alist of NAME →
plist). Each mode-spec carries `:profile NAME' instead of duplicating
`:provider'/`:model'. Mode-level keys still win over profile, so a
mode can pin one half without owning both. Built-in profiles:
`claude-haiku' (openrouter/claude-haiku-4.5) and `deepseek-pro'
(deepseek/deepseek-v4-pro).

`tick-pulse' moves to `deepseek-pro'. Recent run data: cold-start
spikes blew the 30 s wall-clock on ~20% of ticks, and the 10k token
ceiling was fictional (real spend 10–36k across multi-turn tool
chains). Bumped to 60 s / 40k.

Harness round-trips DeepSeek's `reasoning_content'. v4-pro returns
the thinking trace on every assistant turn and rejects the next
request with HTTP 400 unless the field is echoed back. Captured on
`CompletionResult', attached to the assistant message in
`append_assistant_with_tools', forwarded by the OpenAI SDK via its
TypedDict-loose message shape.

- `satan/dl-satan-mode.el`: `dl-satan-profiles' + `--apply-profile'
  merge in `dl-satan-mode-register'. All five built-in modes now use
  `:profile'.
- `satan/dl-satan-tick.el`: tick-pulse → `:profile 'deepseek-pro',
  `:timeout-seconds 60', `:budget-tokens 40000'.
- `satan/harness/providers/base.py`: `CompletionResult.reasoning_content'.
- `satan/harness/runloop.py': `append_assistant_with_tools' threads
  `reasoning_content' onto the message dict.
- `satan/test/dl-satan-test.el': tick assertion bumps.

## 2026-05-20 — SATAN: observation tank

Adds `my/satan-tank` (buffer `*satan-tank*`), a read-only composite
view mirroring what SATAN sees right now. Three sections refresh on
a timer (default 5 s; `g` for manual, `q` to quit):

1. **EVIDENCE WINDOW** — `dl-satan-memory-evidence-assemble` output
   rendered compactly: window times, current panopticon app/title,
   focus / browser segment counts, top bough_active nodes, git state,
   cwd, and any `:truncated_at` passes.
2. **RECENT TRACES** — last N marks via the new `store-recent` reader.
3. **RECENT EVENTS** — tail of run transcripts under
   `dl-satan-runs-dir` with a one-line summary per record
   (`tool-call(args)`, `tool-result → ok|error`, `log:<kind>`,
   `timeout`).

Section renderers are pure (state plist in, string out); gatherers
swallow errors so a degraded section never blanks the buffer.

- `satan/dl-satan-memory-store.el`: new `dl-satan-memory-store-recent`
  reader — `SELECT … ORDER BY observed_end_at DESC LIMIT N` with
  optional `:kinds` / `:grammar-version` filters. Returns
  `(:trace_id :kind :valence :observed_end_at :payload :handles)`
  plists, payload newlines/tabs collapsed to spaces.
- `satan/dl-satan-tank.el`: new module — section renderers, gatherers
  (`evidence-assemble` synth ctx, `store-recent`, transcript tail),
  `dl-satan-tank-mode`, timer lifecycle gated on buffer kill,
  `my/satan-tank` entry point.
- `satan/dl-satan.el`: aggregator pulls in `dl-satan-tank`.
- `satan/test/dl-satan-memory-store-test.el`: +4 ert covering
  `store-recent` (empty / order / limit / kind-filter).
- `satan/test/dl-satan-tank-test.el`: 18 ert covering pure helpers,
  three renderers (nil + populated), `--read-run-events` against
  a fixture transcript, and `--recent-runs` ordering.

Memory subsystem now 130/130; tank suite 18/18.

## 2026-05-20 — SATAN: memory quality sweep — §5 (outcome canon dormant by design)

Docs-only. Closes sweep §5 by declaring the LLM-side outcome canon
path dormant rather than backfilling a `hint.outcome` rule. v1
outcome traces are the scorer (`trace_origin = auto_rule`) lane,
not the `memory_mark` lane; the server-side §9.12 invariant
remains load-bearing future-proofing for the v2 scorer.

- `satan/memory.design.md`: new §8.1 "v1 canon path: dormant by
  design" inventories what the schema admits (closed-world
  `outcome` namespace, `traces.outcome`, server-side invariant)
  vs. what v1 deliberately omits (no canon rule, no hints-shape
  entry, no handler plumbing); explains the prediction/scoring
  split rationale and the v2 wake conditions.
- `satan/HANDOVER.md`: sweep §5 entry struck through with
  done-pointer to §8.1.

No code, schema, or test changes. Memory subsystem still 126/126.

## 2026-05-20 — SATAN: memory quality sweep — §6

Adds a `:cue_only` knob to the evidence assembler so
`memory_resonate`'s cue-derivation pass skips heavy probes that
do not influence the cue. Trims 3 of the 4 bough shell-outs and
both panopticon segment reads per resonate call when no explicit
`cue.handles[]` is supplied.

- `satan/dl-satan-memory-evidence.el`: new opt `:cue_only` (`nil`
  default). When `t`, `focus_segments` and `browser_segments` are
  returned as `'()`, and `bough_recent` / `bough_day` as `nil`,
  without running their probes. `current_window`, `bough_active`,
  `git_state`, and `fs_state` still populate — they are the
  "what is now" signals cue derivation depends on. File header
  documents the knob.
- `satan/dl-satan-tools-memory.el` `--derive-cue-handles`: passes
  `:cue_only t` alongside `:run_started_at`. `--mark-impl` is
  unchanged (it needs the full window).
- `satan/test/dl-satan-memory-evidence-test.el`: new ert
  `assemble-cue-only-skips-heavy-probes` stubs the bough
  helpers to signal if called and asserts the four skipped fields.
- `satan/test/dl-satan-tools-memory-test.el`: 2 new ert —
  `resonate-derives-cue-with-cue-only-opt` (capture confirms
  `:cue_only t` flows through resonate handler) and
  `mark-does-not-set-cue-only` (mark path unaffected).

Memory 126/126 (+3).

## 2026-05-20 — SATAN: `notes_recent` tool

New read-risk tool that lists recently changed files under
`~/notes`, complementing `activity_read` (window focus) and
`org_read_context` (fixed files) by surfacing which artifacts the
user actually moved.

- `satan/dl-satan-tools-notes.el` (new): shells out to `fd
  --changed-after Nh -t f --print0 --base-directory ~/notes
  --exclude satan`, parses NUL-separated output, sorts by mtime
  desc, clamps `:since-hours` to [1, 720] and `:limit` to [1,
  200]. Denote-style basenames `DATE--SLUG__TAG_TAG.EXT` parse
  into `:title` (dashes→spaces) and `:tags` (underscore-split);
  non-denote basenames return `:title` nil.
- `satan/dl-satan.el`: requires the new module.
- `satan/dl-satan-mode.el`: adds `notes_recent` to morning + motd
  `:tools` lists.
- `satan/dl-satan-tick.el`: adds `notes_recent` to the tick-pulse
  default `:tools` list.
- `satan/test/dl-satan-test.el`: new test block stubs
  `call-process` via `cl-letf` and covers argv build, mtime sort,
  limit/since-hours clamp + default, denote-vs-plain basename
  parse, fd non-zero exit, empty output. Manifest fixtures for
  morning + budget-exceeded broker test get the new description
  entry.
- Caller must drop a model-facing description at
  `~/notes/satan/tools/notes_recent.md` (loaded at manifest build
  time per `dl-satan-tools.el:24-30`) before live runs.

## 2026-05-20 — SATAN: memory quality sweep — §2

Wires the broker's run start-time and per-call wall clock through
the tool-ctx so the evidence assembler can bound the window by run
start instead of falling back to the 10-minute default.

- `satan/dl-satan-broker.el`: `dl-satan-broker--tool-ctx` adds
  `:run-started-at` (formatted from `dl-satan-run-start-time`) and
  `:time-now` (formatted at call time), both ISO8601.
- `satan/dl-satan-tools-memory.el` `--ctx-from`: reads `:time-now'
  from tool-ctx (falls back to `--now' for older fixtures), and
  threads `:run-started-at` onto the canon ctx as `:run_started_at'.
  `--mark-impl' and `--derive-cue-handles' now forward
  `:run_started_at' to `dl-satan-memory-evidence-assemble' as an
  opts plist. Top-of-file comment drops the entry for this sweep.
- `satan/dl-satan-tools-hippocampus.el` `--cross-ref`: reads
  `:time-now` and `:run-started-at` from tool-ctx (falls back to
  wall clock for time, nil for run-start) and forwards
  `:run_started_at' to the assembler.
- `satan/test/dl-satan-test.el`: new ert
  `dl-satan-broker/tool-ctx-shape` asserts the keys + ISO8601
  formatting.
- `satan/test/dl-satan-tools-memory-test.el`: 3 new ert covering
  prefers-tool-ctx-time-now, falls-back-to-wall-clock, and
  mark-forwards-run-started-at-to-evidence (via a new
  `--capture-evidence-opts` macro).

Phase-3 95/95 (+1); memory 123/123 (+3).

## 2026-05-20 — SATAN: memory quality sweep — §3

Closes the `normalize-hints` + `canonicalize` two-step dance for
substrate callers.

- `satan/dl-satan-memory-canon.el`:
  `dl-satan-memory-canon-canonicalize-from-raw` now also returns
  `:normalized PLIST`, exposing the closed/open-world hint scalars
  the inner `normalize-hints` already computed (kind, valence,
  phase, topic, focal_app, focal_bough_nanoid, outcome_for).
  Existing `:handles` / `:handle_sources` / `:rejected` keys are
  unchanged.
- `satan/dl-satan-tools-memory.el` `--mark-impl` and
  `--derive-cue-handles`, and
  `satan/dl-satan-tools-hippocampus.el` `--cross-ref`: replaced
  the manual `normalize-hints` + `canonicalize` call pair with a
  single `canonicalize-from-raw`, reading `:kind` / `:valence` off
  the new `:normalized` key. Top-of-file comment in
  `tools-memory.el` no longer lists the workaround.
- `satan/test/dl-satan-memory-canon-test.el`: new ert asserts the
  normalized scalars come back on `canonicalize-from-raw` (kind,
  valence, phase, topic, focal_app).

Canon ert 34/34 (+1 normalized); memory 120/120; phase-3 94/94.

## 2026-05-20 — SATAN: memory quality sweep — §1

Extends the elisp tool args-schema with a working `:type 'array'
contract.

- `satan/dl-satan-tools.el`: `dl-satan-tool--validate-arg` is now a
  lookup wrapper around a new `dl-satan-tool--validate-value` helper
  so element-level checks can reuse the same constraint logic. New
  branch on `:type 'array'` rejects non-array values
  (`"arg KEY must be array"`) and, when `:items` is supplied,
  validates each element with a label of the form `KEY[N]`. New
  `dl-satan-tool--items-constraints` coerces `:items SYMBOL` (legacy)
  to `(:type SYMBOL)` so both spellings work.
- `dl-satan-tool--args-schema-to-jsonschema` now delegates `:items`
  rendering to `dl-satan-tool--items-jsonschema`: symbol items keep
  their `(:type "string")` shape; constraint-plist items can carry
  `:enum`/`:pattern`; `(:type 'object :shape ...)` items recurse so
  the manifest emits a full nested object schema with `properties`
  and `required`.
- `satan/test/dl-satan-test.el`: 7 new ert covering non-array
  rejection, scalar-element happy path, element-type mismatch with
  indexed label, object-element shape validation (required missing
  + ok), and the matching jsonschema fragments.

Phase-3 94/94 (+7); memory 119/119.

## 2026-05-20 — SATAN: memory quality sweep — §4 + §7

Two small post-v1 cleanups from `HANDOVER.md` "Quality sweep":

- §4 `satan/dl-satan-memory-store.el`: docstring drift — per-handle
  `:source` is a PLIST (consumed by `--prep-plist`), not an ALIST.
  Doc-only.
- §7 `satan/dl-satan-tools.el` + `satan/dl-satan-tools-memory.el`:
  `dl-satan-tool--validate-arg` now has a `:type 'number` clause
  (`"arg %s must be number"`), so the dispatcher rejects non-numeric
  values before the handler runs. `memory_resonate`'s handler-side
  `(not (numberp min-score))` check drops out; the existing
  `resonate-bad-min-score-rejected` ert still passes because the
  validator's error message contains `min_score`.

Memory subsystem 119/119; phase-3 87/87.

## 2026-05-20 — SATAN: memory step 11 — acceptance §9 sweep + docs

Substrate-level closure of the v1 memory work.  Walks every §9
acceptance criterion in `satan/memory.design.md` and lands the one
missing enforcement (§9.10 bough isolation across the substrate);
the remaining 13 criteria were already covered by golden / store /
tool / renormalize / canon-purity ert.

- `satan/test/dl-satan-memory-canon-test.el`: new
  `dl-satan-memory/bough-isolation` lint walks every
  `dl-satan-memory-*.el` source file and refuses any reference to a
  bough DB name (`bough_production`, `bough_agent`), the bough
  binary path (`dl-satan-bough-program`), or the low-level invoker
  (`dl-satan-bough--invoke`).  All reads must reach bough through
  the `bough_read' tool handler — the only path admitted by
  `memory.design.md` §0.5.
- `SATAN.md`: file map gains every memory module, every memory
  migration, the bough/memory tool handlers, the cross-ref hook
  note on hippocampus, and the new test files; modes table picks
  up `bough_read`, `memory_*`, and `sway_border_*` per the step-9
  wiring; tools table documents the four new tools and their risk /
  capability shape; notes-tree gains the four new tool description
  files.
- `satan/bough-gaps.md`: B1 section gains a status block recording
  bough's in-flight DR-116 (per-status-transition CLI) and the
  three-step SATAN follow-up (`recent_changes` scope, evidence
  synthesis of `:event "status_changed"`, composing `node created`
  alongside).  The dormant canon rule
  `bough.recent_status_change` wakes once that lands; out of v1
  memory scope.

Memory subsystem 119/119 (118 + 1 bough-isolation lint); phase-3
87/87; integration 1/1.

## 2026-05-20 — SATAN: memory step 12 — hippocampus cross-ref hook

Closes §10.7 of `memory.design.md`.  Every `hippocampus_write`
performed by a mode that also holds `memory-write` (currently
`morning`) now emits an `auto_rule` observation trace pointing at
the org file via `metadata_json.hippocampus_path`.  The trace shape
is identical to LLM-marked observations (canon-emitted handles,
full evidence snapshot), differing only in `trace_origin`.

- `satan/dl-satan-tools-hippocampus.el`: requires the memory
  substrate; adds `dl-satan-tools-hippocampus--cross-ref` and
  invokes it after the org write when the tool-ctx carries the
  `memory-write` capability.  Cross-ref errors are soft-logged and
  never bubble up — the file write remains the load-bearing
  side-effect.
- `satan/dl-satan-memory-store.el`: `--prep-value` now treats any
  non-plist list as a JSON array (previously bare lists of scalars
  like `:tags ("ux")` from real bough nodes tripped `json-serialize`)
  and stringifies symbols.  Latent since step 7; surfaced by the
  first production-shaped evidence blob reaching the store.
- `satan/test/dl-satan-tools-hippocampus-test.el` (new): three ert
  (no-cross-ref-without-memory-write, cross-ref-with-memory-write,
  cross-ref-soft-fail-on-bad-db).

Memory subsystem 118/118 (115 + 3 hippocampus); phase-3 87/87;
integration 1/1.

## 2026-05-20 — SATAN: memory step 10 — renormalize CLI + grammar-bump golden test

Closes the §7 grammar-bump replay path and lands acceptance §9.8.
Operator can now bump grammar versions and replay canonicalization
across every stored trace without touching the trace row itself.

- `satan/dl-satan-memory-migrate.el`: appended `dl-satan-memory-renormalize`
  (per-trace BEGIN/COMMIT; flips old `trace_handles` rows to
  `active = FALSE`; inserts fresh rows under the target version),
  `dl-satan-memory-renormalize-status` (read-only `(:by-version
  :stale-traces)`), and `my/satan-memory-renormalize` interactive
  wrapper.  Worker is idempotent: a pass whose newly-canonicalized
  handle set matches the currently-active set skips the transaction
  entirely.
- `satan/memory/migrations/0004_grammar_v2_fixture.sql` (new):
  smallest-possible v2 bump that copies v1 weights + aliases forward
  and adds `planning -> phase:orientation`.  Seeds v2 in the test
  DB on every reset; stays pending in production until an operator
  applies it.
- `satan/test/dl-satan-memory-renormalize-test.el` (new): six ert
  (`no-op-when-current`, `single-trace-bump`, `idempotent`,
  `per-trace-tx`, `renormalize-status/counts`, `acceptance-9-8`).
  `cl-letf` rebinds the elisp grammar constants to v2 + the planning
  alias for the bumped-shape tests; per-trace-tx test forces a canon
  error on the second trace via a `cl-letf` wrapper and asserts the
  first trace's commit survives.
- `satan/test/dl-satan-memory-migrate-test.el`: `applies-real-migrations`
  bumped to `(1 2 3 4)` / length 4 for the new fixture migration.

Memory subsystem 115/115 (109 prior + 6 renormalize); phase-3 87/87
(no regression); integration 1/1 against the fake harness.  The
fixture migration lives in the migrations dir so the golden test
applies it through the same runner operators will use; it is
deliberately operator-applied, never LLM-reachable.

## 2026-05-20 — SATAN: memory step 9 — wire substrate into broker

First shared-file touch since the memory work began.  Three modes
admit the new tools; one new aggregator becomes the broker's single
entry point for the substrate.

- `satan/dl-satan-memory.el` (new): aggregator that requires the five
  `dl-satan-memory-*` submodules + `dl-satan-tools-{memory,bough}`,
  plus `my/satan-memory-resonate`, `my/satan-memory-show`, and
  `my/satan-memory-status` interactive commands for poking the store
  from Emacs.
- `satan/dl-satan.el` requires the aggregator; the rest of the chain
  resolves transitively.
- `dl-satan-mode.el`: `morning` and `motd` admit `bough_read`,
  `memory_mark`, `memory_resonate`, `memory_show_trace` (and declare
  `memory-write` capability); `self-edit-mech` / `-mind` admit only
  `bough_read`, `memory_resonate`, `memory_show_trace` (read-only —
  no mark, no `memory-write`).
- `dl-satan-tick.el`: tick-mode defaults inherit the same write-side
  surface as morning, so `tick-pulse` can mark memories.
- `dl-satan-tools.el`: lifted deferred-sweep item §1.  Array support
  in the JSON Schema builder (`:type 'array` + optional `:items`
  scalar) — forced now because the four array-shaped args on the
  memory tools (`memory_mark.links`, `memory_resonate.kinds`,
  `cue.handles`, `hints.topic`) previously declared empty constraints
  and tripped `dl-satan-tool--jsonschema-type` with a nil type when
  the broker built a real manifest.
- `dl-satan-tools-memory.el`: declares the array shape explicitly on
  those four args.
- `test/dl-satan-test.el`: requires `dl-satan-memory` so the registry
  has the new tools at test time; description stubs in the manifest
  + budget-denied tests now cover all admitted tools; the self-edit
  `:tools` assertion was relaxed from exact-list to `member` to keep
  the test stable across future additive mode edits.

Memory subsystem 109/109; phase-3 87/87 (no regression); integration
1/1 against the fake harness; `nix build .#satan-jailed-gptel-harness`
clean.  After this commit every memory tool is broker-dispatchable
from a real run; step 10 (renormalize CLI) and step 11 (acceptance
§9 pass + SATAN.md/CHANGELOG narrative) can run in either order.

## 2026-05-20 — SATAN: memory step 8 — memory_* tool handlers

`satan/dl-satan-tools-memory.el` registers the three model-facing
memory tools (`memory_mark`, `memory_resonate`, `memory_show_trace`)
on top of the existing canon + evidence + store stack. Tool surface
matches `memory.design.md` §5.1–5.3.

- `memory_mark` (risk: low, capability: memory-write): assembles the
  evidence window, normalizes hints, canonicalizes against the
  current grammar, writes one trace + handles + links via
  `dl-satan-memory-store-mark`. Returns `{trace_id, handles[],
  rejected[]}`. The broker stamps `trace_origin = "llm_mark"` and
  `source = "memory_mark@<mode_name>"`.
- `memory_resonate` (risk: read): explicit `cue.handles` bypasses
  the evidence pipeline; absent handles re-derive from `cue.hints`
  through the same canon. Returns `{matches[], cue_handles[]}`.
  Read-only per §6.4 — no `access_count` / `last_accessed_at`
  mutation.
- `memory_show_trace` (risk: read): pass-through to
  `dl-satan-memory-store-show`.
- All three register with `:modes nil` — the first shared-file
  touch (mode allowlists + `(require)` wiring) is reserved for
  step 9. The substrate is loadable but not yet broker-reachable.
- Mind-side descriptions at `~/notes/satan/tools/memory_{mark,
  resonate,show_trace}.md` (mind/mechanism split per SATAN.md).
- 28 new tool ert. Memory subsystem now 109/109 (9 mig · 6 gram ·
  32 canon · 16 ev · 18 store · 28 tool). Phase-3 87/87 (no
  regression). Byte-compile clean.

Six quality-sweep items captured in `satan/HANDOVER.md` for the
deferred pass after step 11 (the most actionable: lift array
support and a `:type 'number'` branch into `dl-satan-tool--validate-arg`).

## 2026-05-19 — SATAN: memory step 7 — store backend (mark/resonate/show)

`satan/dl-satan-memory-store.el` lands the transactional storage and
retrieval surfaces for the memory substrate. Implementation: psql
subprocess (R3, §6.1) feeding stdin scripts so `:'var'` substitution
works (psql `-c` doesn't perform it).

- Migration `0003_memory_functions.sql` installs four SQL functions:
  `handle_weight_for`, `memory_mark_trace` (PL/pgSQL; one insert per
  table, enforces the §9.12 outcome invariant server-side),
  `memory_resonate` (inverted-index lookup, scored), `memory_show_trace`
  (json round-trip of trace+handles+links). Applied to both
  `satan_memory_test` and `satan_memory`.
- `dl-satan-memory-store-mark` accepts canon-shaped handle plists and
  passes a single JSONB blob built with `json-serialize` + explicit
  vectors for arrays (avoids `json-encode`'s plist/array ambiguity).
- `dl-satan-memory-store-resonate` and `-show` are read-only — no
  `access_count` / `last_accessed_at` mutation in v1 per §6.4.
- Acceptance §9 partials green: 9.7 idempotent re-mark, 9.11
  zero-weight bough_node, 9.12 outcome invariant, 9.14 origin
  admission. Full §9 pass deferred to step 11.
- 18 new store ert; total memory-subsystem suite 81/81.

Migrate test count assertion updated for the new migration row.

## 2026-05-19 — SATAN: memory step 6 — evidence-window assembler

`satan/dl-satan-memory-evidence.el` lands the impure side of the
memory substrate: bounded reads of panopticon
(`~/.local/state/behaviour/`), bough (via `bough_read` only — no
parallel DB read), `git`, and a small `recentf` heuristic, assembled
into the plist consumed by `dl-satan-memory-canon-canonicalize`.

- Bounds (§4.1): `end = ctx.time_now`, `start = max(end − 10 min,
  run_started_at)`; segments capped at 10, bough_recent at 50.
- Truncation (§4.3) is deterministic, five passes: drop bough_day
  bodies → middle-drop browser segments → middle-drop focus segments
  → shrink long bough_active annotations → drop bough_recent at the
  hard cap. Each pass that fires is recorded in `:truncated_at`.
- Bough output (tree-shaped) is flattened depth-first into the flat
  list `dl-satan-memory-canon` expects for `bough_active` /
  `bough_recent`; canon rules don't need to know about trees.
- 16 new ert pass; total memory-subsystem suite is 63/63.

No shared file touched — registration into the broker, mode
allowlists, and `dl-satan.el` `require` happen at step 9.

## 2026-05-19 — SATAN: tick-pulse budget 3000 → 10000

`tick-pulse` was hitting its 3000-token soft cap mid-turn (observed:
budget exhausted at 5044 tokens with one extra turn after warn). Most
ticks still no-op early; the higher ceiling gives the model room to
finish a turn when it does act. `:budget-tool-calls` and
`:timeout-seconds` unchanged.

- `satan/dl-satan-tick.el` — `:budget-tokens 10000`; header doc string
  updated to match.
- `satan/dl-satan-tick.el` — `dl-satan-tick-quiet-hours` defcustom
  default is now `nil` (quiet hours opt-in); the previous `'(22 . 7)`
  default lives on as a comment for reference.
- `satan/test/dl-satan-test.el` — assertion updated.
- `~/notes/satan/prompts/tick/pulse.txt` — claim updated to match.

## 2026-05-19 — SATAN: prompt tightening (sway_border, satan_final, show-why)

Notes-side only (`~/notes/satan/`, commit `98e04c7` in that repo). No
code change. Prepares ground for the memory-substrate prompt rewrite
without referencing `memory_*` tools that don't exist yet.

- `prompts/morning.txt` — `Terminate with a 'final' message` was drift
  from the rest of the bundle; replaced with the same `satan_final` +
  JSON-blob warning as the scaffold.
- `prompts/{morning,motd,tick/pulse,self-edit-mech,self-edit-mind}.txt`
  now list `sway_border_set` / `sway_border_reset`. The tools have
  been in every mode's elisp allowlist since `663083c1`; the model-
  facing prompts had not caught up.
- `system/scaffold.txt` — two additive lines: (1) "adversarially
  intimate, not managerial" tone rule; (2) "show why" — any action
  that interrupts the user or alters the environment
  (`notify_send`, `sway_border_*`, `proposal_stage`) must name the
  concrete cue.
- `prompts/tick/pulse.txt` — adds the intervention hierarchy
  (`inbox < border < notify < proposal`) and reinforces the
  show-why rule inline.

## 2026-05-19 — SATAN: memory substrate, step 5 (canonicalizer + purity lint)

Step 5 of the memory-substrate plan (`satan/HANDOVER.md`). Lands the
pure canonicalizer that turns evidence + LLM hints + ctx into canonical
handles and per-handle source provenance.

- `satan/dl-satan-memory-canon.el` — new module. Strictly pure (no
  shell, no IO, no clock outside `ctx.time_now`); the purity boundary
  is enforced by a grep-lint test that reads every form via `read'
  and refuses if any of `shell-command`, `call-process`,
  `insert-file-contents`, `url-retrieve`, `current-time`, etc., appear
  in code (comments stripped). Rule registry via a `defrule` macro;
  rules are individually defunable and testable. 14 rules landed,
  covering every entry in `memory.design.md` §3.3 (panopticon
  current/transitions/docs, bough recent/active, cwd project/file_kind,
  ctx mode, time day_week, hint topic/phase/focal_app/focal_bough_nanoid;
  `panopticon.event_transition` is explicitly inert per §10.8).
- Hint normalization: closed-world fields (kind, phase, valence)
  validated against the grammar with up-to-5 suggestions on rejection;
  open-world fields (topic, focal_app) slug-normalized; topic deduped
  and capped at 5.
- Origin priority: when the same handle is emitted by multiple rules,
  the dispatch keeps the highest-priority source (observed > derived >
  ctx > hint). Handles are returned sorted for stable diffs.
- `satan/test/dl-satan-memory-canon-test.el` — 22 ert: pure helpers,
  hint normalization (including rejection with suggestions), one test
  per rule (incl. inert rule), origin-priority dedup, sort stability,
  end-to-end through the raw entry point, two golden-fixture round-trips
  (minimal_firefox, rich_window — full sweep through every rule), and
  the purity grep-lint.
- `satan/test/canon-fixtures/{minimal_firefox,rich_window}.json` —
  golden inputs + expected handle sets.

47/47 ert green across the full memory test suite (migrate + grammar +
canon); byte-compile clean. Not yet wired into `dl-satan.el` — step 9.

## 2026-05-19 — SATAN: memory substrate, step 4 (grammar v1 + drift detector)

Step 4 of the memory-substrate plan (`satan/HANDOVER.md`). Lands the
in-process mirror of grammar v1 and the drift detector that the
canonicalizer depends on for step 5 (per R4).

- `satan/dl-satan-memory-grammar.el` — new module. Pure-data
  constants mirroring `memory.design.md` §2 verbatim:
  `dl-satan-memory-grammar-namespaces` (26 namespaces, open/closed
  world), `-closed-values` (15 enums per §2.2), `-aliases` (6 entries
  per §2.3), `-default-weights` (24 namespace defaults per §2.4),
  plus `-current-version = 1`. Accessors: world / closed-values /
  alias-target / default-weight / valid-value-p.
- `satan/test/dl-satan-memory-grammar-test.el` — 6 ert. Three pure:
  every closed-world namespace has a values entry (and vice versa);
  accessors return known values; `valid-value-p` distinguishes
  closed/open/unknown. Three DB-sync: `MAX(grammar_versions.version)`
  equals `-current-version`; `handle_aliases` for v1 equals
  `-aliases` set-wise; `handle_weights` v1 + `__default__` rows equal
  `-default-weights`. Sync tests target `satan_memory` (override via
  `SATAN_MEMORY_TEST_DB` env var); skip when DB unreachable.

When grammar v2 lands, both sides change: a new migration adds rows
for the new version, and these constants bump `-current-version` and
add namespace/alias/weight entries. The sync test catches either
side moving alone.

## 2026-05-19 — SATAN: memory substrate, step 3 (bough_read tool)

Step 3 of the memory-substrate plan (`satan/HANDOVER.md`). Lands the
read-only path SATAN uses against the bough task tree — the *only*
permitted read path, with no direct PG access against the `bough_*`
databases anywhere in satan code.

- `satan/dl-satan-tools-bough.el` — new module. Shell-out to the pinned
  `bough --json` binary. Six scopes per `memory.design.md` §5.4:
  `node`, `recent_changes`, `active`, `day`, `week`, `project_subtree`.
  Composition per §10.2: `node` walks `parent_nanoid` upward to a
  16-deep root; `week` composes `day list` + per-day `day show`;
  `project_subtree` fetches the full subtree and prunes in elisp
  (default `max_depth=3`, marked with `:children_truncated_count` at
  the boundary). Degraded semantics for `recent_changes` (B1 — uses
  `updated_at` as proxy until bough exposes status-transition history)
  and `project_subtree` (B2 — until bough adds `--max-depth`) are both
  surfaced in the tool description.
- `satan/test/dl-satan-tools-bough-test.el` — 19 ert: registration
  shape, schema validation (scope enum + nanoid/date/ISO8601 patterns),
  per-scope required-arg checks, week-bounds math, depth-prune purity,
  unknown-scope rejection, plus three integration tests that skip when
  `bough` is missing.
- `~/notes/satan/tools/bough_read.md` — model-facing tool description
  (lives outside this repo).

Not yet wired into `dl-satan.el` or any mode allowlist — that's step 9
(per HANDOVER). The tool registers itself on load via the existing
`dl-satan-tool-register` surface.

## 2026-05-19 — SATAN: memory substrate, step 2 (migration runner + schema)

Step 2 of the memory-substrate plan (`satan/HANDOVER.md`). Establishes
the `satan_memory` PG database and a forward-only migration runner.

- `satan/memory/migrations/0001_init.sql` — schema v1 per
  `memory.design.md` §6.2: `traces`, `trace_handles`, `trace_links`,
  `handle_aliases`, `handle_weights`, `grammar_versions`,
  `schema_migrations`. All `CHECK` constraints, indexes, and the
  `^[a-z][a-z0-9_]*:[A-Za-z0-9][A-Za-z0-9_.+>-]*$` handle regex are in.
- `satan/memory/migrations/0002_grammar_v1.sql` — grammar v1 seed: one
  `grammar_versions` row, 6 aliases (§2.3), 24 namespace default weights
  (§2.4).
- `satan/dl-satan-memory-migrate.el` — new module. Shell-out to `psql`
  (R3 decided in `memory.design.md` §6.1). Per-file `--single-transaction`
  wraps both the SQL body and the `schema_migrations` INSERT, so the
  bookkeeping row cannot drift from schema state. Refuses to apply on
  version skip (must equal `max(applied)+1`) or checksum tamper.
  Public surface: `dl-satan-memory-migrate-apply`,
  `dl-satan-memory-migrate-status`, and the interactive
  `my/satan-memory-migrate{,-status}` commands.
- `satan/test/dl-satan-memory-migrate-test.el` — 9 ert against
  `satan_memory_test`: filename parsing (case-strict), duplicate-version
  rejection, ascending sort, real-migration apply, re-apply no-op,
  tamper detection, version-skip refusal, missing-file refusal.
- Both migrations applied to `satan_memory` via the runner.

Not yet wired into `dl-satan.el` (step 9 of the plan). Decision and
bough-CLI scope mapping recorded in `memory.design.md` §6.1 and §10.2.

## 2026-05-19 — SATAN: sway-border tools (ephemeral, runtime-only)

Two tools so SATAN can transiently retint sway window borders without
ever touching `~/.config/sway/config`. `swaymsg client.<class> ...` at
runtime; `swaymsg reload` reverts. Keybindings and `exec` lines are
unreachable by construction — the tool grammar admits only
`client.<class>` with six-tuples of hex-validated colours.

- `satan/dl-satan-tools-sway.el` — new module. `sway_border_set` is
  batched (one call may declare several classes); `sway_border_reset`
  takes no args and emits `swaymsg reload`. Class enum:
  `focused`, `focused_inactive`, `focused_tab_title`, `unfocused`,
  `urgent`, `placeholder`. Per-class: `border`, `background`, `text`
  required; `indicator`, `child_border` optional. Risk `medium` for
  both (visible, ephemeral, reversible).
- `satan/dl-satan-tools.el` — validator and JSON Schema mapper grow
  support for `:type 'object :shape (...)` (recursive) and `:pattern
  REGEXP` for string fields. No existing tool exercises the new branches.
- `satan/dl-satan-mode.el` + `satan/dl-satan-tick.el` — both tool
  names appended to every mode's `:tools` (morning, motd,
  self-edit-mech, self-edit-mind, tick defaults).
- `~/notes/satan/tools/sway_border_set.md`,
  `~/notes/satan/tools/sway_border_reset.md` — model-facing
  descriptions.
- `satan/test/test-sway-border.el` — 14 new ert: validator
  nesting/pattern/required, JSON Schema recursion, handler argv shape,
  unknown-class rejection, reset-emits-reload, mode allowlist.
- `satan/test/dl-satan-test.el` — fixture maps in two broker tests
  gain the sway tool descriptions; the self-edit mode-tool assertion
  is updated to expect the new entries.

Tests: 101/101 ert (87 unit + 14 sway). User runs `home-manager
switch --flake ~/flakes#david` after `git add` for the Nix wrapper to
see the new file.

## 2026-05-19 — SATAN: activity_read v2 — recent_browser + current scopes

Live smoke against OpenRouter confirmed `activity_read{scope:"today"}`
works end-to-end. Adding two more scopes the panopticon producer already
feeds.

- `satan/dl-satan-tools-activity.el` — adds `recent_browser` (mirrors
  `recent_focus` over `segments/browser-<today>.jsonl`; tail-N, default
  20, clamped 1..200) and `current` (single snapshot from
  `current/sway.json` — `app_id`, `workspace`, `output`, `title`, `pid`).
  Enum on `:scope` extended; both new scopes return ok with empty/nil
  data when the producer hasn't written the file yet.
- `~/notes/satan/tools/activity_read.md` — model-facing description
  expanded to cover the new scopes and the new title caveat.
- `satan/test/dl-satan-test.el` — 4 new ert: recent_browser tail,
  recent_browser missing file, current snapshot, current missing file.
  Test fixtures gain `--write-browser-jsonl` and `--write-current-sway`.
- `SATAN.md` — tool-table row refreshed; new open thread #10
  "`activity_read` current-scope title leak" documents the deliberate
  decision to pass sway's window-title through verbatim (acceptable for
  now; future work either strips at the SATAN boundary or has panopticon
  emit a `current/sway-public.json` without title).

Tests: 87/87 ert (+4), 21/21 python, 1/1 integration,
`nix build .#satan-jailed-gptel-harness` clean.

## 2026-05-19 — SATAN: activity_read tool (panopticon consumer)

Panopticon's sway watcher + firefox extension + segmentizer landed
earlier today, so the behaviour state at `~/.local/state/behaviour/`
now contains a daily histogram, focus segments, and (when the
segmentizer has run) browser segments. New `activity_read` tool gives
SATAN read-only access for behaviour-aware prompts.

- `satan/dl-satan-tools-activity.el` — new module. Scope `today`
  returns the parsed `histograms/daily-<today>.json` plist
  (per_app_seconds, per_workspace_seconds, per_hour_seconds, plus the
  browser per-domain seconds when merged in). Scope `recent_focus`
  returns the tail-N segments from `segments/focus-<today>.jsonl`
  (default 20, clamped to 1..200). Both scopes return ok with empty
  data when the file is missing — common at start-of-day before the
  segmentizer fires — rather than erroring, so the model can branch
  on "no activity data yet" without losing the rest of the turn.
- `~/notes/satan/tools/activity_read.md` — model-facing description
  (mind side). Documents the two scopes, the producer-side PII
  redaction, and the start-of-day empty-data condition.
- `satan/dl-satan.el` — `(require 'dl-satan-tools-activity)`.
- `satan/dl-satan-mode.el` — adds `activity_read` to the `morning`
  and `motd` mode-spec `:tools` allowlists. `motd` doesn't run for
  long so the tool is informational; `morning` gets the richest use.
- `satan/dl-satan-tick.el` — adds `activity_read` to the default tick
  allowlist so `tick-pulse` can decide whether to interrupt deep work.
- `satan/test/dl-satan-test.el` — 7 new ert: today happy path,
  today missing-file, recent_focus tail, default/clamp limits,
  recent_focus missing-file, unknown scope, dispatch enum guard.
  Fixture helpers `dl-satan-test--with-tool-descriptions` for the
  manifest-shape and budget-gate tests pick up the new tool too.
- `SATAN.md` — modules table, mode table, tool table, and
  External dependencies note refreshed.

The handler runs broker-side (Emacs), not inside the bwrap jail —
so no extra bind mounts are needed; the jail only sees the JSON-encoded
tool result.

Tests: 83/83 ert (+7), 21/21 python, 1/1 integration,
`nix build .#satan-jailed-gptel-harness` clean.

## 2026-05-19 — SATAN: soft budget UX (thread #4)

Budget exhaustion previously force-terminated mid-stream with a
synthetic `final{reason=budget_tokens}`. The model never knew it
ran out — it just stopped getting calls. Smoother: warn once, let
the model wind down on its own terms.

- `satan/harness/runloop.py` — on the first turn whose cumulative
  `tokens_total` crosses `SATAN_BUDGET_TOKENS`, emit
  `log{kind=budget_warning, tokens_total, budget_tokens}` and append a
  system-role nudge into the chat asking the model to call
  `satan_final` on its next turn. If the model finalises, normal final
  is emitted (no synthetic). If it persists (tool calls / plain text),
  the harness force-terminates with the old synthetic final — now an
  escape hatch rather than the primary path.
- `satan/protocol/PROTOCOL.md` — documents `budget_warning` as a known
  `log` kind; the protocol shape is unchanged (free-form `kind`
  namespace), so no fixture / validator changes.
- `satan/harness/test_gptel_harness.py` — replaces the old
  `test_budget_exhaustion_emits_final` with two cases:
  `test_budget_warning_then_model_finals` (happy path: warning emitted,
  model satan_finals, no synthetic) and
  `test_budget_warning_then_model_persists_forces_final` (escape
  hatch).
- `SATAN.md` — open thread #4 marked done.

Tests: 76/76 ert, 21/21 python, 1/1 integration,
`nix build .#satan-jailed-gptel-harness` clean.

## 2026-05-19 — SATAN: phase 3C-lite — OAI-compatible provider base + DeepSeek

OpenRouter's adapter was the only OpenAI v1 chat-completions client in
the harness; DeepSeek speaks the same dialect. Rather than duplicate
the SDK wiring + tool-call deserialisation, factor it into a shared
base class and re-derive providers as one-line config rows.

- `satan/harness/providers/base.py` — adds
  `OpenAICompatibleProvider(api_key, base_url=None)`. Subsumes
  the `from openai import OpenAI` client construction, the
  `chat.completions.create` call (with `tools=None` when empty), and
  the tool-call / usage deserialisation that previously lived in
  `OpenRouterProvider`. Subclasses set `base_url` as a class attr.
- `satan/harness/providers/openrouter.py` — thin subclass:
  `base_url = "https://openrouter.ai/api/v1"`.
- `satan/harness/providers/deepseek.py` — new thin subclass:
  `base_url = "https://api.deepseek.com"`. Reasoning models'
  `reasoning_content` field is not surfaced; `msg.content` already
  carries the final answer.
- `satan/harness/providers/__init__.py` — `build_provider()` now
  reads a `{provider_name: (subclass, key_env_var)}` registry. Adding
  another OAI-compatible provider is one registry row plus the
  subclass.
- `satan/harness/test_gptel_harness.py` — `ProviderFactoryTests`
  verifies openrouter + deepseek dispatch (subclass type, `base_url`,
  api key wiring), the default-provider fallback, and the three
  error paths (unknown provider, missing model, missing key). The
  real `openai` SDK is stubbed via `sys.modules["openai"]` so the
  tests don't require it.
- Broker side already plumbed: `dl-satan-broker-provider-key-vars`
  carries `(deepseek . "DEEPSEEK_API_KEY")`, `flake.nix` forwards
  the env var into the bwrap jail, and `~/.config/zsh/env.zsh` has
  the `op://` ref. `:provider 'deepseek` is now a valid mode-spec
  value.

Tests: 76/76 ert, 20/20 python (was 14/14; +6 factory tests),
1/1 integration, `nix build .#satan-jailed-gptel-harness` clean
(ruff passes).

Open thread #9 (native Anthropic/Gemini) remains explicitly deferred
per user direction.

## 2026-05-19 — SATAN: phase 3B — harness multi-file split

`gptel_harness.py` had grown into five concerns under one roof:
protocol validator, bundle loader, provider abstraction + adapter,
run loop, entry point. Phase 3B splits them into discrete modules so
the upcoming 3C-lite (OpenAI-compatible provider base + DeepSeek) is
a thin config change, not a surgical edit through a 500-line file.

- `satan/harness/protocol.py` — validator + `emit*` / `read_tool_result`
  helpers. (Moved from the PROTOCOL section of the old monolith.)
- `satan/harness/bundle.py` — `load_bundle`, `load_manifest`,
  `build_system_prompt`, `build_tools`.
- `satan/harness/runloop.py` — `RunState`, message accumulators, `run`,
  `main`. Provider- and protocol-agnostic.
- `satan/harness/providers/base.py` — `Provider` ABC + `CompletionResult`.
- `satan/harness/providers/openrouter.py` — `OpenRouterProvider`
  (OpenAI v1 chat-completions with base_url override).
- `satan/harness/providers/__init__.py` — `build_provider()` registry
  dispatched off `SATAN_PROVIDER` env.
- `satan/harness/__main__.py` — entrypoint. Adds its own directory to
  `sys.path` so absolute imports (`import protocol`,
  `from providers import build_provider`) resolve whether invoked
  via the nix bin or via `python -m unittest test_gptel_harness`.
  No top-level `__init__.py`; `providers/` is the only subpackage.
- `satan/harness/gptel_harness.py` — deleted.
- `flake.nix` — `satanGptelHarness` switches from
  `pkgs.writers.writePython3Bin` (single-file) to
  `pkgs.stdenv.mkDerivation` + `pkgs.makeWrapper` over
  `pkgs.python3.withPackages (ps: [ ps.openai ])`. `checkPhase` runs
  `ruff check` with the legacy ignore set (W503 / E704 dropped — ruff
  doesn't implement them).
- `satan/protocol/PROTOCOL.md` — note updated: both sides ship the
  validator as its own module.
- `satan/harness/test_gptel_harness.py` — imports rewritten to target
  the new modules; `mock.patch.object(runloop, "build_provider", …)`
  replaces the old `h.build_provider` patch. StubProvider subclasses
  `providers.base.Provider`. Same 14 tests; same coverage.

Tests: 76/76 elisp + 14/14 python + 1/1 integration.
`nix build .#satan-jailed-gptel-harness` clean.

## 2026-05-19 — SATAN: phase 3D — broker owns bundle framing

The `# Now` / `# Today (raw)` / `# Source files` section headers used to
be inlined in `gptel_harness.py`. That broke the mind/mechanism
invariant (no canonical model-facing prose in dotfiles) and forced
every alternative harness adapter to re-implement the same framing.
Phase 3D moves rendering across the membrane: the broker writes a
fully-assembled system prompt into `bundle["prompt"]`; the harness is
a passthrough.

- `~/notes/satan/system/framing.txt` (NEW, mind) — section headers as
  `key=value` lines. Required at run time; missing-file signals so
  prose cannot silently default in dotfiles.
- `satan/dl-satan-context.el` — `dl-satan-context--framing` parses the
  framing file; `dl-satan-context--render-{now,today,sources}` build
  per-section line lists; `dl-satan-context--render-prompt` assembles
  scaffold + mode + framing. Every context-fn (`morning`, `motd`,
  `tick`, `self-edit`) returns a bundle whose `:prompt` is the fully
  rendered system prompt. Structured fields (`:now`, `:today_text`,
  `:sources`) remain in the bundle for audit forensics but are no
  longer read by the harness.
- `satan/harness/gptel_harness.py` — `build_system_prompt(bundle)` is
  now `return bundle["prompt"]`. `_render_now` removed; the harness
  holds no canonical model-facing prose.
- `satan/test/dl-satan-test.el` — 8 new tests covering framing parse,
  missing-file/missing-key errors, per-block rendering, section
  ordering. Existing context-fn tests now write a framing.txt fixture.
- `satan/harness/test_gptel_harness.py` — drop the `# Now` /
  `# Today (raw)` / `# Source files` rendering tests (assertions moved
  elisp-side); add passthrough + missing-key assertions on
  `build_system_prompt`.

Closes SATAN.md open thread #9.

Tests: 76/76 elisp + 14/14 python + 1/1 integration ert.
`nix build .#satan-jailed-gptel-harness` clean.

## 2026-05-19 — Journal quick capture

Fast timestamped append into the daily journal's `* Log` from anywhere.

- `my/journal-quick-capture` (`org/dl-denote-journal.el`) — pops a
  small org buffer; `C-c C-c` / `C-RET` append the trimmed text as a
  `** [YYYY-MM-DD HH:MM]` sub-heading under today's `* Log` and
  dismiss; `C-c C-k` aborts. Creates `* Log` if absent. Multi-line
  content preserved. `my/work-journal-quick-capture` is the work
  variant.
- Display prefers a centered `posframe` child frame on graphical
  frames (`(use-package posframe :defer t)`); falls back to a
  below-selected side window in TTY or when posframe is unavailable.
  Restores input focus to the originating frame on dismiss.
- `C-c C-w` inside the capture buffer cycles the target through
  `dl-journal-quick-capture-targets` (personal → work → …) without
  losing typed text. Header line shows the active target label.
- `core/dl-keybind.el` — global `<f1>` runs the personal quick
  capture; `help-command` relocates to `C-<f1>` (C-h remains primary
  help prefix).

## 2026-05-19 — SATAN: phase 3A — protocol reification

The broker/harness JSONL membrane was implicit: ad-hoc `pcase` dispatch
on the broker side, hand-rolled `emit_*` helpers on the harness side,
no schema, no cross-side test contract. Phase 3A reifies it as a named
artifact with shared exemplars driving validator tests on both sides.

- `satan/protocol/PROTOCOL.md` — canonical message-type spec (inbound:
  `ready`, `log`, `tool_call`, `final`, `error`; outbound: `tool_result`).
- `satan/protocol/fixtures.json` — valid + invalid exemplars; each
  invalid entry carries an expected `reason` string. Loaded by both
  test suites.
- `satan/dl-satan-protocol.el` — elisp validator
  `dl-satan-protocol-validate` returning `nil | (:type T :reason R)`.
- `satan/harness/gptel_harness.py` — PROTOCOL section with `check`,
  `validate`, `ProtocolError`. `emit*`/`read_tool_result` now validate
  on the wire. (Validator stays inline rather than splitting into
  `harness/protocol.py` until the harness goes multi-file at phase 3B
  — nix `writePython3Bin` is single-file.)
- `satan/dl-satan-broker.el` — `dl-satan-broker--dispatch` validates
  inbound before pcase; `dl-satan-broker--send-validated` audits any
  malformed outbound (still sends; broker-malformed output is a bug
  flag, not a wire failure). Drops the bespoke
  `dl-satan-broker--validate-final` helper.
- Tests: ert and python both iterate `fixtures.json`, asserting valid
  fixtures pass and invalid fixtures fail with the recorded reason.

Tests: 68/68 elisp + 16/16 python + 1/1 integration ert.

## 2026-05-19 — SATAN: `:now` block in every mode bundle

Every context-fn now emits a `:now` plist (`iso_date`, `weekday`,
`iso_week`, `time`, `tz_offset`, `tz_name`) instead of scattered
`:date`/`:time` keys. The python harness renders it as a fixed `# Now`
section between the assembled scaffold/mode prompt and any
`today_text` / source-file sections, so the model has consistent
date/time/timezone framing regardless of mode.

- `satan/dl-satan-context.el` — new `dl-satan-context-now` helper;
  `morning`, `motd`, `tick`, and `self-edit` bundles all carry `:now`.
- `satan/harness/gptel_harness.py` — `build_system_prompt` renders
  `# Now` when the bundle includes `now`; absent → block omitted.
- `satan/test/dl-satan-test.el` — 4 new tests: now-plist shape +
  per-mode bundle inclusion.
- `satan/harness/test_gptel_harness.py` — `make_bundle` carries a
  canonical `now`; new tests cover render + skip-when-absent.

Tests: 63/63 elisp + 10/10 python.

## 2026-05-19 — SATAN: `agenda_read` tool (work calendar via gcalcli)

New read-only tool for the `morning` and `motd` modes. Shells out to
`gcalcli agenda --calendar $WORK_EMAIL` with a configurable day window
(default 5, clamped 1..14) and a hard `timeout(1)` wrapper so a stalled
gcalcli can't freeze the broker's host Emacs. Calendar id is sourced
from an env var (`WORK_EMAIL`) rather than hard-coded, so the dotfile
carries no identity.

- `satan/dl-satan-tools-agenda.el` — new handler + registration; risk
  `read`, no capability required, default 15s wall timeout.
- `satan/dl-satan-mode.el` — `agenda_read` added to the `:tools`
  allowlist for `morning` and `motd`.
- `satan/dl-satan.el` — `require dl-satan-tools-agenda` after the
  existing tool modules.
- `notes/satan/tools/agenda_read.md` — model-facing description.
- `lisp/dl-secret.el` — added `~/.config/zsh/work.identity.zsh` to
  `my/env-source-files` so launcher-started Emacs (sway, no zshrc)
  sees `WORK_EMAIL`. Terminal-launched Emacs already inherits it.
- `SATAN.md` — modes table (morning + motd), tools table, file map.
- Tests: 52 → 59 (happy path, `:days` honoured, clamp, missing env,
  non-zero exit, `timeout(1)` exit 124, mode allowlist via dispatcher).

## 2026-05-19 — Waybar: SATAN inbox unread badge

New `custom/satan-inbox` waybar module showing the unread count from
`my/satan-inbox-unread-count`. Hidden when zero (or when the emacs
server is unreachable); click opens the inbox in the running emacs
frame via `emacsclient -ne '(my/satan-inbox)'`.

- `~/.config/waybar/scripts/satan-inbox.sh` — new; emits waybar JSON
  with `text` + `class` (`unread` / `empty`); guards against non-numeric
  output when emacsclient fails.
- `~/.config/waybar/config.jsonc` — module declared (60s interval) and
  inserted in `modules-right` immediately after `custom/agenda`.
- `~/.config/waybar/style.css` — added `#custom-satan-inbox` to the
  shared muted-pill group; `.empty` class collapses padding/border so
  the module disappears at zero.

Reload only — waybar config is a dotfile, not flake-managed; no
`home-manager switch` required. `systemctl --user reload waybar`
suffices.

## 2026-05-19 — SATAN: split self-edit into mech + mind lanes

`self-edit` mode is now two proposal-only lanes with different reading
scopes but identical governance (50k tokens / 20 calls / 180s,
`proposal_stage` only, `auto-apply none`):

- `self-edit-mech` — reads `~/.emacs.d/satan/` (the broker, harness,
  handlers, tests). Bug-and-invariant lane.
- `self-edit-mind` — reads `~/notes/satan/{prompts,system,tools}/`
  (model-facing text). Behaviour-shaping-text lane.

Proposals land in the same `~/notes/satan/proposals/` directory; each
denote file carries `:MODE: self-edit-{mech,mind}` so the lanes are
distinguishable for review.

- `satan/dl-satan-context.el` — replaced `dl-satan-self-edit-root`
  defcustom with two new lists (`dl-satan-self-edit-mech-roots`,
  `dl-satan-self-edit-mind-roots`); `dl-satan-context-self-edit` now
  reads roots from MODE-SPEC (`:source-roots` direct, or
  `:source-roots-var` indirect); source `:path` values are
  abbreviate-file-name'd (`~/notes/...` / `~/.emacs.d/...`) instead of
  long relative dotwalks; missing-root tolerated by
  `--list-files`.
- `satan/dl-satan-mode.el` — removed `self-edit`; registered
  `self-edit-mech` and `self-edit-mind` with `:source-roots-var`
  pointing at the respective defcustoms.
- `notes/satan/prompts/self-edit.txt` → `self-edit-mech.txt`
  (`git mv`); content rewritten to make the mech scope explicit.
- `notes/satan/prompts/self-edit-mind.txt` — new prompt for the mind
  lane; calls out prompt/tool/scaffold drift, mode-tool mismatch, and
  prose-vs-behaviour as the things worth proposing.
- `SATAN.md` — modes table (mech + mind rows), file map updates, new
  "Self-edit lanes (mech vs mind)" subsection, notes-tree prompts list.
- Tests: 50 → 52 (1 changed, 3 new: source-roots-var indirection,
  mech/mind registered distinctly, missing-root tolerance via the
  rewritten bundle test).

## 2026-05-19 — SATAN: scaffold rule against fake-JSON termination

Both real motd runs this week ended `reason=no_tool_calls` because the
model emitted a JSON-shaped string in its assistant message content that
looked like a `satan_final` payload but wasn't a tool call. The harness
correctly read no tool calls and coerced to a synthetic final, throwing
away the model's intended summary.

- `notes/satan/system/scaffold.txt` — Protocol section now spells out
  that termination is a TOOL CALL, names the failure mode
  (`reason=no_tool_calls`), and explicitly forbids JSON-looking strings
  in assistant content as a termination signal.

## 2026-05-19 — SATAN: tick mode family (30-min cadence, quiet hours)

Short, frequent, tightly-budgeted SATAN runs. Most ticks do nothing —
that's the design.

- `satan/dl-satan-tick.el` — new module:
  - `dl-satan-tick-pool` (defcustom, default `(("tick-pulse" . 1))`).
    Weighted alist; picker `dl-satan-tick-pick` samples by weight.
  - `dl-satan-tick-quiet-hours` (defcustom, default `(22 . 7)`).
    Wraparound supported; nil disables.
  - `dl-satan-tick-register SHORT-NAME &rest OVERRIDES` — helper
    builds a tick-* mode spec with sensible defaults (tools = motd's
    surface, 3000-token / 4-call / 30-second budget, output handler
    auto-applies `inbox_append` only). Prompt path defaults to
    `<prompts>/tick/SHORT-NAME.txt`.
  - `my/satan-tick` — public entry: quiet-check, pick, dispatch.
  - Default registration: `tick-pulse`.
- `satan/dl-satan-context.el` — `dl-satan-context-tick`: motd-shaped
  bundle plus current `:time` so the model can shape its pulse.
- `satan/dl-satan-output.el` — `dl-satan-output/tick`: auto-applies
  `inbox_append` only; `notify_send` is mid-run via the tool path.
- `satan/dl-satan.el` — require tick module.
- `satan/bin/satan-run-tick` — wrapper invoking `(my/satan-tick)`.
- `notes/satan/prompts/tick/pulse.txt` — `tick-pulse` prompt.
  Explicit "most ticks should do nothing" framing; lists good and bad
  reasons to act.
- `~/flakes/modules/home/satan.nix` — `satan-tick.{service,timer}`:
  `OnBootSec=5min`, `OnUnitActiveSec=30min`, `RandomizedDelaySec=5min`.
- `SATAN.md` — modes table, file map, notes-tree map, new "Tick mode
  family" subsection.
- Tests: 43 → 50 (7 tick: quiet-wraparound, quiet-disabled, pick
  deterministic single, pick zero-weight nil, weight distribution,
  default `tick-pulse` budgets, output handler routes).

Headroom against the new 400k daily ceiling: 48 ticks × 3000 = 144k.
Quiet hours suppress ~ 9 of those, leaving ~117k.

## 2026-05-19 — SATAN: daily 400k token ceiling (pre-spawn gate)

Cap total SATAN token spend per local day. Prevents a runaway tick
schedule or a malformed run loop from blowing past a sane budget.

- `satan/dl-satan-budget.el` — new module. `dl-satan-budget-daily-tokens`
  (defcustom, default 400000, nil disables). `dl-satan-budget-today-total`
  enumerates `runs/<run-id>/` whose run-id begins with today's
  `YYYYMMDDT` prefix and sums each run's max `usage.tokens_total` log
  payload from `transcript.jsonl`. Cheap — no manifest parsing, no
  cross-day fan-out.
- `satan/dl-satan-broker.el` — pre-spawn check in `dl-satan-broker-run`.
  If exceeded: mint run-id, write a slim audit bundle (manifest +
  budget-denied bundle + synthetic final with `reason=budget_daily_tokens`
  + empty actions + `status=budget-exceeded`), skip the child entirely.
  Returns the run-id so callers/systemd journals get a clean record.
  Spawn logic split into `dl-satan-broker--spawn` for the happy path.
- `satan/dl-satan-audit.el` — `status-terminal` predicate accepts
  `budget-exceeded` as a valid terminal status.
- `satan/dl-satan.el` — require `dl-satan-budget`.
- `SATAN.md` — file map, status counts, run-id section, new
  "Daily token ceiling" subsection.
- Tests: 38 → 43 (4 budget + 1 broker refusal). Verifier passes on
  the denied audit bundle.

Resets at local midnight (run-id prefix flips). Designed to be safe
for the upcoming tick mode family (30-min cadence × 24h = 48 runs;
3k token budget × 48 = 144k headroom under the 400k ceiling).

## 2026-05-19 — SATAN: motd single-writer (drop double-write race)

Two paths could write the motd surface: the `dl-satan-output/motd` handler
(unconditional, atomic, from `satan_final.summary`) and the
`org_update_owned_block` tool with `target=motd`. The handler runs last,
so when the model called the tool to write a good motd and then emitted
plain content as the closing turn, the harness coerced to
`final{reason=no_tool_calls}` with an empty/synthetic summary and the
handler stomped the good content.

Fix: one writer, one job. `satan_final.summary` is canonical motd content.

- `satan/dl-satan-mode.el` — motd `:tools` drops `org_update_owned_block`;
  `:capabilities` drops `write-motd` (no remaining gate uses it).
- `satan/dl-satan-tools-org.el` — `org_update_owned_block` target enum
  restricted to `"today"`; `:modes` restricted to `("morning")`;
  `target-path` / `target-capability` drop the `"motd"` arm.
- `satan/dl-satan-output.el` — motd handler auto-apply list is
  `("inbox_append")` only; docstring documents the single-writer invariant.
- `notes/satan/prompts/motd.txt` — rewritten: no `org_update_owned_block`
  in the tool list; explicit instruction that `satan_final.summary` is
  the motd content.
- `notes/satan/tools/org_update_owned_block.md` — target documented as
  `today` only; motd ownership note.
- `SATAN.md` — modes table (motd tools), tools table (capability column).
- Tests: 35 → 38 (3 new: motd target rejected via dispatcher, motd mode
  `:tools` excludes the tool, tool `:modes` registered for morning only).

## 2026-05-19 — SATAN: inbox surface + scaffold expansion + motd budget

Quiet append-only inbox at `~/notes/satan/inbox.org`. Lets SATAN drop
messages the user should see without interrupting them — preferred
over `notify_send` for almost everything.

- `satan/dl-satan-tools-inbox.el` — new `inbox_append(title, body,
  urgency)` tool. Auto-applied with capability `inbox-write`.
  Entries are top-level `*` headlines tagged `:unread:satan:` (plus
  optional `:low:` / `:urgent:`).
- `my/satan-inbox` opens the file; `my/satan-inbox-unread-count`
  returns the unread headline count (suitable for a waybar widget).
- Mode wiring: morning + motd both gain `inbox_append` in `:tools`
  and `inbox-write` in `:capabilities`; output handlers auto-apply.
- `~/notes/satan/system/scaffold.txt` rewritten (was: single
  termination instruction; now: identity, standing rules covering
  owned surfaces / inbox-over-notify / hippocampus, protocol).
- `~/notes/satan/prompts/{morning,motd}.txt` — `inbox_append` listed.
- `~/notes/satan/tools/inbox_append.md` — model-facing description.
- Motd budget bumped 5000 → 10000 tokens. Haiku exhausted 5k before
  reaching `satan_final` in the first real run.
- Fixed pre-existing `mode-name` variable-shadow bug in inbox /
  hippocampus / proposal-stage handlers: `mode-name` is a global
  defvar (buffer-local in every buffer), so a `let` binding gets
  overwritten by `with-temp-{buffer,file}` to "Fundamental". Renamed
  to `mode-str`.
- Tests: 31 → 35 (4 new inbox).

## 2026-05-19 — SATAN: tool names dot → underscore

OpenRouter routed every real-model run to Amazon Bedrock, which rejects
tool names containing dots (`tools.0.custom.name: String should match
pattern '^[a-zA-Z0-9_-]{1,128}$'`). SATAN had never completed a real
end-to-end run; the "smoke-tested live" claim in phase-2A was wishful
— successful runs were all the fake harness.

OpenAI's own validator enforces the same pattern. Switching to
`domain_verb` (underscore) makes the schema portable across every
OpenAI-compatible adapter.

- All tool names renamed: `org.read_context` → `org_read_context`,
  `org.update_owned_block` → `org_update_owned_block`,
  `proposal.stage` → `proposal_stage`, `notify.send` → `notify_send`,
  `hippocampus.write` → `hippocampus_write`,
  `satan.final` → `satan_final`.
- Updated: every tool-spec registration, mode `:tools` lists,
  `dl-satan-output` allowlists, harness `satan_final` interception,
  prompts (`morning.txt`, `motd.txt`, `self-edit.txt`), system
  scaffold (`scaffold.txt`), unit + python harness tests.
- Tool description files `git mv`d: `notes/satan/tools/<dotted>.md` →
  `<underscored>.md` (6 files).
- SATAN.md "Naming" rule updated: `domain_verb`, must match
  `^[a-zA-Z0-9_-]+$`.
- `~/flakes/modules/home/satan.nix` — morning timer moved 07:30 → 09:00
  (07:30 is before 1Password is unlocked → empty `OPENROUTER_API_KEY`
  resolution → guaranteed failed run).

Tests: 31/31 unit ert + 8/8 python unittest still green.

## 2026-05-19 — SATAN: memory → hippocampus rename

The memory subsystem is now called the hippocampus. SATAN owns it:
writes auto-apply, no candidate / confirmed ceremony. Mechanical rename
preparing the ground for `hippocampus.{write,recall,forget}`.

- `satan/dl-satan-tools-memory.el` → `satan/dl-satan-tools-hippocampus.el`
  (`git mv`). New defcustom `dl-satan-hippocampus-dir` =
  `~/notes/satan/hippocampus/`. Handler renamed
  `dl-satan-tool/hippocampus-write`; risk dropped `medium` → `low`.
  User command `my/satan-memory-candidates` → `my/satan-hippocampus`.
- `satan/dl-satan-mode.el` — morning tool list +
  capabilities rewired (`memory.add_candidate` → `hippocampus.write`,
  `memory-candidate` → `hippocampus-write`).
- `satan/dl-satan.el` — `(require 'dl-satan-tools-hippocampus)`.
- `~/notes/satan/tools/memory.add_candidate.md` →
  `tools/hippocampus.write.md` (rewritten — auto-apply framing, no
  "stage for review" language). `prompts/morning.txt` updated.
- Filename pattern `__satan_memory.org` → `__satan_hippocampus.org`;
  filetags `:satan:memory:candidate:` → `:satan:hippocampus:`.
- Tests renamed (`dl-satan-memory/*` → `dl-satan-hippocampus/*`).
- `SATAN.md` — "Memory governance" section rewritten as "Hippocampus
  governance"; file map, modes/tools tables, conventions updated.

No data migration: `~/notes/satan/memory/` was never populated. The
existing `~/notes/satan/hippocampus/` dir (already present in the spec
for jail bind-mount) is now the durable home for entries.

## 2026-05-19 — SATAN: mind/mechanism split (phase-2 E)

All model-facing behavioural text now lives under `~/notes/satan/`;
dotfiles hold mechanism only. Invariant: if changing the text could
change what the model decides to do, it belongs in the notes repo, not
this one.

- Moved `satan/prompts/{morning,motd,self-edit}.txt` →
  `~/notes/satan/prompts/`. New `~/notes/satan/system/scaffold.txt`
  (shared termination instruction). New `~/notes/satan/tools/<name>.md`
  per tool (incl. `satan.final`).
- `satan/dl-satan-mode.el` — `dl-satan-prompts-dir` default rebased on
  `dl-notes-root`.
- `satan/dl-satan-context.el` — new `dl-satan-context--read-required`
  (signals on missing), `dl-satan-system-scaffold-file` defcustom,
  `dl-satan-context--assemble-prompt` returns
  `scaffold + "\n\n" + mode`.
- `satan/dl-satan-tools.el` — new `dl-satan-tools-descriptions-dir`,
  description loader, `dl-satan-tool-json-schema` (assembles
  OpenAI-tools dict from elisp schema + notes description),
  `dl-satan-tool-final-schema` for the synthetic terminal tool.
- `satan/dl-satan-tools-{org,notify,memory}.el` — dropped
  `:description` from tool specs; no canonical source in dotfiles.
- `satan/dl-satan-broker.el` — extracted
  `dl-satan-broker--build-manifest`; manifest now carries `:tools` as
  full JSON Schemas (incl. `satan.final`); unknown tool in mode
  allowlist signals.
- `satan/harness/gptel_harness.py` — deleted `TOOL_SCHEMAS`,
  `SATAN_FINAL_SCHEMA`, and the hardcoded termination paragraph.
  `build_tools(manifest)` returns `manifest["tools"]` verbatim; missing
  tools array errors out before any model call.
- Failure mode: missing prompt/scaffold/tool-description signals at
  run start; no partial behaviour.
- Tests: +7 ert (`context/missing-prompt`, `context/missing-scaffold`,
  `tools/json-schema-from-notes`, `tools/json-schema-includes-enum`,
  `tools/missing-description-errors`,
  `tools/final-schema-uses-notes-description`,
  `broker/manifest-tools-shape`); python `build_tools` /
  `build_system_prompt` tests rewritten around the new contract.
  31/31 unit ert + 8/8 python unittest + 1/1 integration ert green.
- SATAN.md: new Ownership section + invariant, updated file map,
  closed open thread #6 (self-describing manifest done), added new
  open thread for `build_system_prompt` bundle-section headers (still
  inlined in python).

## 2026-05-19 — SATAN: self-edit mode (phase-2 D)

Adds a `self-edit` mode that feeds the entire SATAN source tree to the
LLM and accepts only `proposal.stage` calls.  Nothing auto-applies;
proposals land as denote files under `~/notes/satan/proposals/` for
manual review.  Intended for: footgun spotting, missing-test
detection, doc/code drift, simplification suggestions on SATAN's own
codebase.

- `satan/dl-satan-context.el` —
  `dl-satan-context-self-edit` builds a bundle with `:sources` (list
  of `(:path REL :content STR)` for every file under
  `dl-satan-self-edit-root` matching
  `dl-satan-self-edit-source-regexp`, minus
  `dl-satan-self-edit-exclude-regexp`).  All three are defcustoms.
- `satan/dl-satan-output.el` — `dl-satan-output/self-edit` partitions
  `proposal.stage` as the only auto-apply target; everything else gets
  classified as staged.
- `satan/dl-satan-mode.el` — registers the `self-edit` mode.  Budget:
  50k tokens, 20 tool calls, 180s wall.  `:auto-apply 'none`.
- `satan/prompts/self-edit.txt` — instructions for the LLM:
  rationale + affected files + patch sketch + test plan per proposal.
  Don't propose changes outside the SATAN tree.
- `satan/harness/gptel_harness.py` — `build_system_prompt` now renders
  a `:sources` array as fenced code blocks under `## <path>` headings.
- Tests: 2 new ert (context-bundles-sources, output-only-applies)
  + 1 new python unittest (system-prompt-renders-sources).
  24/24 unit ert + 8/8 python unittest + 1/1 integration ert green.

## 2026-05-19 — SATAN: memory.add_candidate tool (phase-2 C)

Adds a tool for the agent to stage a candidate memory — a fact,
preference, or pattern future runs would benefit from remembering —
as a denote-named org file under `~/notes/satan/memory/candidates/`.
Review is `find-file` / dired for v1 (`M-x my/satan-memory-candidates`).
Risk `medium`: durable artifact, capability-gated.

- `satan/dl-satan-tools-memory.el` — handler +
  registration.  Args: `title` (required), `body` (required).
  Refuses unless `tool-ctx :capabilities` includes
  `memory-candidate`.  Filename pattern
  `<denote-id>--<slug>__satan_memory.org` with filetags
  `:satan:memory:candidate:`.  `my/satan-memory-candidates` opens the
  candidates dir in dired.
- `satan/dl-satan.el` — requires the new file.
- `satan/dl-satan-mode.el` — `morning` allowlist adds
  `memory.add_candidate`; new `memory-candidate` capability.  `motd`
  unchanged (too short to surface durable insights).
- `satan/harness/gptel_harness.py` — JSON Schema for
  `memory.add_candidate`.
- `satan/prompts/morning.txt` — describes the tool.
- Tests: 3 new ert (`handler-writes-denote-file`, `capability-required`,
  `schema-required`) — 22/22 unit ert green.  7/7 python unittest green.

## 2026-05-19 — SATAN: notify.send tool (phase-2 B)

Adds a `notify.send` tool so the agent can post a transient desktop
notification via D-Bus.  Thin wrapper around `notifications-notify`
(Emacs built-in).  Risk `low`; flows through the same audit transcript
as every other tool call.

- `satan/dl-satan-tools-notify.el` — handler + registration.  Args:
  `title` (required), `body` (required), `urgency`
  (`low|normal|critical`, optional), `timeout` (ms, optional, default
  8000).  D-Bus failure returns `error` instead of propagating.
- `satan/dl-satan.el` — requires the new file.
- `satan/dl-satan-mode.el` — `morning` and `motd` allowlist
  `notify.send`; new `notify` capability tag.
- `satan/harness/gptel_harness.py` — JSON Schema for `notify.send`
  added to `TOOL_SCHEMAS` so the LLM sees it whenever the mode
  manifest allows it.
- `satan/prompts/{morning,motd}.txt` — note the new tool with a
  reminder to use it sparingly.
- Tests: 4 new ert (`dispatch-ok` via stubbed `notifications-notify`,
  schema missing-title, urgency enum, handler-error path) — 19/19
  unit ert green.  6/6 python harness unittest green.

## 2026-05-19 — SATAN: real LLM harness (phase-2 A)

Replaces the phase-1 fake harness with `satan-gptel-harness`, an
OpenAI-compatible chat-completions driver (OpenRouter v1 by default).
The harness is provider-agnostic via a `Provider` abstract base — keys
and model id come from env (`SATAN_PROVIDER`, `SATAN_MODEL`,
`<PROVIDER>_API_KEY`).  Future providers (Anthropic direct, OpenAI,
DeepSeek, Pi/Zerostack) plug in by implementing `Provider.complete`.

- `satan/harness/gptel_harness.py` — main harness.  Termination signal
  is a `satan.final(summary, actions[])` tool call; adapter intercepts
  it and emits the broker's `final` record.  Plain-content responses
  with no tool calls are coerced into a final with
  `reason=no_tool_calls`.
- Budget: harness tallies `prompt_tokens + completion_tokens` reported
  by the provider; emits per-turn `log` events with cumulative usage;
  graceful self-termination via synthetic `final` with
  `reason=budget_tokens` once a turn crosses
  `SATAN_BUDGET_TOKENS`.  Broker's existing `:budget-tool-calls` +
  `:timeout-seconds` remain the backstops.
- `satan/harness/test_gptel_harness.py` — five unit tests covering the
  termination paths, budget exhaustion, and tool-call filtering.
  Stdlib `unittest`; no network.
- `flake.nix` — `satanGptelHarness` (`writePython3Bin` with
  `python3Packages.openai`), `satanGptelJailOptions` (forwards
  `SATAN_PROVIDER`/`SATAN_MODEL`/`SATAN_BUDGET_TOKENS` + four provider
  key vars), `satan-jailed-gptel-harness` (profile `specDev` for
  network).
- `dl-satan-broker.el` — `dl-satan-broker-provider-key-vars` map;
  resolves `op://` refs via `my/op-read-env` at spawn (condition-case
  so a locked 1Password doesn't crash the run); forwards
  `SATAN_PROVIDER`/`SATAN_MODEL`/`SATAN_BUDGET_TOKENS` + selected key
  into the child env.
- `dl-satan-mode.el` — `morning` and `motd` now drive
  `jailed-satan-gptel-harness` against `anthropic/claude-haiku-4.5` via
  openrouter.  Budgets: morning 20k tokens / 8 tool calls / 90s wall;
  motd 5k tokens / 4 tool calls / 45s wall.
- `satan-jailed-fake-harness` retained as the test fixture for the
  existing integration ert.
- Smoke: 15/15 unit ert + 1/1 integration ert + 5/5 python unittest
  green.  Standalone protocol smoke against real openrouter confirms
  `ready` emission, network reach, error path clean.

## 2026-05-19 — SATAN: broker + JSONL protocol + jailed fake harness

Phase-1 of the SATAN local agent runtime (see `SATAN.local.md`).  Emacs
is the broker and capability authority; a bubblewrap-jailed child
process is the harness; they exchange newline-delimited JSON over
stdin/stdout; only the broker mutates durable state.

- `satan/` — new module bucket.
  - `dl-satan-jsonl.el` — line-buffered filter + writer.  `json-serialize`
    rejects bare lists, so `dl-satan-jsonl-prepare` walks payloads and
    coerces non-plist lists to vectors.
  - `dl-satan-block.el` — find/replace owned org blocks of the form
    `#+begin_satan :block NAME :owner SATAN :updated [...]` /
    `#+end_satan`.  Refuses multi-match; creates-at-end on none-match.
  - `dl-satan-audit.el` — append-only writer for
    `runs/<run-id>/{manifest,bundle,transcript,final,actions,status}`
    plus a six-predicate verifier that proves the
    `SATAN.local.md:601-616` auditability invariant.
  - `dl-satan-tools.el` + `dl-satan-tools-org.el` — registry, allowlist
    + schema check, three handlers (`org.read_context`,
    `org.update_owned_block`, `proposal.stage`).
  - `dl-satan-mode.el` — `morning` and `motd` mode-specs.
  - `dl-satan-context.el`, `dl-satan-output.el` — context assembler +
    handlers.
  - `dl-satan-broker.el` — `make-process` driver: line-buffered filter,
    timeout timer, tool-call dispatch, sentinel runs output handler.
  - `dl-satan.el` — `my/satan-run MODE` interactive entry.
  - `satan/bin/satan-run` — shell wrapper for systemd/cron via
    `emacsclient --eval`.
  - `satan/test/*.el` — 15 unit tests + 1 end-to-end integration test
    against the real jailed binary (skips unless `SATAN_TEST_JAIL_BIN`
    is set).
- `flake.nix` — adds `satan-jailed-fake-harness` derivation built via
  `pkgs.writers.writePython3Bin`, profile = `offline`.  Jail mounts
  `~/notes` read-only at `/satan/notes` and
  `~/notes/satan/hippocampus` read-write at `/satan/hippocampus`.
  Forwards `SATAN_RUN_ID`, sets `SATAN_RUN_DIR=/satan/run` inside the
  jail.  Exposes `jailPkgs` as flake `packages` so the binary builds
  via `nix build .#satan-jailed-fake-harness`.
- `core/dl-path.el` — adds `satan` to `my/lisp-dirs` and
  `trusted-content`.
- `init.el` — `(require 'dl-satan)`.
- `~/notes/satan/{hippocampus,proposals,runs}/` — on-disk layout.
- `~/flakes/modules/home/satan.nix` — systemd user services and timers
  for `satan-morning` (07:30 daily) and `satan-motd` (07:00 daily).
  **Not** imported by `Sleipnir.nix` — staged for review.
- `~/flakes/modules/home/emacs.nix` — adds `satan` to `configDirs` so
  the Nix wrapper's use-package parser scans the bucket.

Phase-1 non-goals: real model harness adapter (fake only), memory
candidate review UI, ROM management beyond a static prompt file, the
`self_edit` mode, network egress filtering, multi-step tool-call
reasoning loops, D-Bus notifications.

## 2026-05-18 — secrets: 1Password resolution + zsh env sourcing

API keys move out of plaintext on disk. `~/.config/zsh/env.zsh` now
holds `op://vault/item/field` refs instead of secret strings; resolution
happens on demand.

- `lisp/dl-secret.el` — three concerns merged into one module:
  - `my/op-read` / `my/op-read-env` — resolve refs via 1Password CLI,
    session-cached; `my/op-forget` clears the cache.
  - `my/auth-source-secret` — generic wrapper around
    `auth-source-search` (lambda-secret + utf-8 handling).
  - Auto-sources `~/.config/zsh/env.zsh` at load (only sets vars that
    are currently unset, so terminal-launched Emacs keeps resolved
    values).
- `apps/dl-gptel.el` — OpenRouter backend switched to
  `(lambda () (my/op-read-env "OPENROUTER_API_KEY"))`. Lambda form
  re-resolves per request; no stale-pin risk.
- `AGENTS.md` — new "Secrets and env vars" section documents the
  resolution path and the dl-secret API.

Sway-launched Emacs (which never runs zshrc) now sees the same API
keys as a terminal session, without any keys touching disk.

## 2026-05-18 — crash diagnostics: stderr wrapper + SIGUSR2 backtrace

Gui locked + all frames vanished while editing an org buffer; no
coredump, no journal entry. Fuzzel-spawned pgtk emacs has stdout/stderr
pointed at `/dev/null`, so wayland/compositor disconnects and late
fatal messages were unrecoverable.

- `~/.local/bin/emacs-logged` — launcher wrapper, `exec emacs "$@"`
  with stderr appended to `~/.local/state/emacs/stderr.log`; previous
  session rotated to `stderr.log.1` on each start. Header line records
  timestamp + pid + args.
- `~/.local/share/applications/emacs.desktop` — local override (XDG
  precedence over Nix) so fuzzel routes through the wrapper.
- `init.el` — `(setq debug-on-event 'sigusr2)`; `pkill -USR2 emacs`
  during a freeze drops into the debugger with a backtrace.

Files live outside the repo (state + XDG launcher dirs); noted here so
future-me knows where to look.

## 2026-05-18 — org faces scale with text-scale; new-frame bg syncs to theme

`core/dl-faces.el` — org heading/code faces moved to float `:height`
multipliers and table-driven via new `my/org-face-styles` (levels 1-8 +
title + block/code/verbatim). C-mousewheel / `text-scale-adjust` now
scales them since float heights chain through `default`. `core/dl-theme.el`
— `my/sync-frame-colors-to-theme` on `enable-theme-functions` copies
current `default` bg/fg into `default-frame-alist`, so frames opened
after the bootstrap no longer inherit the `#000000` anti-flash colour
from `dl-interface.el`.

## 2026-05-17 — tier-2 lambda-emacs cherry-picks

Seven small commands lifted from lambda-emacs, cleaned up, slotted into
existing family maps:

- `my/toggle-window-dedicated` (`C-c w P`) — pin selected window to its
  buffer. Lambda's version had a `(let (window …))` typo that left
  `window` nil; rewritten against `selected-window`.
- `my/window-exchange-buffer` (`C-c w x`) — swap two windows' buffers
  via `ace-window`, focus stays put. Uses the already-installed
  `ace-window` (`editing/dl-motion.el`).
- `my/delete-current-buffer-file` (`C-c f K`) — delete file on disk +
  kill buffer (confirm). Lambda fell back to `ido-kill-buffer`;
  replaced with `kill-current-buffer` since ido isn't in play.
- `my/move-file` (`C-c f M`) — `write-file` then delete the old.
- `my/tmp-buffer` (`C-c b t`) — timestamped throwaway in the *current*
  major mode (lambda's version silently dropped to fundamental-mode
  despite the docstring).
- `my/unfill-paragraph` (`M-Q`) — Stefan Monnier's inverse of
  `fill-paragraph`, in `core/dl-prose.el`.
- `my/forward-or-backward-sexp` (`C-c j p`) — vim `%` style match-paren
  jump, in `editing/dl-motion.el`.

New file `lisp/dl-file-ops.el` for the two file commands (loaded from
`init.el`). Window / buffer / motion / prose commands appended to
existing module files. Bindings centralised in `core/dl-keymap.el`
under `my/bind`; KEYS.md updated for `f`, `b`, `w`, `j` sections.

Skipped from the candidate list: `lem-jump-in-buffer` (redundant —
`C-c o h` and `C-c s o` already cover it cleanly).

## 2026-05-17 — modernize last `defadvice`

`core/dl-core.el` — the pre-2.0 `defadvice` form on `find-file`
(`make-directory-maybe`) rewritten as a named defun
`dl-core--make-parent-directory-maybe` plus `(advice-add 'find-file
:before ...)`.  Behaviour-preserving; the latent
`(file-exists-p nil)` edge case (when `file-name-directory` returns
nil) is preserved as in the original.

## 2026-05-17 — naming policy + migration

Naming convention written into `AGENTS.md` (between "The four traps"
and "Common debugging commands"):

- `dl-MODULE` for file/`provide` symbols.
- `dl-MODULE-name` for module's public internals; `dl-MODULE--name` for
  private (defcustoms always module-owned).
- `my/name` for personal commands and their helper/variable families
  (`my/` propagates through the helper cluster even when the helpers
  live in a `dl-MODULE` file — role beats file).
- Grandfathered: `my-X-map` keymaps (`my/bind` + meow leader-mirror
  discover by this name) and `meow-setup` (meow docs require that
  exact function name).

Migration in two single-file passes:

- **`apps/dl-shpool.el`** — `my-shpool` defgroup and 5 defcustoms
  (`-command`, `-known-sessions`, `-restore-sessions`, `-auto-restore`,
  `-debug`) renamed to `dl-shpool-*`, plus all ~55 internal references
  (`replace_all`).  Orphan customize entry
  `(my-shpool-known-sessions ...)` removed from `custom-vars.el`.  A
  `(dl-shpool-known-sessions ...)` entry was already present under the
  target name; its value (`".emacs.d" "hris" "team" "claude"`) becomes
  the canonical saved list.  Two names from the old entry (`"flakes"`,
  `"example"`) dropped — re-add via M-x customize if you still use
  them; the cache auto-grows otherwise.
- **`lang/dl-nix.el`** — 5 `dl-nix/X` slash-prefix names renamed to
  `dl-nix-X` (`-flake`, `-nixos-host`, `-home-user`, `-nixd-config`,
  `-set-workspace-config`), plus internal references.  No customize
  state to migrate.

After this pass the codebase is policy-compliant.  `rg "my-shpool|dl-nix/"`
returns empty.

## 2026-05-17 — polish: named hooks, fold consolidation, shpool/interface tidy

Low-leverage polish from the review:

- **`apps/dl-magit.el`** — the anonymous lambda on `git-commit-mode-hook`
  (`(lambda () (ws-butler-mode -1))`) extracted to
  `my/git-commit-disable-ws-butler`.  Named hooks survive
  `.emacs.desktop` restore more cleanly and are easier to remove.
- **`editing/dl-fold.el`** — 36 bare `add-hook` calls (5 for
  `outline-minor-mode`, 15 for `hs-minor-mode`, 16 for
  `treesit-fold-mode`) consolidated into three `use-package` blocks
  with `:hook` lists (`outline`, `hideshow` — both built-in with
  `:ensure nil` — and `treesit-fold`).  ~50 lines down to ~25.
  Language-group structure preserved as inline comments inside the
  `:hook` argument.  The four commented-out kotlin/swift/elixir/zig
  hooks dropped; a one-line comment notes how to re-add.
- **`apps/dl-shpool.el`** — `my/shpool-attach-args` renamed to
  `my/shpool--attach-args` (`--` private prefix matches the rest of
  the file's namespace; only caller is `my/shpool--open`).
- **`core/dl-interface.el`** — `(mapc (lambda (hook) (add-hook ...)) ...)`
  over a `let`-bound hook list rewritten as a `dolist`.  Same effect,
  half the line count, no closure overhead.

The audit's claim about redundant `customize-save-variable` calls in
`dl-shpool.el` (lines 298–303 and 317–319) was wrong — re-reading both
functions, `my/shpool-add-current-to-restore` adds to *both*
`restore-sessions` and `known-sessions` so saving both is correct, and
`my/shpool-remove-from-restore` only touches `restore-sessions` and
only saves `restore-sessions`.  No change.

The note about `(use-package hydra :demand t)` in `core/dl-keybind.el`
being the only `:demand` in the file is informational only — it has to
be eager because downstream files (`dl-keymap.el`) reference the
`hydra-…/body' entry points generated by `defhydra`.

## 2026-05-17 — face scatter cleanup: all attrs in dl-faces.el

The two remaining face strays from the review's §7 ("face customization
belongs in dl-faces") moved.  Verified with rg: no `set-face-attribute`
/ `face-spec-set` / `custom-set-faces` / `:custom-face` outside
`core/dl-faces.el` (and the auto-generated `custom-vars.el`).

- `core/dl-meow.el` — the `dl-meow--apply-indicator-faces` defun, its
  call from meow's `:config`, and the `enable-theme-functions` add-hook
  all gone.  Replaced in `core/dl-faces.el` by `my/apply-meow-indicator-faces`
  (renamed for `my/apply-X-faces` consistency) under a
  `(with-eval-after-load 'meow ...)` block that does the call + hook
  wiring once meow loads.  `defface dl-meow-indicator-inactive` and
  `dl-meow-indicator` stay in dl-meow — those are package scaffolding
  (face *definition* + modeline helper), not customization.
- `editing/dl-fold.el` — the `set-face-attribute 'treesit-fold-replacement-face`
  block from treesit-fold's `:config` moved to a
  `(with-eval-after-load 'treesit-fold ...)` block in dl-faces.

## 2026-05-17 — visual layer: dl-font → dl-faces, dl-interface slimmed

Two questions the audit raised about `core/dl-font.el` and `core/dl-interface.el`:
**(a)** the file named "fonts" was actually the universal face-customization
hub (font roles + every `set-face-attribute` in the codebase); **(b)**
dl-interface had become a kitchen sink (startup chrome + global modes
+ window helpers + popup tamers + scroll-key overrides, all in one
file).  Resolved both.

**`dl-font.el` → `dl-faces.el`** — `git mv` rename; `provide`/`require`
and file header updated.  `init.el:12` follows.  The file's content is
unchanged structurally, just better-named.

**`my/apply-fonts` now fires at startup and on theme rotation.** It was
defined but never called at the top level — fonts were coming from
whatever the theme set, and manual `M-x my/apply-fonts` was the only
path to your role/height/weight customizations.  Added a top-level
`(my/apply-fonts)` plus `(add-hook 'enable-theme-functions
#'my/apply-fonts)`.  Function signature now `(&rest _)` so it slots
directly onto the hook (same shape as `dl-meow--apply-indicator-faces`,
the only other face-applier with a theme-reload hook).

**`dl-interface.el` split (approach A from the design pass)**:

- `split-and-follow-horizontally` / `split-and-follow-vertically`,
  `(use-package transpose-frame ...)`, and `(winner-mode 1)` moved to
  `lisp/dl-window.el` where the rest of the window helpers live.  The
  stale comment at the top of dl-window pointing back to dl-interface
  is updated.
- `(use-package shackle ...)` and `(use-package popper ...)` extracted
  to new `core/dl-popups.el`.  Sibling of dl-interface; required in
  init.el right after it.
- `(global-set-key (kbd "C-v") ...)` / `M-v` (the View-half-page
  overrides) and the `(require 'view)` they need moved to
  `core/dl-keybind.el` next to the other ergonomic chord bindings.

After the split dl-interface owns just chrome + frame + global display
modes + per-mode hooks + the remaining package wrappers
(`spacious-padding`, `diminish`, `nerd-icons` + `nerd-icons-completion`,
`beacon`, `breadcrumb`) — coherent.

**Incidentals along the way**:

- Typo `(use-short-anwswers t)` in dl-interface's `:custom` removed
  (set a phantom variable; the correctly-spelled `use-short-answers`
  is already in `dl-core.el`).
- Duplicate top-level `(global-prettify-symbols-mode t)` removed; the
  `:custom` line earlier in the same use-package block already enables
  it.

**Touched:** `init.el`, `core/dl-faces.el` (renamed from `dl-font.el`),
`core/dl-popups.el` (new), `core/dl-interface.el`, `core/dl-keybind.el`,
`lisp/dl-window.el`.  `home-manager switch` required (new file).

## 2026-05-17 — quality review: trivial fixes + lazy-loading + eglot consolidation

Sweep audit (`REVIEW.md` for the full report).

**Trivial fixes** — `init.el` duplicate `(require 'dl-term)` removed; 4 dead commented `set-face-attribute` / `set-frame-font` lines deleted. Save-time bug closed in `editing/dl-persist.el`: `my/eglot-format-buffer-if-connected` was wired both buffer-local (via `my/eglot-on-save-setup`) and globally on `before-save-hook`, firing twice in eglot buffers — global add removed. Orphan `<f9>` binding next to `toggle-maximize-buffer` in `lisp/dl-buffer-management.el` removed; same binding already lives in `core/dl-keybind.el`. Duplicate `with-eval-after-load 'org` face block in `core/dl-font.el` removed — `my/apply-fonts` already calls `my/apply-org-faces`. `completion/dl-vertico.el` file header said `dl-orderless.el`; fixed. Redundant `(use-package savehist :init (savehist-mode))` in `dl-vertico.el` dropped — `dl-completion.el` enables savehist earlier in init order.

**Lazy-loading** — `org/dl-org.el`: `use-package org` now defers via `:mode "\\.org\\'"`; the bare top-level `(setq ...)` block (which duplicated `org-startup-indented` and `org-hide-emphasis-markers` already in `:custom`) folded into `:custom`. `org-bullets-bullet-list` moved into `org-bullets`' own `:custom` and the package now defers via `:hook (org-mode . org-bullets-mode)`. The anonymous margin/hl-line lambda in `org-mode-hook` extracted to `my/org-setup-margins` (named hooks survive `.emacs.desktop` restore more cleanly).

`apps/dl-eaf.el`: `:demand t` removed from all four packages. `eaf` itself now declares `:commands (eaf-open eaf-open-browser eaf-open-pdf-viewer eaf-open-image-viewer)`; the apps keep `:after eaf` so load order is preserved when an entry command pulls eaf in. Largest single startup-time win in this pass.

**Eglot consolidation** — `my/eglot-connected-p`, `my/eglot-format-buffer-if-connected`, `my/eglot-organize-imports-if-connected`, and `my/eglot-on-save-setup` moved from `editing/dl-persist.el` to `dev/dl-eglot.el`. `editing/dl-persist.el` is now strictly *session* persistence (file revert + autosave + undo-fu). The organize-imports hook was previously global on `before-save-hook` (firing on every save, no-op outside eglot buffers); it now installs buffer-local via `my/eglot-on-save-setup`, mirroring the format-buffer pattern. `lang/dl-nix.el`: the eager `(use-package eglot :config (add-to-list 'eglot-server-programs ...))` (which pulled eglot at startup) replaced with `with-eval-after-load 'eglot`; nixd registration now waits until eglot actually loads.

**Use-package dedup** — Four duplicate `use-package` forms removed:

- `(use-package dired ...)` in `apps/dl-dirvish.el` deleted; identical settings already in `apps/dl-dired.el`.
- `(use-package diredfl ...)` in `editing/dl-project.el` deleted; canonical home is `apps/dl-dired.el`.
- `(use-package markdown-mode ...)` in `lang/dl-lang-common.el` deleted; its `visual-line-mode` hook lifted into the existing form in `lang/dl-markdown.el`.
- `(use-package nerd-icons :defer t)` in `apps/dl-dired.el` deleted; canonical home is `core/dl-interface.el` (which also configures `nerd-icons-completion`).

**Overlapping `(use-package emacs ...)` blocks** — The block in `completion/dl-vertico.el` was a pure duplicate: `context-menu-mode` was already enabled in `core/dl-interface.el:111`, and `enable-recursive-minibuffers` / `read-extended-command-predicate` were already in `completion/dl-completion.el`. The one genuinely cross-cutting setting, `minibuffer-prompt-properties` (locks cursor out of the prompt — applies beyond vertico), lifted into `dl-completion.el`. Block removed.

`editing/dl-project.el`'s `(use-package emacs ...)` block had nothing to do with projects: `major-mode-remap-alist` (treesitter remap) moved to `dev/dl-treesit.el` next to `treesit-auto`; the remaining `:hook ((prog-mode . electric-pair-mode))` collapsed to a top-level `add-hook`. Block removed.

**Buglet** — `completion/dl-completion.el` had `(keymap-set minibuffer-mode-map "TAB" 'minibuffer-complete)` inside its `:custom` block, where the form was treated as `(VAR=keymap-set VALUE=minibuffer-mode-map ...)` and never actually bound TAB. Moved into a proper `:bind (:map minibuffer-mode-map ...)` clause.

After this pass, the seven remaining `(use-package emacs ...)` blocks each own a coherent domain: `dl-core` (defaults), `dl-backup` (backup), `dl-interface` (UI), `dl-persist` (auto-revert + history), `dl-completion` (minibuffer + completion), `dl-elisp` (elisp-mode), and the new minimal one in `dl-eaf` / N-A. No emacs-block lives in `dl-project` or `dl-vertico` anymore.

**Touched:** `init.el`, `core/dl-font.el`, `completion/dl-completion.el`, `completion/dl-vertico.el`, `editing/dl-persist.el`, `editing/dl-project.el`, `lisp/dl-buffer-management.el`, `lang/dl-markdown.el`, `lang/dl-lang-common.el`, `lang/dl-nix.el`, `org/dl-org.el`, `apps/dl-eaf.el`, `apps/dl-dired.el`, `apps/dl-dirvish.el`, `dev/dl-eglot.el`, `dev/dl-treesit.el`, `REVIEW.md` (new).

## 2026-05-17 — lambda-emacs lifts: meow polish, user-buffer cycling, window helpers

Three groups picked from `./lambda-emacs/` and `./meow.local.el`.

- **Meow `:custom` block** (`core/dl-meow.el`).
  Added `meow-use-cursor-position-hack`, `meow-use-clipboard`,
  `meow-goto-line-function = consult-goto-line`,
  `meow--kbd-delete-char = <deletechar>`, `<…>` registered as the
  `a` thing.  Terminal-disable hook renamed
  `my-disable-meow-in-terminal` → `dl-meow--disable-in-terminals`
  to match file convention; vterm `meow-mode-state-list` entry
  dropped (the hook does `(meow-mode -1)` which supersedes the
  state-list lookup and removes the indicator/cursor too).
  Lambda's magit cooperation block (put magit in normal state, unset
  `j`/`k`) was tried and reverted: forcing meow normal state in magit
  made meow's minor-mode keymap shadow magit's single-letter bindings
  (`s`, `c`, `l`, …); the `j`/`k` unset only frees those two.
  Correct shape if revisited is the vterm/ghostel pattern (disable
  meow entirely in `magit-mode` buffers).
- **User-buffer cycling** (`lisp/dl-buffer-management.el`).
  `my/user-buffer-p` filters `*…*` and dired buffers;
  `my/next-user-buffer` / `my/previous-user-buffer` skip past them.
  Bound at `C-c b n` / `C-c b p` (replacing raw next/previous-buffer)
  and mirrored to Meow leader `SPC [` / `SPC ]` for flick cycling.
  File header fixed (`.le` → `.el`); added `(require
  'dl-buffer-management)` to `init.el` (was unloaded — F9
  `toggle-maximize-buffer` was dead code).
- **Window helpers** (`lisp/dl-window.el` — new).
  - `C-c w s` / `w v` now `split-and-follow-{horizontally,vertically}`
    (existing defuns in `core/dl-interface.el`, previously unbound) —
    split and move point into the new pane.
  - `C-c w S` / `w V` keep the raw `split-window-{below,right}` for
    when you want focus to stay put.
  - `C-c w f` → `transpose-frame` (swap horizontal ⇄ vertical splits
    across the whole frame).  The transpose-frame package was already
    declared in `core/dl-interface.el` and bound at `C-x 7`; `w f`
    is the leader-friendly alias.  Strictly more general than the
    2-window-only flip I almost wrote — caught before merging.
  - `C-c w c` / `w C` → `my/rotate-windows[-backward]` (cycle buffers
    around non-dedicated windows; distinct from transpose, which
    rotates the layout).  `w r` is taken by the resize hydra, so
    rotate landed on `c` (cycle).

Deferred avenue documented in `KEYS.md`: nil-out
`meow-keypad-{meta,ctrl-meta,literal}-prefix` + `-start-keys` to
release `SPC g` / `SPC m` (currently aliased to `SPC G` / `SPC M`).
Not adopted — would lose Meow's `SPC c …` / `SPC x …` keypad
dispatchers and the literal-input escape.

**Touched:** `core/dl-meow.el`, `core/dl-keymap.el`,
`lisp/dl-buffer-management.el`, `lisp/dl-window.el` (new), `init.el`,
`KEYS.md`.

## 2026-05-17 — window-resize hydra (first defhydra)

`hydra-window-resize` lands at `C-c w r`.  Sticky modal: arrow keys
grow/shrink the selected window in the matching direction (`<right>`
wider, `<up>` taller, etc.), `=` balances, `q` exits.

Hydra was previously deferred (`use-package hydra :commands defhydra`)
with no actual hydras defined; promoted to `:demand t` so `defhydra`
is in scope when `dl-keymap.el` references the `…/body` entry point.
`declare-function` placeholder added in `dl-keymap.el` to silence the
byte-compiler "not known to be defined" warning during cold compile.

**Touched:** `core/dl-keybind.el`, `core/dl-keymap.el`, `KEYS.md`.

## 2026-05-17 — Policy lint + ready-player squatter

The deferred-sweep audit (entry below) cleared all `C-c <letter>`
Policy violations in tracked `.el` files, but uncovered one foreign-
package squatter the previous audits had missed.  A small lint keeps
it from coming back.

- **`ready-player` was silently owning `C-c m`.**  `ready-player-mode`
  installs a "Ready Player" keymap globally on activation, clobbering
  `my-term-map` after `dl-keymap.el` had bound it.  No `my/bind`
  warning fired because the install bypasses `my/bind`.  Fix:
  `(setq ready-player-set-global-bindings nil)` via `:custom` in
  `apps/dl-dired.el`.  Term family restored at `C-c m`.
- **`core/dl-policy-lint.el` — new.**  Walks `mode-specific-map` and
  reports any single-letter binding whose value isn't a `my-*-map`
  family map or a Policy-reserved singleton (`C-c a/c/l`).
  - `M-x my-policy-lint` pops `*Policy Lint*` with offending key +
    binding + reason (`foreign-map` / `foreign-command`).
  - Silent startup check via `emacs-startup-hook`: logs a single
    `*Messages*` line iff violations exist; never opens a buffer.
  - Catches what `my/bind`'s collision warning can't — foreign
    packages binding `C-c <letter>` from their own `:config`.

Required: a one-line `(require 'dl-policy-lint)` after
`(require 'dl-keymap)` in `init.el`.  Family allowlist
(`my-policy-lint-family-maps`) needs updating when a new tier-1
prefix lands.

**Touched:** `core/dl-policy-lint.el` (new), `core/dl-keymap.el`
(unchanged for lint), `apps/dl-dired.el`, `init.el`, `KEYS.md`.

## 2026-05-17 — keymap policy deferred sweep

Cleared the four remaining Policy stragglers from the previous audit.
After this pass, no `C-c <letter>` global bindings live outside
`core/dl-keymap.el`.

- **`C-c s q` / `s Q` — visual-regexp.**  `vr/query-replace` and
  `vr/replace` lifted out of `editing/dl-search.el` into the central
  search map.  Lowercase = interactive (common), uppercase = one-shot
  replace (less common).  Isearch chords `C-r` / `C-s` stay in
  `dl-search.el` (they shadow Emacs globals, not personal keys).
- **`C-c n r …` — roam compartment.**  Six org-roam bindings squatting
  on tier-1 `C-c r` moved into a `my-roam-map` sub-prefix under notes.
  Reflects Phase-1 reality: roam stays wired (db autosync, capture
  templates) but isn't the primary navigator.  If/when promoted back
  to a daily tool, lift out of the compartment.
- **`apps/dl-slack.el` global bindings deleted.**  Module currently
  uninstalled (`init.el:76`); the `C-c S …` family would have squatted
  on tier-1 `S` the moment slack returned.  Mode-local maps
  (`slack-mode-map` etc.) retained — those are package-owned.  Header
  comment in the file flags the next-time refactor requirement.
- **Doc rot trims.**  `(global-set-key (kbd "C-c h") …)` comment in
  `lisp/dl-insert-elisp-header.el` removed (`C-c h` is Policy-banned
  as the modal gateway).  Dead commented combobulate `use-package`
  block in `editing/dl-multi-edit.el` deleted (`combobulate-key-prefix
  "C-c o"` reference was stale; `C-c o` is now the Org map).

**Touched:** `core/dl-keymap.el`, `editing/dl-search.el`,
`org/dl-org-roam.el`, `apps/dl-slack.el`,
`lisp/dl-insert-elisp-header.el`, `editing/dl-multi-edit.el`,
`KEYS.md`.

## 2026-05-17 — keymap audit fixes

Audit pass against the freshly-Policy-ied keymap surfaced four real
bugs and one Policy violation; all addressed.

**Critical: `C-c s` was unreachable.** `dl-search.el` called
`(rg-enable-default-bindings)`, which does
`(global-set-key (kbd "C-c s") rg-global-map)` — silently replacing
`my-search-map` (whose 11 scope-ladder bindings I'd just centralised)
with rg.el's transient menu. Verified against the live session:
`C-c s` resolved to `rg-menu`; `C-c s s`/`s p` etc. were unbound.
Fix: drop `rg-enable-default-bindings`; expose `rg-menu` at `C-c s g`
in the central map. `consult-ripgrep` remains the common path at
`s r` / `s R` / `M-s r`.

**`C-c t B` double-bound.** `tab-line-mode` shadowed by
`global-tab-line-mode` (last-write-wins; `my/bind` collision warning
fired silently to `*Messages*` on every startup). Fix: `t B` =
buffer-local `tab-line-mode`, `t G` = `global-tab-line-mode`,
mirroring the existing `l`/`L` line-numbers pattern.

**Embark had no working keys.** `C-c a embark-act` was overwritten by
`org-agenda` (correct per Policy clause 6); `C-;  embark-dwim` was
overwritten by `dl-motion.el`'s `avy-goto-char-timer`. Both embark
verbs were silently dead. Fix: `C-, embark-act` and `C-' embark-dwim`.
Displaces `goto-last-change` and `avy-goto-char-2` from those chords.
`goto-last-change-reverse` stays at `C-.`; `avy-goto-char-2` rescued
to `C-c j 2`.

**`C-c j` Policy violation.** `dl-motion.el` had
`("C-c j" . avy-goto-line)` — a single binding squatting on a
top-level family letter from outside `dl-keymap.el`. Fix: new
`my-jump-map` at `C-c j` declared centrally (`j j` line, `j c` char
timer, `j 2` 2-char, `j w` word). Chord bindings `C-:` / `C-;` in
`dl-motion.el` retained as escape hatches.

**Touched:** `core/dl-keymap.el`, `completion/dl-embark.el`,
`editing/dl-motion.el`, `editing/dl-search.el`, `KEYS.md`.

Deferred (Policy violations not swept this pass): `C-c q r` /
`C-c q q` visual-regexp in `dl-search.el` (not lifted central);
`C-c r …` org-roam (CHANGELOG previously flagged as "wired but
unused" — candidate for deletion next pass); `C-c S …` slack (the
whole module is currently disabled at `init.el:76`).

## 2026-05-17 — keymap policy + tier-1 families fleshed out

Written keybinding policy in `KEYS.md` (three-tier grammar — family
prefix at `C-c <letter>`, lower/upper variants within a family,
capital sub-prefixes for compartments), four previously-thin/empty
maps populated, project promoted to a parallel family.

**`C-c p` — project (new tier-1 family).**  Letters mirror
`project.el`'s `C-x p <letter>` defaults so muscle memory between the
two prefixes is identical.  `p p / f / b / k / d / D / c / r / g /
v / e / s / !`.  `C-c f F` (was `project-find-file`) and `C-c f p`
(was `project-switch-project`) retired — the file family is files
again.

**`C-c s` — search (scope ladder).**  Lowercase narrows, uppercase
widens.  `s s` line / `s S` line-multi; `s r` ripgrep (project) /
`s R` ripgrep (prompt dir); `s i` imenu (buffer) / `s I` imenu
(project); `s o` outline; `s d` find filenames; `s m` / `s M`
mark-ring / global-mark-ring; `s .` line-at-symbol.  Existing `C-c s
…` `:bind` block in `completion/dl-consult.el` retired; the letter
set rotated (`s g/f/l` → `s r/d/s`) for ladder consistency.  Two
helpers (`my/consult-line-symbol-at-point`,
`my/consult-ripgrep-prompt-dir`) live in `dl-consult.el`.

**`C-c e` — eval.**  Lowercase reads to minibuffer; uppercase
prints/inserts.  `e e` / `E` last sexp (read / print); `e f` defun;
`e r` region; `e b` buffer; `e i` ielm; `e s` scratch; `e x`
eval-expression; `e m` pp-macroexpand.

**`C-c o` — org (re-scoped).**  Cross-buffer entry points only —
in-buffer Org commands stay at Org's own `C-c C-<x>` (mode-specific
space, Org owns it).  `o h` heading (buffer) / `o H` heading
(agenda); `o j` clock-goto / `o i` clock-in-last / `o O` clock-out;
`o r` refile; `o q` `my/org-ql-find-here` (file-scoped, complementing
corpus-scoped `n q`); `o b` switchb; `o L` insert-link-global.  New
wrapper `my/org-ql-find-here` in `org/dl-org-ql.el`.

**Disabled session map retired.**  `C-c j` / `my-session-map` and
its commented easysession binds removed from `core/dl-keymap.el`;
which-key label dropped; meow leader entry dropped.  Easysession can
reclaim `j` (or land elsewhere) if it returns.

**`KEYS.md` overhaul.**  New `## Policy` section codifies the
three-tier grammar (Tier 1 family / Tier 2 variant / Tier 3
compartment) with the reserved-letters note (`C-c h` avoided because
`h` is the modal gateway).  Prefix index updated (drop `j`, add
`p`, retag `s`/`e`/`o`).  Full content sections added for
`C-c o / s / p / e`.  Three stale claims fixed: `which-key-idle-delay`
is `0.3`, not `1e6 (off)`; "empty maps" deferred-item retired; "re-enable
session map" deferred-item retired.

**Touched:** `core/dl-keymap.el`, `completion/dl-consult.el`,
`org/dl-org-ql.el`, `KEYS.md`.

Deferred (unchanged): hydras (window-resize is the natural first);
remaining `:bind` migrations into the prefix structure (`dl-embark`,
`dl-motion`, `dl-search`, `dl-fold`); `C-c d` (diagnostics) and
`C-c k` (config) reserved per the Policy budget.

## 2026-05-17 — work compartment in `~/notes`

First-class work compartment under `~/notes/work/`, mirroring the
existing class taxonomy plus two work-native classes (`meetings/`,
`people/`).  `work.org` reroled from a sparse log into the curated
dashboard described in `work.local.md`; the pre-change contents are
preserved verbatim at `work/archive/legacy-work.org`.

**Filesystem (notes repo).** New subtree:

```
work/
  inbox.org             :work:inbox:
  intake/  journal/  weekly/  meetings/  people/
  projects/  areas/  sources/  references/  slips/  indexes/
  attachments/  archive/
  archive/legacy-work.org   ← verbatim copy of pre-change work.org
```

`work.org` itself is now the dashboard (priorities, commitments,
waiting-on, deadlines, active projects, people, meetings, daily +
weekly work review checklists, entry-point links) with
`#+filetags: :work:index:`.  Single commit in the notes repo.

**Path module.** `core/dl-notes-paths.el` extended with 16 work
constants (`dl-notes-work-file`, `dl-notes-work-dir`, then per-class
subdir constants for `inbox`, `intake`, `journal`, `weekly`,
`meetings`, `people`, `projects`, `areas`, `sources`, `references`,
`slips`, `indexes`, `attachments`, `archive`).  New `my/notes-ensure-dirs`
creates any missing personal or work directories at load time (and
on-demand) — a fresh clone is self-bootstrapping.

**Constructors.** `my/denote--new` now accepts a class string *or* a
list of class strings; work constructors prepend two keywords (`work`
+ class), so a meeting note ends up
`work/meetings/<id>--<slug>__work_meeting_<extras>.org` with
`:work:meeting:` in `#+filetags:`.  Eight new constructors land:
`my/denote-new-work-{project,area,source,slip,reference,index,
meeting,person}`.  `denote-known-keywords` extended with `meeting`,
`person`, `work`, and the cross-boundary tags `work-relevant`,
`work-adjacent`, `management`, `technical-leadership`.

**Journal/weekly.** `org/dl-denote-journal.el` refactored: the file-
name builder, skeleton builder, and `ensure-file` helper now take dir
/ suffix / tags arguments.  Personal `my/journal-note`, `my/weekly-note`,
`my/journal--ensure-today` continue to work unchanged; new
`my/work-journal-note`, `my/work-weekly-note`, and
`my/work-journal--ensure-today` write to `work/journal/` and
`work/weekly/` with `__work_journal.org` / `__work_weekly_journal.org`
suffixes and `:work:journal:` / `:work:weekly:journal:` tags.

**Capture.** Nested `("w" "Work")` group with six children:

```
w i  Work inbox        work/inbox.org           * TODO …                :work:
w j  Work journal      today's work journal     * %U %?                 under * Log
w t  Work task         work/inbox.org           * TODO %?               :work:task:
w m  Work meeting      work/inbox.org           * %? :work:meeting:     + ATTENDEES/DATE drawer
w p  Work person       work/inbox.org           * %? :work:person:      + WHO drawer
w r  Work reference    work/inbox.org           * %? :work:reference:   + URL/AUTHOR/DATE/LICENSE/TRUST drawer
```

Same shape as the existing `s/S/r` source/slip/reference pipeline:
fast capture into `work/inbox.org`; durable promotion via the work
constructors.  `w j` uses `my/work-journal--ensure-today` as the
capture target so the file is created with skeleton on first touch
of the day.

**Agenda.** Three scopes via `org-agenda-custom-commands` rather than
modal `org-agenda-files` mutation:

```
C-c a a   default dispatcher (combined union — the new default)
C-c a p   personal-only
C-c a w   work-only
C-c a c   combined (explicit)
```

`my/org-agenda-refresh-files` walks personal + work scopes with
`directory-files-recursively` and stores three lists
(`my/org-agenda-{personal,work,combined}-files`).  Custom commands
bind `org-agenda-files` to the appropriate list per invocation —
boundary by directory custody, not tag.  Crossover via `:work-relevant:`
deferred; appending a filtered list to `my/org-agenda-work-files` is
the one-line extension when that pattern materialises.

Excluded by design (mirrors the existing personal exclusion):
`areas/`, `indexes/`, `references/`, `sources/`, `slips/`, `archive/`,
`attachments/`, `intake/` and their work counterparts.

**Review.** Six work commands mirror the personal set 1:1, factored
through small private helpers (`my/review--open-inbox`,
`my/review--dired-newest`, `my/review--weekly-with-waiting`,
`my/review--stale-cutoff`):

```
my/review-work-inbox
my/review-work-intake
my/review-work-weekly
my/review-work-stale
my/review-work-references-retained
my/review-work-references-untrusted
```

Plus `my/work-org-ql-find` — work-scoped wrapper around `org-ql-find`
bound to `C-c n W q`.

**Keymap.** `C-c n W` is a fourth notes sub-prefix alongside
`N / m / v`.  Constructors live directly under `W` (so personal
constructors at `C-c n N …` aren't overloaded); reviews under `W v`.
Eighteen new binds total.  `SPC n W …` works automatically through
the existing `my-notes-map` Meow leader mirror — `W` is not in the
keypad reserved set (`g`, `m`, `c`, `x`).

**Touched:** `core/dl-notes-paths.el`, `org/dl-denote.el`,
`org/dl-denote-templates.el`, `org/dl-denote-journal.el`,
`org/dl-org-capture.el`, `org/dl-org-agenda.el`, `org/dl-review.el`,
`core/dl-keymap.el`, `NOTES.md`, `KEYS.md`.  Notes repo: `work.org`,
`work/inbox.org`, `work/archive/legacy-work.org`.  No new requires in
`init.el` — all extensions live in modules already loaded.

Deferred: cross-boundary `:work-relevant:` agenda inclusion; work
deadlines / people-followups / active-projects review surfaces
(add when friction earns them).

## 2026-05-17 — notes system overhaul, Phase 7 (root-note triage)

Content-level work in `~/notes/`. No Emacs-config changes — just
re-homing the 6 root-level Denote notes left after Phase 1 into class
subdirs, and adding the reference metadata block to the 2 LLM-era
markdowns so the Phase 6 review queries start surfacing them.

**Re-homing.** Six `git mv`s, history preserved. Classification:

| Note | New dir | Signal |
|---|---|---|
| `substrate__emacs_idea_project_tech.org` | `projects/` | `:project:` tag in filename |
| `emacs-note-system__emacs_org_project_tech.org` | `projects/` | `:project:` tag in filename |
| `ricing-emacs__emacs_oss_tech.org` | `projects/` | content: TODO/NEXT list of emacs packages = active workstream |
| `risk-governance-glossary__…` | `indexes/` | content: glossary ≡ index per plan |
| `proficiency-with-emacs__emacs_org_pkm_tech.org` | `areas/` | content: topic map for ongoing emacs learning |
| `orchestration__ai_design_dev_tech.org` | `areas/` | content: standing principles in a domain |

The plan said all 6 had explicit class tags. Only 2 actually did; the
rest were classified from content. No external file-path-based links
existed (only the files' own `#+identifier:` lines reference them) so
no link surgery was needed. Denote-id-based links would survive a
move regardless.

Note for `ricing-emacs` in `projects/`: agenda now pulls in its
TODO/NEXT items (`dl-notes-projects-dir` is in `org-agenda-files`).
That's the intended shape of project-tier notes; if any item should
not be agenda-visible, change its keyword.

**Reference metadata.** Both Markdown references in `references/`
gained the metadata block the Phase 1 plan specified
(`status: raw`, `trust: unreviewed`, `captured-at:`). Each updated
its `tags:` list to start with `reference`. The plan said both were
LLM-generated; only one actually is:

- `pkm-research-report__pkm_research_slop.md` — LLM-generated (has
  ChatGPT/Claude `citeturn…` citation markers). Tags now include
  `reference, llm, untrusted`; `source: llm-generation` added.
- `how-a-researcher-uses-denote__emacs_pkm_web.md` — human-written
  blog post from lambdaland.org. Tags include `reference, web`;
  `source-url: https://lambdaland.org/posts/2025-07-11_research_notes/`
  added; trust still `unreviewed` until reviewed.

**Verification.** Both Phase 6 review queries now match:
`my/review-references-retained` (ripgrep `status: raw`) → 2 hits.
`my/review-references-untrusted` (ripgrep `untrusted` /
`trust: unreviewed`) → 2 hits.

**Out of scope:** `~/tasks/{10_daily, 20_weekly, 30_projects,
50_notes}` legacy markdown (per plan: "out of scope for the Emacs
config but flagged"). Single-format `archive/`, `attachments/`,
`intake/` triage is also a content task and will happen as captures
roll through.

That closes the planned overhaul. Phases 1-7 done; everything left is
either content (triaging incoming captures) or downstream
elaborations (more `dl-review` queries, more capture templates as
they earn their keep, eventual `dl-citar.el` if a bibliography ever
materializes).

## 2026-05-17 — notes system overhaul, Phase 6 (review module)

Phase 6: `org/dl-review.el` lands with six review commands wired
under the `C-c n v …` sub-prefix that Phase 4 stubbed out. Two
shapes:

- **Navigational** — open the buffer you want for a review pass.
- **Reporting** — surface items matching a review predicate, via
  `org-ql` for Org files or `consult-ripgrep` for the mixed
  `references/` formats (.org / .md / .pdf / .html).

```
C-c n v i   my/review-inbox                 open inbox + jump to first TODO
C-c n v I   my/review-intake                dired intake/, sorted newest first
C-c n v w   my/review-weekly                open weekly note + side window of WAITING items
C-c n v s   my/review-stale                 org-ql: WAITING items untouched > my/review-stale-days (7 default)
C-c n v r   my/review-references-retained   ripgrep: references with `status: raw`
C-c n v u   my/review-references-untrusted  ripgrep: `:untrusted:` tag or `trust: unreviewed`
```

**Stale-WAITING predicate.** Approximation: a WAITING item is stale
if no timestamp (active or inactive) in its subtree falls within the
last `my/review-stale-days` (defvar, default 7). Captured as
`(and (todo "WAITING") (not (ts :from CUTOFF)))`. Not exact — true
"time in WAITING" requires walking LOGBOOK state-change entries — but
the timestamp-of-anything-recent approximation is honest enough for
weekly triage. The user can flip the defvar to tighten.

**References review uses ripgrep, not org-ql.** `references/` is
explicitly multi-format per the plan (LLM markdowns, PDFs, web
clippings, .org files). Both `v r` and `v u` use `consult-ripgrep`
against the literal metadata strings (`status: raw`,
`trust: unreviewed`, `:untrusted:`) so any format with those flags
shows up. Current matches: zero — the 2 existing LLM .md references
predate the Phase 1 metadata convention and haven't been tagged.
Tagging them is a content-level task (Phase 7-ish), unblocked but
not done.

**`my/review--notes-files`** picks the query universe:
`inbox.org`, `projects/`, `areas/`, `sources/`, `slips/`,
`journal/`, `weekly/`. References excluded — they're not authored
content. Intake also excluded — it's an object dump, not Org.

**Touched:** `org/dl-review.el` (NEW; `git add`-ed so the flake
parser sees it), `core/dl-keymap.el` (six binds under
`my-notes-review-map`), `init.el` (`require 'dl-review`).

Phase 7 (root-note triage; promote the 6 root-level Denote notes
into class subdirs; tag the 2 LLM .md references for review) is the
last config-related slice — and it's mostly content work, not
Emacs-config work.

## 2026-05-17 — notes system overhaul, Phase 5 (org-ql + consult-notes + consult-org)

Phase 5 of the notes overhaul: install the new retrieval tools and
wire them to the existing Phase 4 keybinds. Concrete saved-search and
review commands continue to defer to Phase 6 (`dl-review.el`).

**New modules:**

- `org/dl-org-ql.el` — installs `org-ql`. `C-c n q` (`org-ql-find`)
  bound in Phase 4 now resolves. The dashboards/queries mentioned in
  the plan land in Phase 6 alongside the review commands — they're
  the same body of work (`my/notes-stale-items`, weekly review etc.
  are all `org-ql` queries).
- `completion/dl-consult-notes.el` — installs `consult-notes` with
  per-class file-dir sources backed by `dl-notes-*-dir` constants:

  ```
  Journal     j    Slips       S    Areas       a
  Weekly      w    References  r    Sources     s
  Projects    p    Indexes     i
  ```

  Narrow keys are typed at the consult prompt to scope to one class
  (e.g. `j SPC` for journal only). `consult-notes-denote-mode` is
  enabled on top so bare Denote-named files at `dl-notes-root` (the 6
  root-level notes pending Phase 7 triage) are still picked up.

**`consult-org-heading` binding** (consult bundles `consult-org`):

- `C-c o h` (`my-org-map "h"`) — in-buffer outline search. Lives in
  `core/dl-keymap.el` so it inherits the meow leader mirror
  (`SPC o h`).

**citar skipped.** Plan §5 says "only if a bibliography exists. Skip
otherwise." `rg -l 'citar|bibliography'` against `~/notes` returned
nothing meaningful — no `.bib` files, no `bibliography:` org-cite
front matter. Adding `citar` now would be speculative. The Phase 2
"deferred module" `org/dl-citar.el` stays unborn until there's
content to back it.

**Nix install verified.** Both packages landed in the new
`emacs-packages-deps` derivation under:

```
share/emacs/site-lisp/elpa/{org-ql-20250421.133, consult-notes-20260222.1928}
```

(Plus transitive deps `org-super-agenda`, `peg`, `ts`.) `consult-org`
needs no install — bundled with `consult`.

**Note for the running session.** The currently-running Emacs is
still backed by the *old* wrapper's elpa cache, so a restart is
needed to load `org-ql` / `consult-notes` from the proper path
on init. In the meantime, the live-eval workflow used to verify
phase 5 added the new elpa subdirs to `load-path` ad-hoc; that's
session-local and goes away on restart, which is the right shape.

**Touched:** `org/dl-org-ql.el` (NEW), `completion/dl-consult-notes.el`
(NEW), `core/dl-keymap.el` (consult-org-heading bind), `init.el`
(two requires).

Phase 6 (review workflow — `dl-review.el` with inbox/intake/weekly
sweeps and stale-item queries) and Phase 7 (root-note triage) remain.

## 2026-05-17 — notes system overhaul, Phase 4 (capture pipeline + `C-c n …` consolidation)

Phase 4 of the notes overhaul (plan
`~/.claude/plans/yes-use-dl-for-staged-quiche.md`). Two slices: capture
templates aligned with the promotion pipeline, and a single
`C-c n …` namespace with three sub-prefixes.

**New module: `org/dl-denote-templates.el`** — class constructors that
wrap `denote` per class. Each prompts for title + extra keywords, then
calls `denote` with the class tag prepended and the right subdir:

```
my/denote-new-project    -> projects/    :project:
my/denote-new-area       -> areas/       :area:
my/denote-new-source     -> sources/     :source:
my/denote-new-slip       -> slips/       :slip:
my/denote-new-reference  -> references/  :reference:
my/denote-new-index      -> indexes/     :index:
```

Class is encoded twice — by file location *and* by the leading keyword
— so downstream filters (org-ql, consult-notes, agenda regex) can pick
either signal.

**Capture rework (`org/dl-org-capture.el`).** Old template letters
`i / f / P / r` were replaced with a pipeline-aligned set; old `j`
datetree (`journal/log.org`) was retired in favour of appending into
today's Denote-named journal file:

```
c   Inbox text        -> inbox.org   * TODO …
j   Journal (today)   -> today's denote journal, under * Log
s   Source intake     -> inbox.org   * … :source:    + URL/AUTHOR drawer
S   Slip intake       -> inbox.org   * … :slip:
r   Reference intake  -> inbox.org   * … :reference: + URL/AUTHOR/DATE/LICENSE/TRUST drawer
p   Protocol          unchanged (sprig/org-capture-extension)
L   Protocol Link     unchanged
```

The `j` target uses a new helper `my/journal--ensure-today` in
`dl-denote-journal.el`, which creates today's file with the skeleton if
absent so capture has somewhere to land before the user has hit
`C-c n j` for the day. The helper is shared with `my/journal-note`
itself (extracted alongside `my/journal--today-file` and
`my/journal--today-skeleton`).

Dropped templates: `i` (renamed to `c`), `f` (use `c` and delete the
TODO marker, or `denote`/class constructors), `P` (use `C-c n N p`),
old `r` "Reading note" (repurposed for reference intake). The
`f` file-intake template the plan flagged as optional is not yet
written — intake-dir workflow is content-level (Phase 7).

**Keymap consolidation (`core/dl-keymap.el`).** Single `my-notes-map`
at `C-c n` (mirrored as `SPC n` via mode-specific-map = meow leader),
with three sub-prefixes (`my-notes-new-map`, `my-notes-manage-map`,
`my-notes-review-map`). Full table:

```
C-c n c   org-capture                          C-c n N p   new project
C-c n j   my/journal-note                      C-c n N a   new area
C-c n w   my/weekly-note                       C-c n N s   new source
C-c n n   denote                               C-c n N S   new slip
C-c n f   consult-notes              (Ph5)     C-c n N r   new reference
C-c n s   consult-notes-search…     (Ph5)     C-c n N i   new index
C-c n l   org-store-link                       C-c n N j   journal today
C-c n i   denote-link                          C-c n N w   weekly
C-c n o   org-open-at-point-global
C-c n g   org-mark-ring-goto                   C-c n m r   denote-rename-file
C-c n b   denote-backlinks                     C-c n m R   …-using-front-matter
C-c n q   org-ql-find               (Ph5)     C-c n m k   denote-rename-file-keywords
                                               C-c n m t   denote-rename-file-title
C-c n v   (review prefix — commands Ph6)
```

Phase-5 bindings (`f / s / q`) are wired to symbols that aren't yet
installed; the void-function error only surfaces if pressed before
Phase 5 lands. Cheaper than stubbing them out twice — `declare-function`
forms at the top of `dl-keymap.el` keep the byte-compiler quiet.

Plan §4b had split keyword edits into `m k` (add) and `m K` (remove),
but denote 3.x collapsed those into a single editor
(`denote-rename-file-keywords`) that prepopulates the existing list and
lets the user add or remove inline. Collapsed the bindings to match:
`m k` only, `m K` unbound.

**Migrations from previous bindings**:

- `C-c n n / l / b / r / R` (`:bind` block in `dl-denote.el`) → moved to
  `my-notes-map` (`n` denote, `i` denote-link [was `l`], `b` backlinks,
  `m r` rename, `m R` front-matter rename). The `dl-denote.el` `:bind`
  block was removed.
- `C-c n j / w` (`global-set-key` in `dl-denote-journal.el`) → moved to
  `my-notes-map`. The redundant `(define-key … "C-c n d" nil)` retire-
  binding is gone too — `C-c n d` simply isn't defined anymore.

**Denote known-keywords extended** to include the full class set
(`area`, `slip`, `index`, `weekly`) so completion at the keyword prompt
suggests them.

**Touched:** `org/dl-denote-templates.el` (NEW — `git add`-ed so the
flake parser sees it), `org/dl-org-capture.el` (template rewrite),
`org/dl-denote-journal.el` (factored helpers; binds moved out),
`org/dl-denote.el` (binds moved out; known-keywords extended),
`core/dl-keymap.el` (notes map + sub-prefixes + meow leader mirror),
`init.el` (`require 'dl-denote-templates`).

Phases 5-7 (org-ql / consult-notes / citar; review workflow; root-note
triage) remain.

## 2026-05-17 — notes system overhaul, Phase 3 (Denote-named journaling) + org-modern fix

**Journaling moves to Denote naming.** `dl-denote-journal.el` rewritten:

- `my/journal-note` (new name; replaces `my/daily-note`) →
  `journal/YYYYMMDDT000000--YYYY-MM-DD-<weekday>__journal.org`. Today
  resolves to `20260517T000000--2026-05-17-sunday__journal.org`,
  matching the 5 migrated files from Phase 1.
- `my/weekly-note` (kept the name) → `weekly/<monday-id>--YYYY-w<NN>__weekly_journal.org`.
  Identifier anchors on the ISO-week Monday, so the file sorts to the
  start of its week regardless of which day it's first opened. Today
  resolves to `20260511T000000--2026-w20__weekly_journal.org`.
- New helper `my/journal--iso-monday` shifts a time back to its ISO
  Monday using `%u` (1=Mon … 7=Sun).
- Templates set `#+title:`, `#+filetags:`, `#+date:` on first-open;
  body skeletons unchanged from before.

**Keybind rebind** (per the agreed Phase 4 keymap):

- `C-c n d` (was `my/daily-note`) — unbound via
  `(define-key global-map ... nil)`.
- `C-c n j` → `my/journal-note` (new).
- `C-c n w` → `my/weekly-note` (unchanged).

Roll-own rather than upstream: denote 4.1.3 in the Nix overlay ships
without the `denote-journal` submodule (split off in 4.x and not yet
packaged here). The roll-own is ~40 lines and lets us keep the exact
filename convention the migrated files use (`T000000` + weekday-in-slug).

The Phase 2 `j` capture template (datetree in `journal/log.org`) is
left in place — different ergonomic shape (quick fragment append vs.
full-page operational log). Retire later if it goes unused.

**org-modern fix** (longstanding no-op, flagged in Phase 2):

```elisp
;; was:
(use-package org-modern
  :after
  (add-hook 'org-mode-hook #'org-modern-mode)
  (add-hook 'org-agenda-finalize-hook #'org-modern-agenda))

;; now:
(use-package org-modern
  :hook ((org-mode            . org-modern-mode)
         (org-agenda-finalize . org-modern-agenda)))
```

`:after` takes a package list, so the two `add-hook` forms were being
parsed as package names and silently dropped — `org-modern-mode` was
never actually attached to `org-mode-hook`. Now it auto-enables on
every Org buffer (no more manual toggle).

**Touched:** `org/dl-denote-journal.el` (rewrite), `org/dl-org.el`
(org-modern hooks).

## 2026-05-17 — notes system overhaul, Phase 2 (module decomposition)

Pure refactor: split `org/dl-org.el` into focused modules. No behaviour
change — every binding, template, advice, and var resolves the same as
before.

**New modules** (all under `org/`, all tracked via git so the Nix flake
parser picks them up):

- `dl-org-capture.el` — capture templates (7: `i/f/j/P/r/p/L`),
  `my/capture-body`, `my/capture-entry`, `my/sanitize-link-description`,
  `my/org-capture-delete-client-frame` + the
  `my/org-capture-delete-frame-on-finalize` flag, advice on
  `org-capture-finalize`/`kill`, and the `C-c c` global binding.
- `dl-org-agenda.el` — `org-agenda-files` (now derived from
  `dl-notes-*` constants), `C-c a` global binding. Custom agenda
  commands land here in Phase 5.
- `dl-org-links.el` — `C-c l` (`org-store-link`). Home for the Phase 4
  consolidated `C-c n l/i/o/g` link namespace.
- `dl-denote-journal.el` — `my/daily-note`, `my/weekly-note`, and their
  `C-c n d/w` bindings. Home for the Phase 3 Denote-named rewrite.

**Slimmed `dl-org.el`**: keeps org defaults (directory, todo keywords,
tag-alist, log-done, return-follows-link, speed-commands), org-modern
and org-bullets styling, and the mode-hook spacing tweak. Everything
else moved out.

**init.el load order** (in section `;; Org`):

```
(require 'dl-org)
(require 'dl-org-capture)
(require 'dl-org-agenda)
(require 'dl-org-links)
(require 'dl-denote)
(require 'dl-denote-journal)
(require 'dl-org-roam)
```

**Modules deferred** rather than created empty (per "no half-finished
implementations"):

- `dl-denote-templates.el` — class constructors (`my/denote-new-project`
  etc). Phase 3/4 when they have content.
- `dl-org-ql.el` / `dl-citar.el` — Phase 5, when the packages land.
- `dl-review.el` — Phase 6.
- `dl-writing.el` — `core/dl-prose.el` already covers prose/spelling
  cleanly; the plan's `dl-writing.el` is redundant with what exists.
  Keeping `dl-prose.el` where it is.

**Known pre-existing bug** (left untouched, flagged for later):
`org-modern`'s `use-package` block uses `:after` followed by `add-hook`
calls — `:after` takes a package list, not body forms, so the hooks
never get added. `org-modern-mode` is currently not actually enabled on
`org-mode-hook`. Fix: change `:after` to `:config` (or `:hook`). Not
part of Phase 2's "no behaviour change" promise.

**Touched:** `init.el`, `org/dl-org.el` (slimmed), 4 new modules under
`org/`.

## 2026-05-17 — notes system overhaul, Phase 1 (paths + dirs + TODO)

First slice of the notes-system overhaul plan
(`~/.claude/plans/yes-use-dl-for-staged-quiche.md`). No new packages, no
module decomposition — just the substrate.

**Filesystem.** `~/notes` was a symlink to `~/tasks/00_inbox/`; promoted
in place: `rm` the symlink, `mv ~/tasks/00_inbox ~/notes`. Reorganised
inside the new real `~/notes/`:

- Created `intake/ journal/ weekly/ projects/ areas/ sources/ slips/
  indexes/ references/ attachments/ archive/`.
- `_archived/` → `archive/`, `assets/` → `attachments/`, `context/` →
  `references/` (the two LLM research markdowns land here; will need
  `:reference:llm:untrusted:` tags on review per the plan).
- 5 daily files in `2026/YYYY-MM-DD.org` → renamed to Denote-style
  `YYYYMMDDT000000--yyyy-mm-dd-weekday__journal.org` under `journal/`.
- Deleted empty placeholders (`indices/`, `notes/`, `refs/`, `writing/`)
  whose names don't match the new vocab. `projects/` was already
  on-name; kept.
- 6 root-level Denote notes left at root — homing into class subdirs is
  Phase 7 triage (content, not config).
- `.git/`, `.gitignore`, `.org-roam.db` preserved via the bulk dir
  move. Corpus history intact.
- `~/tasks/{10_daily, 20_weekly, 30_projects, 40_areas, 50_notes,
  90_archive}` left untouched — legacy parking, separate triage.

**New module: `core/dl-notes-paths.el`.** Single source of truth for
notes paths. Defines `dl-notes-root`, `dl-notes-inbox-file`, and
per-class dir constants (`dl-notes-{intake,journal,weekly,projects,
areas,sources,slips,indexes,references,attachments,archive}-dir`), plus
`my/notes-path` for joining segments under root. Required early in
`init.el` (after `dl-core`).

**Downstream rewires** (replace string literals with constants):

- `org/dl-org.el`: `org-directory`, `org-default-notes-file`,
  `org-agenda-files`, all capture-template file paths, and
  `my/daily-note`/`my/weekly-note` now derive from `dl-notes-*`. Daily
  and weekly point at the new `journal/`/`weekly/` dirs but keep the
  simple `YYYY-MM-DD.org` / `YYYY-WNN.org` naming for now — Denote-named
  rewrite is Phase 3. Agenda dropped the (gone) `writing/` and added
  `weekly/`. Duplicate `(global-set-key "C-c c" #'org-capture)` (had
  shadowed itself at L130) removed.
- `org/dl-denote.el`: `denote-directory` → `dl-notes-root`.
- `org/dl-org-roam.el`: `org-roam-directory` → `(file-truename
  dl-notes-root)`. Roam stays wired but unused (separate
  acceleration layer per the plan; not the primary navigator).

**TODO state expansion.** Old: `TODO NEXT WAIT | DONE CANCELLED`. New:
`TODO NEXT STARTED WAITING(w@/!) | DONE(d!) CANCELED(c@) MOVED(m@)`.
Logging triggers added (`!` for done, `@` for waiting/canceled/moved).
One existing match (`work.org:5` had `** WAIT`) swept via `sed` to
`WAITING`. `CANCELLED` → `CANCELED` rename had no matches.

**Touched:** `core/dl-notes-paths.el` (new — tracked via git so the Nix
flake parser sees it), `init.el`, `org/dl-org.el`, `org/dl-denote.el`,
`org/dl-org-roam.el`, plus the filesystem migration outside the repo.

Phases 2-7 (module decomposition, Denote-based journaling, capture
template rework + keymap consolidation, org-ql/consult-notes/citar,
review workflow, root-note triage) remain.

## 2026-05-16 — org-protocol capture from Firefox

Wired up [sprig/org-capture-extension](https://github.com/sprig/org-capture-extension)
end-to-end. Three bugs found en route:

- **Desktop handler used `%F` (files) instead of `%u` (URL)**, so the
  Emacs-provided `emacsclient.desktop` silently dropped the
  `org-protocol://` URI and created a blank frame. New
  `~/.local/share/applications/org-protocol.desktop` (tracked via the
  sparse `~/` worktree) handles the scheme with `%u`, `--create-frame`,
  `--no-wait`.
- **`(concat org-directory "protocol.org")`** produced
  `~/notesprotocol.org`. Replaced with `expand-file-name`.
- **Duplicate template key `p`**: "Project task" shadowed "Protocol"
  (assoc returns first match). Renamed Project task to `P`.

Templates corrected to use the org-protocol plist keys (`%:link`,
`%:description`) instead of `%u` (which is the inactive timestamp, not
the URL) and `%c` (clipboard pollution).

Two improvements from the sprig README, with safety tweaks:

- **`my/sanitize-link-description`** replaces `[` `]` in the `L`
  template's description so ArXiv-style titles don't break the
  `[[link][desc]]` syntax.
- **Auto-close the emacsclient frame** after `org-capture-finalize` /
  `org-capture-kill`.  Uses a boolean flag set by the template (cleaner
  than sprig's counter) and guards with `(frame-parameter nil 'client)`
  + `(cdr (frame-list))` so manual `C-c c p` from the main frame is
  safe and the last frame is never deleted.  Refile is covered by the
  finalize advice — refile calls finalize internally.

**Touched:** `org/dl-org.el`, `~/.local/share/applications/org-protocol.desktop`.

## 2026-05-16 — session leader + meow `h` as C-c, autosave hook fix

Two related cleanups around the leader system.

**`my-session-map` (`C-c j` / `SPC j` / `h j`).** Easysession's defaults
were `C-c s*`, which `define-key` silently descended into `my-search-map`
(squatting in the search namespace). Moved them onto their own prefix
with which-key labels and meow leader mirror, via `my/bind`:

```
C-c j s   save           C-c j r   rename
C-c j l   load           C-c j R   reset
C-c j L   load+geometry  C-c j u   unload
                         C-c j d   delete
```

**Meow normal `h` → `mode-specific-map`.** Bound `h` directly to the C-c
keymap, so `h f f`, `h j s` etc. work from normal state as a third path
alongside `C-c` and `SPC`. Bonus over `SPC`: lowercase `g` / `m` work
without the capital workaround (no meow-keypad in the way). Dropped
`meow-left` — home-row arrows live on a layer.

**Autosave bug.** `(add-hook 'after-focus-change-function …)` was wrong
— that variable holds a single function (`#'ignore` advised by
`blink-cursor--rescan-frames`), not a hook list. `add-hook` cons'd the
function onto the existing advised form, producing an uncallable list and
spamming `Invalid function:` on every focus event. Replaced with
`add-function :after`, arity-tolerant via a `&rest _` wrapper.

**Touched:** `core/dl-keymap.el`, `editing/dl-persist.el`, `KEYS.md`.

## 2026-05-16 — file manager: dired/dirvish + yazi/broot wrappers

Consolidated the file-management stack on Dired + Dirvish, with Yazi and
Broot reachable as ghostel terminals that hand a path back to Emacs on
exit. Single home for everything under `my-file-map` (`C-c f` / `SPC f`):
`d` dired-jump, `D` dirvish, `t` dirvish-side, `F` project-find-file, `p`
project-switch, `y` yazi, `b` broot. Existing `f/s/S/r` kept.

Retired `dired-preview`, `dired-sidebar`, `nerd-icons-dired`, `dired-subtree`,
plus a duplicate `recentf` block in `editing/dl-persist.el` and the stray
`("C-c f" . dirvish-dwim)` bind that was shadowing the prefix. `C-x C-n`
moved from `dired-sidebar-toggle-sidebar` to `dirvish-side`.

Yazi uses `--cwd-file`, Broot uses `--outcmd` (parses the `cd PATH` line —
use **alt-enter** to fire `:cd`). Sentinel kills the ghostel buffer on exit.

See `FILE_MANAGER.md` for the full layout and the traps hit along the way
(missing `(require 'dl-dirvish)` in `init.el`, `lexical-binding` cookie on
the wrong line).

**Touched:** `apps/dl-dired.el`, `apps/dl-dirvish.el`, `core/dl-keymap.el`,
`core/dl-interface.el`, `editing/dl-project.el`, `editing/dl-persist.el`,
`init.el`.

## 2026-05-16 — nixd over nil, with flake-aware completion

Switched the Nix LSP from `nil` to `nixd` and fed it workspace settings so it
can evaluate the flake at `~/flakes`:

- `nixpkgs.expr` resolves to the flake's own nixpkgs input → completion for
  real package attrs (`pkgs.<TAB>`).
- `options.nixos` → `nixosConfigurations.Sleipnir.options` (option completion
  + docs under `config.*` in NixOS modules).
- `options.home-manager` → `homeConfigurations.david.options` (same for HM
  modules).
- `formatting.command` → `alejandra`, matching the flake's treefmt.

Hostname and HM user are hardcoded constants in `lang/dl-nix.el`. First
completion in a session is slow (full flake eval); subsequent calls are
cached. Activate with `M-x eglot-reconnect` in a `.nix` buffer.

**Touched:** `lang/dl-nix.el`.

## 2026-05-16 — vterm → ghostel

Replaced the vterm/multi-vterm/vterm-toggle stack with [ghostel](https://github.com/dakra/ghostel)
(libghostty-vt). Shpool session management (`apps/dl-shpool.el`) was ported to
ghostel's API in the same change — `shpool attach` is now spawned directly via
`ghostel-exec` instead of "open vterm, then send `exec shpool attach NAME`".

**Touched:** `apps/dl-term.el`, `apps/dl-shpool.el`, `core/dl-keymap.el`.

### Recovery — restoring vterm

To roll back, drop ghostel and reinstate the three blocks below in
`apps/dl-term.el`, plus the old `my-term-map` bindings in `core/dl-keymap.el`.

`apps/dl-term.el` (was the entire ghostel section):

```elisp
(use-package vterm
  :commands vterm
  :custom
  (vterm-kill-buffer-on-exit t)
  :bind (:map vterm-mode-map
          ("C-c <escape>" . vterm-send-escape))
  :config
  (setq vterm-max-scrollback 100000))

(use-package multi-vterm
  :after vterm
  :commands (multi-vterm multi-vterm-next multi-vterm-prev))

(defun my/vterm-named (name)
  "Open or create a named (for NAME) vterm buffer."
  (interactive "sVTerm name: ")
  (let ((buf-name (format "*vterm:%s*" name)))
    (if (get-buffer buf-name)
      (pop-to-buffer buf-name)
      (vterm buf-name))))

(use-package vterm-toggle
  :custom
  (vterm-toggle-hide-method 'delete-window)
  (vterm-toggle-fullscreen-p nil)
  :bind (([C-f1] . vterm-toggle)
          ([C-f2] . vterm-toggle-cd))
  :init
  (add-to-list 'display-buffer-alist
    '((lambda (buffer-or-name _)
        (let ((buffer (get-buffer buffer-or-name)))
          (equal major-mode 'vterm-mode)))
       (display-buffer-reuse-window display-buffer-at-bottom)
       (dedicated . t)
       (reusable-frames . visible)
       (window-height . 0.3)))
  :config
  (define-key vterm-mode-map [(control return)] #'vterm-toggle-insert-cd)
  (define-key vterm-mode-map (kbd "M-n")        #'vterm-toggle-forward)
  (define-key vterm-mode-map (kbd "M-p")        #'vterm-toggle-backward))
```

`core/dl-keymap.el` — replace the current `ghostel`/`ghostel-other` lines:

```elisp
(my/bind my-term-map "t" #'multi-vterm      "vterm")
(my/bind my-term-map "n" #'multi-vterm-next "vterm-next")
(my/bind my-term-map "P" #'multi-vterm-prev "vterm-prev")
```

`apps/dl-shpool.el` — shpool used to `(vterm buf-name)` then send
`exec shpool attach NAME\n` via `vterm-send-string` + `vterm-send-return`.
Mode checks were `'vterm-mode'`. Git history at this commit's parent has the
full pre-port version if needed.
