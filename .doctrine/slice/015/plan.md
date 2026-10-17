# Implementation Plan SL-015: Emacs in-process LLM clients via the LLM gateway

Prose companion to `plan.toml`. Narrative only — no queried data lives here
(the storage rule); the phase list, criteria, verification, and links are
authored in the TOML. Use this for the plan's rationale and sequencing.
<!-- Reference forms: `lib:reference/glossary.md` § reference forms. -->

## Overview

Six phases follow the design's two steps (design sec-9): step [A] works
against today's gateway, which serves only `deepseek-flash`; step [B] waits
for flakes:SL-014 PHASE-05 to put OpenRouter and Fireworks live.

```
[A]  PHASE-01 module ──┬── PHASE-02 gptel deepseek ──┐
                       └── PHASE-03 minuet, eca ─────┴── PHASE-04 G1 (VH)
                                                              │
     flakes:SL-014 PHASE-05 ─────────────────────────────────┤
[B]                                       PHASE-05 gptel openrouter/fireworks + G2
                                                              │
                                          PHASE-06 op-key removal, docs
```

## Sequencing & Rationale

- **PHASE-01 first.** Every client depends on `dl-llm-gateway-key`; it is
  small, pure apart from one file read, and fully testable without a
  gateway.
- **PHASE-02 and PHASE-03 are file-disjoint.** gptel (`dl-gptel*.el`,
  presets test) and minuet/eca (`dl-minuet.el`, `dl-eca*.el`) share only
  PHASE-01's module and CHANGELOG.md. They run in either order; serial is
  the default.
- **PHASE-02 carries the RV-016 F-2 control.** Its VT-1 must be seen red
  against plain flattening before `dl-gptel-deepseek-thinking` lands; that
  is what shows the test discriminates the fault the review found.
- **PHASE-04 is a gate, not a build.** Real keys and a live gateway are the
  only way to observe the request path, reasoning on and off, and the
  ledger. The user issues the keys first (DEC-010). A failure re-enters the
  phase that owns the defect.
- **PHASE-05 waits on flakes.** Its entrance is flakes:SL-014 PHASE-05
  plus the widened `gptel` key. It moves the remaining backends and their
  presets together, so no preset ever points at a half-moved backend, and
  closes with G2.
- **PHASE-06 last.** `my/op-key` can go only once no backend calls it; the
  docs describe the final state once, not an intermediate one.

## Notes

- `llm-gateway issue` and `llm-gateway models` run as the gateway service
  user (sudo): they are the user's acts at PHASE-04 and PHASE-05 entrance.
- CHANGELOG entries land with each user-facing phase (02, 03, 05, 06),
  naming the presets, commands and keys the coach tracks (AGENTS.md).
- Each phase ends green under `just check`, with
  `bin/elisp-locate-paren-error` ok on every touched `.el`.
