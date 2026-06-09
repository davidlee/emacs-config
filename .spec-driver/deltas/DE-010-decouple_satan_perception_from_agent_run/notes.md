# Notes for DE-010 — handover

Design provenance: a session discussion (2026-06-08) that started as "is the
tick model silly?" and converged on the perception/cognition split. These notes
capture the commentary that shaped the decision but didn't all fit the delta
body. Read alongside the delta, [[ADR-001]] (accepted, the ratified split),
[[ADR-002]] (proposed, the arrival gate), and [[IMPR-012]] (gate design notes).

## Artefact map (where each decision lives)

| Concern | Artefact | State |
|---|---|---|
| Decouple perception from cognition | ADR-001 | accepted |
| D1 — perception as pure function, lazy-materialize | ADR-001 + DE-010 §7 | resolved |
| D2 — consumer: replayer vs hybrid | DE-010 §7 | **open** |
| Arrival gate (metabolic, stochastic) | ADR-002 / IMPR-012 | proposed / idea |
| Segment-schema substrate | ISSUE-006 (portable panopticon) | dependency |

## 1. The core realisation — this is an extraction, not a build

`dl-satan-broker--prepare` already does the deterministic work: it freezes one
`time_now`, builds the evidence window, runs the canon, persists `percept.json`,
runs auto-resonance + motive read — and **then** spawns the model as its last
step (`docs/satan/perceptual-design.md` §S1). The spawn is the seam. We are
*cutting* there, not writing a new perception pipeline. CLAUDE.md "no parallel
implementation" applies hard: there must remain **exactly one** percept builder.
Panopticon already does the time-series/histogram aggregation below the broker —
the parcel is "segments since watermark", not new sensing.

## 2. The deepest design insight — time-locality dies in the decoupling

This is the bit most worth preserving and the thing the delta body under-states.

Today a percept is **present-tense** ("last 10 min", sampled at tick time). The
moment you decouple and let the consumer run slack/irregular, a percept built at
10:00 and consumed at 14:00 is **archaeology, not perception**. The agent stops
being "present-aware" and becomes a "log-replayer". That is a genuine *semantic*
shift, not just a scheduling change — and it is acceptable (much of SATAN's
value is retrospective) **only if** we split interventions by latency-tolerance.

### Intervention latency classes (maps to `protocol.md` intervention `kind` enum)

| kind | latency-sensitive? | deferrable in a replayer? |
|---|---|---|
| `notify`, `visible_sign` (e.g. `sway_border_set`) | **yes** | **no** — worthless stale; "you look stuck" at +4h is noise |
| `inbox`, `proposal`, `patch_job` | no | yes — batch-safe |
| memory marks / outcome accrual | no | yes — order-independent |
| `accuse`, `ask`, `delay`, `quarantine`, `surface` | mixed | case-by-case |

**Consequence:** the slow consumer must **not own the alarm bell.** Latency-
sensitive kinds need a near-real-time path; latency-tolerant kinds drain from the
backlog. This is exactly what D2 (below) decides, and why the arrival gate
(ADR-002) keeps a *fast* episode-scoped reflex distinct from the *slow* global
metabolism.

## 3. Two retention semantics — not one queue

"All segments since watermark" + "recency-biased replay" hides **two** consumers
of the backlog with different ordering AND retention. Modelling them as one LIFO
queue either spams stale interventions or loses memory coverage.

- **Intervention relevance** — newest-first, **plus a freshness horizon**: past
  some age a parcel is no longer intervention-eligible.
- **Memory / outcome accrual** — wants *all* parcels, order-independent,
  complete; must not drop the old ones.

Model: **one ingest cursor** (how far memory has consumed) + **a per-parcel
"intervention-eligible-until" stamp**. Parcels stay immutable/append-only;
consumption state lives in the cursor/stamp, never by mutating the parcel
(matches architecture.md "State: append-only artifacts").

## 4. Idempotency — key on segment offset, not wall-clock

systemd timers fire late and can overlap a slow run. If parcel boundaries derive
from "segments since cursor N" rather than "now − 10 min", a missed/doubled tick
just re-derives the same boundary → idempotent for free. **Do not window on
wall-clock.** (Under D1=B there is no perception timer at all in this delta, but
the same offset-keying protects the consumer's ingest cursor.)

## 5. D2 — RESOLVED hybrid (2026-06-09)

- **Pure replayer.** Clean, fully decoupled, deterministic. But loses all
  real-time reflex → then you *must* build a separate cheap reflex path (could be
  deterministic, no LLM) for the latency-sensitive kinds in §2.
- **Hybrid (lean).** Decoupled perception + a thin, cheap, frequent touch for
  latency-sensitive cues; heavy reasoning drains the backlog at slack cadence.

Under D1=B (perception is a function, no perception timer), the **only** periodic
clock left in the system is the gate — which is exactly where a thin cheap
latency-touch lives. **Decision (2026-06-09): hybrid.** The gate both decides
discretionary arrival *and* carries the cheap reflex — one mechanism, not two.
The pure-replayer alternative would force a separate reflex path for the same
job. This also satisfies **ADR-002 acceptance gate #2**. DR-010 / IP can now
proceed on this shape.

Latency floor either way: worst-case intervention ≈ perception-eval + gate +
spawn ≈ ~10–12 min. SATAN was never sub-minute; **document the floor, accept it.**

## 6. Future lever (not in scope, capture so it isn't re-derived)

If ~10-min latency ever proves too slack: panopticon already segmentizes, so a
**segment-close event** could *event-trigger* the gate instead of polling —
tightening reflex latency without a faster poll. Deliberately deferred; simple
poll first.

## 7. D1a residual (from the lazy-materialize decision)

Lazy materialization drops the per-tick "what did SATAN see at 10:00" audit
artifact. Memory/outcome accrual is unaffected (reads the durable segment log via
the ingest cursor). If an explicit *perception-of-record* is ever wanted, add an
**optional slow archival materialization** decoupled from consume. Deferred
unless a need appears.

## 8. What "done" looks like (draft acceptance, from delta §6)

- A budget-denied tick still produces perception (ISSUE-001 regression).
- A doubled/late invocation yields no duplicate/corrupt parcel (offset-keying).
- Consumer drains the backlog and advances the cursor without mutating parcels.

## Open threads for the next agent

D1 + D2 both resolved → architectural shape is locked (perception = pure
function, lazy-materialize; consumer = hybrid, gate carries the cheap reflex).

1. **Flesh DR-010** — current-vs-target now that the shape is locked.
2. Decide spec authority: the perception loop is doc-canon, not a SPEC. Does
   authority move into a SPEC as part of this delta, or stay in
   `docs/satan/perceptual-design.md`?
3. Then `plan-phases` for an IP.
4. (Separately) ADR-002's other two gates — self-manipulation analysis +
   doctrine amendment — remain before the arrival gate can be accepted.

DR-010 accepted, IP-010 + phase-01 authored. Items 1–3 above are DONE.

---

# New Agent Instructions (2026-06-09 — drive IP-010 Phase 1 via /dispatch)

**Task card:** `.spec-driver/deltas/DE-010-decouple_satan_perception_from_agent_run/`
DE-010 in-progress · DR-010 accepted · IP-010 planned · **phase-01 in-progress**.

**Your job:** execute IP-010 Phase 1 (perceive/consume seam) with **/dispatch in
serial** (user instruction — do NOT implement inline, do NOT parallelize; the
seam at 1.1/1.2 is serial-dependent). Route via `/using-spec-driver` first, then
`/dispatch` on DE-010. Preflight is already done (this handoff) — you do not need
to re-run it; verify the assumptions hold if you touch a file, but do not
re-explore from scratch.

## Required reading (in order)
- `phases/phase-01.md` — tasks 1.1–1.6, exit criteria, **§10 Findings** (verified
  assumptions, probe shapes, audit-verifier constraints, caller census, session-
  blocked decision). READ §10 — it is the distilled preflight.
- `DR-010.md` §3 (target control flow, perceive/consume boundary table, side-
  effect def, snapshot-shape note), §4 (code-impact table), §7 (DEC-perceive-
  boundary, DEC-probes-read-commit-split, DEC-budget-denied-mirror-percept).
- `docs/satan/perceptual-design.md` §S1 (broker pre-spawn sequence).

## Locked design decisions (do not re-litigate)
- **session-blocked terminal handling (user, 2026-06-09):** unify all three
  no-child paths through a shared `dl-satan-broker--write-no-child-run STATUS
  REASON …` helper. session-blocked → status **`failed`**, reason
  **`session_blocked`**, writes audit bundle + percept.json + bundle.json:percept
  (verify-clean), **NO `.FAILED` rename, NO failure notification** (intentional
  DEC-8 deferral, not a failure — must not pollute the failure-streak counter or
  pop desktop alerts). **budget-denied keeps** status `budget-exceeded` + .FAILED
  + announce (unchanged). **perceive-failed** → status `failed` reason
  `perceive_failed` + .FAILED + announce.
- **Keep `assemble-context = enrich∘perceive`** (composition, not a parallel
  builder) and **`-probe = commit∘read`** wrappers — preserves DRY, the single
  percept builder invariant, byte-stability, and existing test stubs.
- **curiosity probe carries a latent bug DR §3 mandates fixing:** today it
  advances its watermark to wall-clock `ts` (out-of-order `end_ts` rows skipped).
  The read/commit split must make `--count-uninspected` return `(count .
  high-water-end_ts)` (mirror content's shape) and commit must advance to that
  high-water, NOT `ts`. content already does this (DEC-5); wpm snapshot = state+prev.

## Build order (dependency order — NOT the sheet's 1.1→1.6 numbering)
1. **1.3** split `dl-satan-run-assemble-context` (context.el:25) →
   `dl-satan-run-perceive` (percept-build + persist + evidence + sensor_status)
   and `dl-satan-run-enrich` (resonance + motive; reads `:percept` from prepare);
   keep `assemble-context` as the `enrich∘perceive` composition.
2. **1.1 + 1.2** rewrite `dl-satan-broker-run` (broker.el:658): mkdir run-dir →
   `perceive` UNCONDITIONALLY before the session/budget gates (ISSUE-001 fix);
   factor `--write-no-child-run` (replaces `--write-budget-denied-run` body,
   broker.el:622) per the locked decision; mirror `:percept` into all denial
   bundles. `--spawn` (consume, broker.el:695) drops percept-build, calls
   `enrich` instead of assemble-context at :755; probes stay in consume for now.
   **Update the dec8 test stubs (broker-test.el:731)** — it stubs assemble-context
   + `-probe`; restub for enrich + new read/commit fns.
3. **1.4** probe read/commit split across `dl-satan-sensor-{curiosity,content,
   wpm}.el`: perceive does pure read-snapshots → frozen onto prepare; consume
   commits (charge + advance watermark to snapshot high-water). Apply the
   curiosity bugfix above.
4. **1.5** confirm `context-interactive` (context.el:577) byte-stable — it calls
   assemble-context (= enrich∘perceive), so it should be unchanged; pin with
   VT-mcp-bundle.
5. **1.6** author VTs (VT-budget-denied-perceives, VT-perceive-pure,
   VT-probe-split; regressions VT-percept-golden, VT-mcp-bundle); `just check`.

## Key files
- `satan/dl-satan-broker.el` — `broker-run` (658), `--spawn` (695),
  `--write-budget-denied-run` (622), `--announce-failure` (531), `--prepare` (128).
- `satan/dl-satan-context.el` — `assemble-context` (25), `context-interactive` (577).
- `satan/dl-satan-percept.el` — `percept-build` (45), `percept-persist` (102).
- `satan/dl-satan-sensor-{curiosity,content,wpm}.el` — probes (99/95/128).
- `satan/dl-satan-audit.el` — `audit-open` (49, writes bundle.json),
  `verify-run` (694), `status-terminal` (685).
- Tests: `satan/test/dl-satan-broker-test.el` (budget test 426, dec8 731),
  `dl-satan-context-test.el`, `dl-satan-sensor-content-test.el`, `dl-satan-percept-test.el`.

## Relevant memory
- `mem.signpost.satan.orientation` — SATAN architecture/file map (verified
  2026-05-31, scope `satan/**`; treat as advisory, commits since).

## Doctrine / guardrails
- **Elisp gate (AGENTS.md):** after EVERY `.el` edit run
  `bin/elisp-locate-paren-error FILE` until `{"ok":true}` BEFORE byte-compile/tests.
- POL-001 — perception stays in `.emacs.d` (editor-substrate sensing).
- "no parallel implementation" — exactly ONE percept builder must remain.
- Commit policy: frequent small `.spec-driver/**` commits; code + spec-driver may
  commit together or separately, whichever keeps the worktree clean first.

## Commit state / loose ends
- Phase sheet (status in-progress + §10 findings) **already committed** (1edcd30).
- **No code written yet** — clean worktree for code (modulo pre-existing untracked
  `.cache/ .direnv/ .envrc result` and `M .agents/spec-driver-boot.md`, unrelated).
- Task list (#1–#6) was created for an inline plan; /dispatch will own its own
  task tracking — ignore or reset.
