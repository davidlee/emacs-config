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

## Harvest
<!-- single-copy: updated in place each harvest; ids only, never restated content -->
fresh-as-of: 2026-10-18 · ready (PHASE-01 next) · 33a83a7

### Produced
- design locked after RV-016 (Codex pass + verify rounds) (f05c063)
- plan: PHASE-01..06, sheets materialised; slice ready (5e68053, 21214a7, 265d4e2)
- revised: DEC-005 — deepseek shaper maps effort low to none; DEC-006 — presets as backend + gateway model
- off-plan fix: invalid OpenRouter id dropped from gptel; magit hi-lock workaround in dl-magit.el (33a83a7)
- minted: CHR-006 — drop the magit hi-lock workaround when magit fixes it
- earlier: CHR-004 — retire env.zsh LLM exports after satan:SL-022; CHR-005 — dead AGENTS.md link
- no SL-015 code yet; `just check` green at 33a83a7

### Learned
- EVD-001 — reasoning_effort becomes thinking on/off on the native DeepSeek route
- mem.pattern.review.codex-exec-reviewer — Codex CLI as read-only reviewer; no local sockets
- mem.fact.doctrine.design-section-edit — edit run sections via declare body + materialise

### Open
- DEC-010 — the user issues the gptel and minuet keys before PHASE-04 (G1)
- flakes:SL-014 PHASE-05 — prerequisite for PHASE-05 ([B])
- flakes-side follow-ups (flakes:SL-013's gptel non-goal, README unjailed-eca line) — to raise in ~/flakes (design sec-11)
