---
name: satan-refactor-extraction-policy
description: Guiding policy for extracting SATAN modules out of elisp — when a module earns the editor seat, what doesn't, and the standing extraction candidates
metadata:
  type: policy
  topic: satan-refactor
  status: living
  updated_at: 2026-05-23
---

# Extraction policy — when SATAN code should leave `.emacs.d/`

Companion to [`plan.md`](plan.md) (active refactor themes) and
[`../governance.md`](../governance.md) (broker is the trusted authority).

This document is **not** a list of imminent work. It is the standing
test the project uses to decide whether a given module belongs inside
the Emacs broker process, and the candidate list that currently fails
that test. Carve early, carve when the next round of work would
otherwise grow the wrong half — not reactively.

## Background

SATAN started as broker-only and has grown to roughly 43k lines of
elisp under `~/.emacs.d/satan/`. Two halves have already been spawned
into their own projects:

- `~/dev/panopticon` — desktop behaviour capture (sensor, read-only
  producer of `~/.local/state/behaviour/`).
- `~/dev/satan-patcher` — Go daemon candidate for the patch-job runner;
  defcustom switch already wired (`dl-satan-patch-runner-enabled`).

Nothing is on fire. The question is whether the remaining elisp mass
contains modules that would be more honestly hosted elsewhere, and
under what test.

## The test

For each module, ask: **does it use the editor as an editor?**

Editor primitives in scope: org-mode parsing/writing, denote naming,
buffer manipulation, dired, `find-file`, `recentf`, interactive
commands (`my/satan-*`), `compile-angel` save hooks, ert as the natural
test surface, broker authority over user-visible surfaces.

If yes → the module earns its seat in `.emacs.d/`. Editor is the
substrate; living in elisp is the right home.

If no → the module is in elisp only because the broker spawned there.
It is an incidental tenant. Eligible for extraction when carving
becomes cheaper than continuing to host it.

This is **not** a performance test. The motivating costs are
maintainability:

1. **Test harness coupling.** Pure modules ship with ert that requires
   `emacs --batch -L …` to run anything. CI cost compounds; refactor
   cost compounds; reviewers must know ert to evaluate a SQL or
   classifier change.
2. **Language fit for JSON/SQL-shaped work.** Documented evidence: the
   `json-serialize` arrays gotcha in [`../governance.md`](../governance.md)
   ("Elisp lists become objects unless coerced to vectors") is a tax
   paid at every JSON boundary. Substrate, audit, and protocol code
   all hand-walk payloads to defend against it.
3. **Crash domain coupling.** Editor freezes are user-hostile in a way
   daemon hangs are not. `dl-satan-tools-agenda.el` already wraps
   gcalcli in `timeout(1)` for exactly this reason. Any blocking
   subprocess inside Emacs is a UX hazard.
4. **Onboarding / review surface.** Contributors must read elisp to
   understand modules that are not in any meaningful sense lisp work
   (queue worker, SQL classifier, JSON verifier). Filters reviewers
   to lispers.
5. **Compile-angel coupling.** Save → byte-compile → reload. Bigger
   pure-logic mass means bigger startup blast radius from typos in
   modules that have nothing to do with editing.

None of these are felt acutely today. They compound silently.

## What earns the seat (do not extract)

| Module(s) | Why it belongs |
|---|---|
| `dl-satan-broker.el`, `dl-satan.el`, `dl-satan-mode.el`, `dl-satan-tools.el` | The broker IS the trust boundary. Extracting the broker dissolves the architecture in [`../governance.md`](../governance.md). |
| `dl-satan-tools-org.el`, `dl-satan-block.el` | Owned-block writer + org parsing — pure editor work. |
| `dl-satan-tools-hippocampus.el`, `dl-satan-tools-inbox.el` | Denote naming, dired UX, `my/satan-*` commands. |
| `dl-satan-tools-atsatan.el`, `dl-satan-tools-notes.el` | Headline parsing, note-tree access through editor conventions. |
| `dl-satan-context.el` | Bundle assembly reads journal/week/inbox org files, applies framing — editor-shaped. |
| `dl-satan-tick.el`, `dl-satan-budget.el`, `dl-satan-output.el` | Schedule + ceiling + dispatch into editor-owned surfaces. |
| `dl-satan-tools-docs.el` | Doc chunk lookup — small, file-shaped, fine in elisp. |
| `dl-satan-tools-{notify,sway,activity,agenda,bough}.el` | Thin shells over external commands; trivial size, naturally bound to broker capability gating. |

## Active beachhead

### `satan-attrd` — attribute layer (first Rust daemon)

Status: **active, first Rust daemon. Greenfield, not a port.** Scaffold
landed 2026-05-23 (initial commit `d8a6a10` in `~/dev/satan-attrd`) —
no schema or store code yet; T-attr-1b is the first code-bearing PR.

Redirects in-flight T-attr-1 implementation work (`T-attr-1b..1e`) out
of the broker and into the new project at `~/dev/satan-attrd`. The
design contract at [`../attributes/design-contract.md`](../attributes/design-contract.md)
was language-neutralised on 2026-05-23 (contract §17 "Implementation
locus + pinned daemon design choices" now in the contract proper, not
just the theme-doc amendment). The contract remains normative on
substance (schema, validators, semantics, caps, rebuild). See
[`T-attr-1-attribute-layer.md`](T-attr-1-attribute-layer.md) §"Implementation locus".

Why the first beachhead is greenfield rather than a port: the
attribute layer is unusually invariant-heavy (8 closed-enum attributes
× per-source reason enums × reserved-but-unimplemented validation ×
cap composition × multi-attribute pre-dispatch snapshot × replay-order
determinism per `(ts, run_id, seq)`). It is the smallest invariant-rich
workload SATAN will ship. Rust pays its scaffolding cost on the most
receptive surface, and establishes the broker↔daemon RPC pattern on
something simpler than the memory substrate (which carries
canonicalizer + grammar versioning + replay-bit-equivalence risk and
is the wrong first daemon).

Scaffolding source: lift bough's `Cargo.toml` deps + PG patterns
(whatever it uses for sqlx/diesel/tokio-postgres + LISTEN/NOTIFY) as
the starting point.

Daemon owns: PG migration `0007_attributes.sql`, store API
(UPSERT + insert-event + counter + lookup), dispatcher (consumes
intervention outcome events, applies delta tables + caps), audit
event emission.

Broker keeps (stays elisp): capsule render glue (capsule is still
assembled broker-side via the existing registry), disable-switch
fast-path check before RPC, any tool handlers exposed to the model
(thin RPC shims).

Open design choices the daemon must pin before T-attr-1c:

- **Audit transcript path.** `attribute.delta_applied` lives in
  `transcript.jsonl` per the audit-truth convention. Options: (a)
  daemon writes `satan_attribute_events` row, RPCs event back to
  broker which writes transcript line — preserves "transcript is
  audit truth"; (b) daemon writes table only — diverges from
  convention but simpler. Recommendation: (a).
- **Event bus shape.** Dispatcher consumes
  `intervention.outcome_classified` / `outcome_revised`. Recommended:
  broker emits via PG queue table + `pg_notify` (matches existing
  patch-listener pattern). Alternative: direct broker→daemon RPC on
  each emit (simpler, tighter coupling).
- **Disable-switch placement.** Broker-side check before RPC means
  daemon never sees disabled events. Daemon-side check means audit
  records "would have applied X but disabled" — cleaner for the
  rebuild semantics in contract §10. Recommendation: daemon-side.

This is the first invocation of the extraction trigger "candidate's
surface area is about to grow materially in the next refactor theme."
Greenfield extraction here is cheaper than land-then-port; doing it
in Rust now means the eventual memory-substrate absorption is
"extend daemon" rather than "create + port."

## What does not earn the seat (extraction candidates)

Listed in roughly the order extraction would pay off, not in any
committed sequence. These are deferred — not active. The active
beachhead above is the first daemon; these follow if/when their
triggers fire.

### 1. Patch runner → `satan-patcher`

Status: **pivot-pending, already in flight.** `~/dev/satan-patcher/`
exists (Go, ~5k LoC); `dl-satan-patch-runner-enabled` defcustom can
hand the queue off. Tracked separately in
[`../governance.md`](../governance.md) Open Thread 12 and
`../patch/handover.md`.

Language note: the existing Go implementation is incidental — an
agent jumped to implementation without surfacing Rust vs Go. Rewrite
trigger is "starts to grow past evening-rebuildable" or "feature
friction surfaces real workload-fit pain", not "feels wrong." At
current size a Rust rewrite for consistency is an evening's work but
not on the roadmap. Reconsider when growth forces it; until then
treat the existing Go as the deployed reality.

Modules in scope: `dl-satan-patch-{store,listener,runner,worktree,adapter,adapter-pi,prompt,classify,inbox}.el` (the tools surface
`dl-satan-tools-patch.el` is RPC into the runner and stays elisp).

Fit failure: queue worker, worktree allocator, subprocess driver. No
editor primitive used. Already conceptually a daemon — listener exists
to avoid polling.

### 2. Memory substrate → `satan-memoryd`

Status: **candidate.** Biggest editor-mismatch in the codebase.

Modules in scope: `dl-satan-memory-{canon,store,migrate,grammar,evidence}.el`. Elisp keeps the tool handlers
(`dl-satan-tools-memory.el`) as thin RPC shims; daemon owns connection
pool + canonicalizer + migration runner.

Fit failure: SQL access (psql subprocess per call), JSON shaping,
pure deterministic transforms. The canonicalizer is the cleanest pure
function in the codebase yet requires ert + Emacs to test. The
`json-serialize` arrays gotcha is paid here repeatedly.

Care: canonicalizer is deterministic and grammar-versioned. Port must
preserve byte-for-byte equivalence on the test corpus; existing ert
becomes a port acceptance fixture rather than ongoing test surface.

### 3. Audit verifier → `satan-audit` CLI

Status: **candidate.** Mechanical port; independently useful.

Modules in scope: `dl-satan-audit.el` (verifier half — the append-only
writer half stays in the broker because it writes during a live run).

Fit failure: post-hoc verification over JSON files. Should be runnable
from CI, from cron, from a post-mortem shell without booting an
emacs-server. Today's only invocation path is
`emacsclient --eval '(dl-satan-audit-verify-run …)'`.

Care: the 6 predicates are the spec; preserve them verbatim. Add a
golden-fixture test set covering each predicate's pass/fail cases
before the port to lock semantics.

### 4. Observer → folds into §2 or stands alone

Status: **candidate, dependent.** Most coherent extracted alongside §2
(shares substrate + JSON shape). Standalone extraction is also viable
if §2 stays.

Modules in scope: `dl-satan-observer.el`, `dl-satan-observer-classify.el`.

Fit failure: file scan over 24h of `transcript.jsonl`, deterministic
predicate classifier, dedup state file. No editor primitive used.

Care: the verdict-write path touches motive footer (`dl-satan-motive-touch-footer`) and
memory store. If extracted, the daemon must either own those writes
(blurs the broker trust boundary — bad) or RPC the verdict back to the
broker for application (clean — but adds a hop). Default to RPC-back.

## Anti-candidates (explicit do-not-touch)

Patterns that look extractable but are not, recorded so the question
doesn't get re-asked:

1. **`dl-satan-tools-bough.el`.** The real fix is `bough serve`
   inside the bough project, not adapter changes here.
2. **Sensor-alerts / cooldown / quiet-hours state.** Tiny single-file
   JSON, no SQL, fits elisp.
3. **Mode / tool / capability dispatch.** Trust boundary. Extracting
   destroys the architecture. See [`../governance.md`](../governance.md)
   §"Permission governance".
4. **Memory canonicalizer alone (without store + evidence).** Pure
   elisp is cheap to keep IF the store moves too. Half-extraction
   creates a worse split than no extraction.
5. **Doc chunk indexer.** Substring scan over ~50 files. Worth
   nothing to extract until ~500 chunks or an embedding index is
   needed.
6. **Hippocampus indexer.** Currently no re-read path. Build the
   indexer only when a tool actually wants semantic recall over
   `hippocampus/`; do not pre-extract.

## When to act on a candidate

Trigger a candidate's extraction when **one** of the following
applies, not before:

- The candidate's surface area is about to grow materially in the next
  refactor theme (carving before growth is cheaper than after).
- A recurring bug in the candidate traces to language/runtime fit
  (JSON walking, subprocess hang, ert-only test reach, …).
- A contributor or reviewer is being asked to read elisp to evaluate
  non-elisp work.
- Tests for the candidate begin to dominate `emacs --batch` CI cost.

Absent any trigger, leave it. The policy exists so that when a trigger
arrives, the carve has already been argued and the answer is known.

## Standing principles

- **Carve early, not reactively.** The whole point of this document is
  to know the cut lines before pain forces them.
- **Rust is the target language for SATAN-orbit daemons.** Workload
  fit (PG + LISTEN/NOTIFY + RPC + invariant-heavy dispatchers + replay
  determinism) matches Rust's type system and `sqlx` compile-time
  query checking. bough is the existing in-orbit Rust precedent and
  its scaffolding (Cargo.toml deps, PG patterns) is the cheapest
  starting point for any new daemon. `satan-patcher` being Go is
  incidental — an agent jumped to implementation without surfacing
  the language choice; rewrite trigger is "starts to grow", not
  "feels wrong." panopticon being Python is workload fit (sensor
  glue) and stands.
- **Trust boundary stays in Emacs.** Daemons are dumb transports +
  pure transforms. Authority over user-visible surfaces lives in the
  broker.
- **One project per extraction.** Resist consolidating §2 + §3 + §4
  into a single `satan-daemon` just because they could share a Rust
  workspace — independent extractions stay independently
  disable-able.
- **Preserve test corpora across the port.** Existing ert becomes
  acceptance fixtures; the new daemon must pass them before the
  switch flips.
- **Disable switch on every extraction.** Match the pattern set by
  `dl-satan-patch-runner-enabled`. Rollback is cheap when wired in
  from day one.
