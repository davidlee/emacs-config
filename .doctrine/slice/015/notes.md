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
fresh-as-of: 2026-10-18 · design/reviewing (RV-016) · e5e3cf3

### Produced
- scope corrections and decisions recorded on the slice (commits 7404061, 51f523c)
- design drafted: 11 sections, 16 design-target selectors, RV-016 opened (e5e3cf3)
- minted: DEC-001..DEC-010, the design decisions; EVD-001, LiteLLM collapsing DeepSeek effort to on/off
- minted: CHR-004, retire the env.zsh LLM exports after satan:SL-022; CHR-005, dead AGENTS.md link
- no code changed; `just check` not run (nothing to check)

### Learned
- EVD-001 — reasoning_effort becomes thinking on/off on the native DeepSeek route

### Open
- RV-016 — section reviews and the review-pass disposition are owed by the user before lock
- DEC-010 — the user issues the `gptel` and `minuet` keys before gate G1
- flakes:SL-014 PHASE-05 — prerequisite for step [B] (design sec-9)
- flakes-side follow-ups (flakes:SL-013's gptel non-goal, the README line on unjailed eca) — to raise in ~/flakes (design sec-11)
