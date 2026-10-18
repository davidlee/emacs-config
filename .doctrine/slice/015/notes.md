# Notes SL-015: Emacs in-process LLM clients via the LLM gateway

Durable per-slice scratchpad — tracked in git. The place to lift anything from a
disposable phase sheet (`.doctrine/state/.../phase-NN.md`) that must survive
`rm -rf` before the slice close-out audit harvests it.

## Design-stage notes

- Research: `research/research.md` (runtime, gitignored), round 1 plus a
  correction: flakes:SL-014's body guard admits `reasoning` and `thinking`.
  An informal Codex (gpt-6-sol) second opinion is adjudicated in its last
  section; it is not on the review ledger.
- R4 latency, 2026-10-17/18, minuet-shaped request: gateway → DeepSeek has
  0.30–0.45 s to first token, the same as direct DeepSeek. Direct
  OpenRouter has 0.67–1.71 s. Hence DEC-006 and DEC-007.
- Gateway names for OpenRouter's own routers have a double prefix
  (`openrouter/openrouter/auto`): `~/flakes/agents/gateway.nix:22-30`.
- Doctrine gotcha: a `design apply` declare cannot use `needs` to point at
  nodes created in the same payload ("unknown node"). Create the nodes in
  one apply, then add `needs` in a second.
- Review pass (RV-016, 2026-10-18): Codex (gpt-6-sol) adversarial pass,
  then three verify rounds; concluded. No further pass needed: the
  remaining doubts are runtime facts a reviewer cannot settle in a
  read-only sandbox, and the plan already checks them —
  - the `@quick` → `"none"` control (F-2), placed on a phase at `/plan`;
  - G2's `/v1/models` query against the live gateway (Codex could not
    reach local sockets);
  - G1's observation that `@quick` replies carry no reasoning.
  A further pass would probe exactly those, so it would duplicate G1/G2.

## G1 (PHASE-04) — 2026-10-18, user-observed

Prereqs done by the user: `gptel` and `minuet` keys issued, `just home-switch`,
Emacs restarted.

- VH-1 pass: a gptel chat routed to `@deep` completed plain; `@quick` replied
  fast with no reasoning block; `@think` replied with a reasoning block. This is
  also first live evidence that flat `reasoning_effort` maps correctly on
  DeepSeek through the gateway (flakes:DEC-074 lists that as unverified;
  flakes:IMP-038 owns the pinning test).
- VH-2 pass: a minuet completion appeared in a buffer.
- VH-3 pass: `llm-gateway list` shows spend on `gptel` (0.0008 USD) and
  `minuet` (0.0005 USD), both on `deepseek-flash`.
- Side finding, fixed outside the slice in `177c5f4`: macher treated the
  `$HOME` repo as a workspace and scanned every file under `~`.

## G2 (PHASE-05) — 2026-10-18, user-observed

- VH-2 pass: the gateway's `/v1/models`, fetched with the `gptel` key per design
  sec-9, lists exactly the 13 names gptel uses (deepseek-flash, 11 openrouter/,
  1 fireworks/).
- VH-1 pass: `@nemo` (fireworks), `@glm` and `@gem` (openrouter) each completed
  through the gateway with a reasoning trace; `@gem` + `@quick` replied with no
  reasoning. First live evidence of flat `reasoning_effort` on OpenRouter and
  Fireworks via the gateway (flakes:SPEC-001 FR-006; flakes:IMP-038 pins it).

## Harvest
<!-- single-copy: updated in place each harvest; ids only, never restated content -->
fresh-as-of: 2026-10-18 · PHASE-04 · ecdc205

### Produced
- PHASE-01 done — `lisp/dl-llm-gateway.el` key reader + tests; required from init.el (c58e527)
- PHASE-02 done — gptel DeepSeek and `@deep` on the gateway; `dl-gptel-deepseek-thinking` shaper; VT-1 red recorded in the sheet (83ae69a)
- PHASE-03 done — minuet on the gateway; unjailed eca and `dl-eca-toggle-jail` removed (fc56d8f)
- PHASE-04 (G1) passed — VH-1..3 user-observed; see `## G1` (ecdc205)
- adapted: deepseek-flash model entry omits gptel cost fields (gateway records spend); PHASE-02/EX-1 checked by full-init batch smoke, not ert
- off-slice: macher no longer treats the $HOME repo as a workspace (177c5f4)
- minted: IMP-026 — ERT coverage for dl-gptel.el backend construction; CHR-007 — flakes still installs unjailed eca
- earlier: CHR-004 — retire env.zsh LLM exports after satan:SL-022; CHR-005 — dead AGENTS.md link; CHR-006 — drop the magit hi-lock workaround
- `.doctrine/observations/` (3 friction notes from the orchestrator) left untracked, pending the user
- `just check` 219/219 at fc56d8f (last SL-015 code change)

### Learned
- EVD-002 — flat reasoning_effort toggles DeepSeek reasoning through the gateway, live
- EVD-001 — LiteLLM collapses reasoning_effort to DeepSeek thinking on/off
- mem.fact.gptel.host-needs-port — gptel `:host` must carry the port; `url-host` drops it
- mem.fact.gptel.deepseek-not-autoloaded-in-tests — tests must require gptel-openai-extras
- mem.pattern.review.codex-exec-reviewer — Codex CLI as read-only reviewer; no local sockets
- mem.fact.doctrine.design-section-edit — edit run sections via declare body + materialise

### Open
- flakes:DEC-074 — clients send flat reasoning_effort; SL-015 conforms; flakes:IMP-038 pins it gateway-side
- flakes:SL-014 PHASE-05 + widening the gptel key — prerequisites for PHASE-05 ([B])
- flakes-side follow-ups (flakes:SL-013's gptel non-goal, README unjailed-eca line, CHR-007) — to raise in ~/flakes (design sec-11)
