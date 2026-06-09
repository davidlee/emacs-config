---
id: IP-010-P02
slug: "010-decouple_satan_perception_from_agent_run-phase-02"
name: IP-010 Phase 02
created: "2026-06-10"
updated: "2026-06-10"
status: completed  # one of: completed | deferred | draft | in-progress | pending
kind: phase  # one of: audit | delta | design_revision | issue | memory | phase | plan | policy | problem | prod | requirement | risk | spec | standard | task | verification
plan: IP-010
delta: DE-010
---

# Phase 2 - Per-source intra-day ingest cursor

## 1. Objective

Add a **per-source ingest cursor** — the evidence-assembly consumption frontier,
distinct from the per-sensor probe watermarks shipped in Phase 1. Keyed on each
source's native field (focus/browser `end_ts`, content `captured_at`; **git
excluded**). `consume` advances the cursors after a successful run; `perceive`
**never** touches them. Surface **backlog depth (`head − cursor`)** as an
`emacsclient`-callable read fn (the value a waybar widget would poll) and assess
the waybar-config wiring — **do not** edit `~/flakes`/waybar config this delta.
Intra-day only: `(cursor, head]` cannot cross midnight (deferred, DR §8).
Additive / low-risk: missing or zero cursor ⇒ "consume from head".

## 2. Links & References

- **Delta**: DE-010 §3 (Scope), §5 (Approach)
- **Design Revision Sections**: DR-010 §3 ("Cursor / watermark, per-source,
  intra-day"; boundary table row "advance ingest cursor → consume"), §4 (Code
  Impact: NEW per-source ingest-cursor store, evidence.el), §7
  (DEC-cursor-per-source-intra-day), §8 (open: cross-midnight), §9 (rollback:
  missing cursor = consume-from-head)
- **Specs / PRODs**: none — doc-canon (DEC-spec-authority-stays-doc)
- **Support Docs**: `docs/satan/perceptual-design.md`, `docs/satan/architecture.md`
  ("State: append-only artifacts"), `docs/satan/data-collection.md`

## 3. Entrance Criteria

- [x] Phase 1 complete — perceive/consume seam landed (`32c7dc9`), `just check`
      green (982/991)
- [x] `consume` (`broker--spawn`) is the single place cursors advance (probe
      commits already live there)
- [x] No existing per-source ingest-cursor store (investigation 2026-06-10 — §10);
      sensor `*-state.json` files are private probe marks, not the assembly frontier

## 4. Exit Criteria / Done When

- [ ] Per-source ingest-cursor store persists frontiers for focus (`end_ts`),
      browser (`end_ts`), content (`captured_at`); git excluded
- [ ] `consume` advances each source's cursor to that source's head **after a
      successful run only**; `perceive` never writes the cursor (spy in
      VT-perceive-pure extended to the cursor writer)
- [ ] Cursor advance is **intra-day**: `(cursor, head]` confined to one day-file;
      cross-midnight not attempted (documented deferral)
- [ ] Doubled / late invocation is idempotent within a day (advance to head is a
      max, not an increment)
- [ ] Missing / zero / unparseable cursor ⇒ "consume from head" (additive
      fallback, no error)
- [ ] Backlog depth (`head − cursor`) exposed as an `emacsclient`-callable read fn
      per source; waybar-config wiring **assessed** and written down (NOT built)
- [ ] VT-cursor-advance green (flip coverage entry `planned → verified`)
- [ ] exactly one cursor store remains (no parallel implementation); probe
      watermarks untouched
- [ ] `bin/elisp-locate-paren-error` `{"ok":true}` after every `.el` edit
- [ ] `just check` green (no regressions vs 982/991 baseline)

## 5. Verification

- `bin/elisp-locate-paren-error FILE` after each `.el` edit → `{"ok":true}`
  before byte-compile/tests (AGENTS.md elisp gate).
- **VT-cursor-advance** (new, `dl-satan-broker` or a dedicated cursor-store test
  file — follow `(provide 'basename)` rule, `mem.fact.satan.batch-ert-redefined-double-load`):
  - consume advances per-source cursors to head;
  - perceive advances **nothing** (forbidden-call spy on the cursor writer, added
    to the existing VT-perceive-pure spy set);
  - doubled/late invocation idempotent within a day (second advance is a no-op
    because head unchanged; out-of-order row behind cursor does not regress it);
  - missing cursor ⇒ consume-from-head (no error, frontier initialises to head).
- **Backlog-depth fn**: unit test that `head − cursor` returns the expected
  per-source depth on a fixture with a known cursor + segment tail; zero when
  cursor == head; full count when cursor missing.
- Regression: VT-perceive-pure (extended), VT-probe-split, VT-cursor-advance all
  green; `just check` full suite green.

## 6. Assumptions & STOP Conditions

- **Assumptions**:
  - The cursor is a **separate** JSON-state file under `~/.local/state/satan/`,
    following the established sensor `*-state.json` read/write idiom (NOT a reuse
    of any sensor's private mark — those advance on a different cadence/key).
  - "Source" = evidence source (focus / browser / content), NOT per-app_id /
    per-domain. Three frontiers, one file (a plist keyed by source).
  - `head` per source: focus/browser via `dl-satan-memory-evidence--newest-segment-end`
    (max `:end_ts`, evidence.el:141); content via max `:captured_at` (mirror).
  - The cursor's read boundary plugs into `assemble-with-bounds(start end …)`
    (evidence.el:589) — but this delta builds **no positive per-segment replay
    pass** (DR §3 "negative guarantee only"). The cursor advances the frontier
    and feeds backlog depth; it does not yet gate what evidence is assembled.
    Confirm with the design whether `consume` should pass `cursor` as the read
    `start` this delta or only advance/surface it (see §9 open decision).
- **STOP when**:
  - the design would require a positive replay pass / cross-midnight read to meet
    an exit criterion (out of scope — DR §8; `/consult`);
  - extracting a shared JSON-state helper looks necessary to advance (it touches
    3 existing sensor files — blast radius beyond "additive"; `/consult` before
    widening scope);
  - any change would re-enable a perception timer or move perception out of
    `.emacs.d` (POL-001).

## 7. Tasks & Progress

_(Status: `[ ]` todo, `[WIP]`, `[x]` done, `[blocked]`. Serial dispatch — user
instruction 2026-06-10. Build order top-to-bottom; later tasks depend on the
`head` read from 2.1.)_

| Status | ID  | Description                                              | Parallel? | Notes |
| ------ | --- | ------------------------------------------------------- | --------- | ----- |
| [x]    | 2.1 | New per-source ingest-cursor store (read/write/head)    | [ ]       | `dl-satan-ingest-cursor.el` (B1, opus). focus/browser parsed-instant, content string< |
| [x]    | 2.2 | `consume` advances cursors on successful run only       | [ ]       | broker `--spawn:859`, after probe commits, soft-fail; denial/perceive skip confirmed |
| [x]    | 2.3 | Backlog-depth read fn (`head − cursor`) + waybar assess | [ ]       | `-backlog-depth` → `(:focus N :browser N :content N :total N)`; assess-only (B2) |
| [x]    | 2.4 | VT-cursor-advance + extend VT-perceive-pure spy; gate   | [ ]       | 8 VTs in `dl-satan-ingest-cursor-test.el`; perceive-pure spies cursor writer; coverage verified; 990/999 |

### Task Details

- **2.1 New per-source ingest-cursor store**
  - **Design / Approach**: one JSON-state file (e.g.
    `~/.local/state/satan/ingest-cursor.json`) holding a plist keyed by source
    `{:focus END_TS, :browser END_TS, :content CAPTURED_AT}`. Read returns the
    plist (nil/missing source ⇒ nil ⇒ caller treats as "from head"). Provide a
    `head` accessor per source (focus/browser → `--newest-segment-end`; content →
    max `:captured_at`). Advance = write `max(current, head)` per source
    (idempotent, out-of-order safe — same discipline as the Phase-1 probe
    high-water bugfix). Git deliberately absent.
  - **Files / Components**: NEW `satan/dl-satan-ingest-cursor.el` (or smallest
    home that avoids a parallel impl — confirm no better host). Reads head via
    `satan/dl-satan-memory-evidence.el` (`--newest-segment-end`, content max).
  - **Testing**: read/write round-trip; advance-is-max (out-of-order row behind
    cursor does not regress); missing file ⇒ nil.
  - **Observations & AI Notes**: DRY watch — this is the 4th JSON-plist-state
    file. Do NOT extract a shared helper inside this phase (3-file blast radius,
    breaks "additive"); log the extraction as an improvement instead (§8 / notes).
  - **Commits / References**: —

- **2.2 `consume` advances cursors on a successful run**
  - **Design / Approach**: in `dl-satan-broker--spawn` (consume), after a
    successful run — alongside the existing probe commits — advance each source's
    ingest cursor to its head. **Only** on success; perceive and all denial paths
    (`--write-no-child-run` callers) must not advance. Intra-day: rely on the
    day-file boundary the evidence assembler already enforces.
  - **Files / Components**: `satan/dl-satan-broker.el` (`--spawn`).
  - **Testing**: covered by VT-cursor-advance (2.4) — advance on success,
    no-advance on perceive/denied.
  - **Observations & AI Notes**: keep the advance a single call mirroring the
    probe-commit placement so the consume side stays legible.
  - **Commits / References**: —

- **2.3 Backlog-depth read fn + waybar assessment**
  - **Design / Approach**: `emacsclient`-callable fn returning `head − cursor`
    per source (count of segments newer than cursor, or the pair). Zero when
    `cursor == head`; full count when cursor missing. **Assess** the waybar-config
    change (the existing widget calls `emacsclient` on a timer — document the exact
    new call + render, where the config lives, that it needs `home-manager switch`)
    but **do not edit** `~/flakes`/waybar config (user decision 2026-06-10).
  - **Files / Components**: read fn in `.emacs.d` (POL-001). Assessment captured
    in §10 / notes.md.
  - **Testing**: unit test on a fixture (known cursor + tail → expected depth;
    cursor==head → 0; missing → full).
  - **Observations & AI Notes**: this is the §8 gate-check row 4 ("waybar wiring
    assessed") + IP exit "waybar widget assessed".
  - **Commits / References**: —

- **2.4 VT-cursor-advance + verification gate**
  - **Design / Approach**: author VT-cursor-advance (see §5). Extend the existing
    VT-perceive-pure forbidden-call spy set to include the cursor writer (perceive
    must never advance). Flip the IP coverage entry `planned → verified`. Run
    `just check`.
  - **Files / Components**: `satan/test/dl-satan-broker-test.el` (or new cursor
    test file with `(provide …)`); extend the perceive-pure spy.
  - **Testing**: this IS the test task; gate `just check` green.
  - **Commits / References**: —

## 8. Risks & Mitigations

| Risk | Mitigation | Status |
| ---- | ---------- | ------ |
| Cursor conflated with probe watermark (parallel impl) | Separate store/file; probe marks untouched; investigation §10 confirms no existing host | open |
| Cursor advances on a denied/perceive path (over-consumption) | Advance only in `--spawn` success path; VT spies perceive + denial paths | open |
| Out-of-order rows regress the cursor | Advance = `max(current, head)`, never assign; mirrors Phase-1 probe high-water fix | open |
| Cross-day backlog silently dropped | Intra-day scope explicit; negative guarantee only; deferred (DR §8) | accepted |
| Scope creep into a shared state-helper refactor | STOP condition (§6); log as improvement, don't extract this phase | open |
| Backlog fn drifts from real head (content vs focus key) | Per-source head accessor uses each source's native field; unit-tested | open |

## 9. Decisions & Outcomes

- `2026-06-10` - **Serial dispatch** (user). Build order 2.1→2.4; 2.2/2.3 both
  consume the `head` read from 2.1, so serial avoids re-deriving it.
- `2026-06-10` - **Surface only, no waybar build** (user). Build the
  `emacsclient`-callable `head − cursor` fn + assess wiring; do NOT edit
  `~/flakes`/waybar config (it's just config calling emacsclient on a timer).
- `2026-06-10` - **No shared JSON-state helper this phase.** 4th state file, but
  extraction touches 3 sensor files — beyond "additive"; logged as improvement.
- **OPEN (resolve in 2.1/2.2)**: does `consume` pass `cursor` as the
  `assemble-with-bounds` read `start` this delta, or only advance + surface it?
  DR §3 says "no positive per-segment replay pass — negative guarantee only",
  which points to **advance + surface only**. Confirm against evidence assembler
  before wiring a read boundary; `/consult` if it implies a replay pass.

## 10. Findings / Research Notes

Investigation 2026-06-10 (read-only, `satan/`):

- **No existing per-source ingest-cursor store.** Each sensor owns a single-value
  JSON state file (`~/.local/state/satan/sensor-{curiosity,content,wpm}.json`),
  read/write via private `--read-state`/`--write-state`; keys are `:last_inspected`
  (curiosity/content) and `:last_state`/`:last_emitted_at` (wpm). These are probe
  marks (advance on probe commit), **not** the evidence-assembly frontier. No
  shared store abstraction; no per-source/per-app keying anywhere.
- **Head accessors exist**: `dl-satan-memory-evidence--newest-segment-end`
  (evidence.el:141, max `:end_ts`) for focus/browser; content high-water is max
  `:captured_at` (mirrors `dl-satan-sensor-content--count-uninspected`,
  content.el:73, which already returns `(COUNT . HIGH-WATER)`).
- **Read boundary**: `dl-satan-memory-evidence-assemble-with-bounds(start end ctx
  &optional opts)` (evidence.el:589); focus/browser day-files read at :625/:632
  via `--segments-status(path start end limit now)` → `--filter-segments`
  ([START,END] overlap on `:start_ts`/`:end_ts`, evidence.el:322). This is where a
  `(cursor, head]` read **would** plug in IF a positive replay pass were in scope
  (it is not — DR §3).
- **Idiom to mirror**: sensor state files use plain JSON plist read/write to a
  fixed path under `~/.local/state/satan/`. The cursor store follows this idiom in
  its own file. DRY-improvement candidate: 4 near-identical JSON-state read/write
  pairs could share a helper — out of scope here (blast radius).

## 11. Wrap-up Checklist

- [x] Exit criteria satisfied (cursor store + advance + backlog-depth fn;
      perceive never advances — spied; VT-cursor-advance green)
- [x] Verification evidence stored — `just check` 990/999 (+8 VTs vs P01 982/991,
      0 unexpected, 9 pre-existing skips); VTs:
      `dl-satan-ingest-cursor/{advance-writes-head-per-source,advance-idempotent,
      advance-does-not-regress-on-older-row,advance-mixed-offset-focus-uses-parsed-instant,
      advance-missing-cursor-initialises-to-head,backlog-depth-known-cursor,
      backlog-depth-cursor-at-head-is-zero,backlog-depth-missing-cursor-full-count}`;
      VT-perceive-pure spy extended (`-advance`/`--write`)
- [x] Spec/Delta/Plan updated — VT-cursor-advance coverage flipped `verified`
      (B2); IP §9 + gate-check row 4 ticked at delta level
- [x] Waybar wiring assessed (surface-only, user decision): widget would call
      `emacsclient --eval '(dl-satan-ingest-cursor-backlog-depth)'` →
      `(:focus N :browser N :content N :total N)`; config lives in `~/flakes`
      (`~/.config/waybar`); needs `home-manager switch`. Read fn stays in
      `.emacs.d` (POL-001). **Not built this delta** — follow-up if wanted.
- [ ] Hand-off notes (close-out follow-ups: ADR-001 amendment +
      perceptual-design.md §S1 via `/audit-change`; then reconcile/author
      `mem.fact.satan.perceive-consume-seam` + the worker-created
      `mem.pattern.satan.ingest-cursor-backlog-depth`; then `/close-change`)
