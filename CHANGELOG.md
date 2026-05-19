# Changelog

Notable changes to this Emacs config. Loosely dated; not versioned.

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
