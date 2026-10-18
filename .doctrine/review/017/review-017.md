# Review RV-017 — reconciliation of SL-015

Adversarial-review ledger. Structured findings live in the sister
ledger toml; this prose companion carries the reviewer's framing.

## Brief

<!-- Pre-reading + lines of attack: what this review is probing, the invariants
     it must hold the subject to, and where the bodies are likely buried. Seeded
     at `review new`; the reviewer fills it before raising findings. -->

Mode: **conformance** self-audit, main worktree, head `e4e2c86`. SL-015 was
driven by `/capsule-driver` (no dispatch, no candidate branch). The surface
reviewed is the primary tree's commits c58e527, 83ae69a, fc56d8f, a007f3c and
e4e2c86, plus doctrine bookkeeping. Concurrent writer: satan:SL-022 landed
cf9d419 and ceb3062 in shared files. Those commits are out of scope here,
except where they make SL-015's design stale.

Lines of attack:
1. **Path conformance:** run `slice conformance 15` and disposition each
   undeclared or undelivered path.
2. **Criteria:** `slice verify-vt 015`, `just check` (219/219), and G1/G2 user
   observations in notes `## G1` / `## G2`.
3. **Secret-handling invariants** (design sec-3/4/5):
   - keys are read per call from key files; never in argv, `setenv` or
     `process-environment`;
   - no `op` calls from the new code;
   - `dl-llm-gateway.el` requires neither `dl-secret` nor any client.
   Check gptel's curl path against its source: headers must reach curl via
   `--config -` stdin, not `-H` in argv.
4. **Wire contract:** clients send flat `reasoning_effort` (flakes:SPEC-001
   FR-006, flakes:DEC-074), and model names are exact `<provider>/<id>`.
5. **Canon drift:** where design.md, DEC-005/006 and plan criteria no longer
   describe what shipped, because of the user-directed PHASE-05 change or
   SL-022's removals.
6. **Regressions** from dropping `gptel-openrouter`, the direct backends and
   the eca toggle.

## Synthesis

SL-015 delivered what it set out to: every in-process LLM client in this config
(gptel's deepseek, openrouter and fireworks backends; minuet) now reaches
providers only through the local gateway, each on its own key file. The
direct-key machinery is gone: `my/op-key`, `my/op-key-vault`,
`my/op-read-env`, `dl-gptel-openai-key`, `gptel-openrouter` and unjailed eca.
`my/op-read` stays for org-gcal and now has its own tests.

```
gptel ─┬ deepseek   ┐                      ┌ DeepSeek
       ├ openrouter ├ keys/gptel ─┐        ├ OpenRouter
       └ fireworks  ┘             ├ 127.0.0.1:4000 (LiteLLM) ┤
minuet ─────────────── keys/minuet┘        └ Fireworks
```

Evidence:
- `just check` passes 219/219.
- `verify-vt` passes on every attributable VT; the one exception is PHASE-05
  VT-2, waived by user direction.
- Conformance: 16 paths conformant, 0 undelivered, 2 undeclared (F-3, F-4).
- G1 and G2 were user-observed: the reasoning on/off semantics hold on all
  three providers through the gateway (EVD-002, notes `## G2`).

The secret-handling invariants hold:
- `dl-llm-gateway-key` reads the key file on every call, with no cache and no
  environment write.
- `dl-llm-gateway.el` requires nothing from this config.
- gptel builds curl's argv from config args plus `--config -`, and puts the
  `Authorization` header in the stdin config (gptel-request.el:2813-2828,
  2888-2890), so keys never reach /proc cmdline.

Drift is confined to canon (F-1, F-2), and in both cases the code is right:
- **F-1:** the user moved openrouter to flat `reasoning_effort` under
  flakes:SPEC-001 FR-006.
- **F-2:** satan:SL-022 removed `my/satan-credential` under its own DEC-042.

Standing risks, accepted as follow-ups:
- **F-5 / IMP-028:** vision models no longer get images.
- **F-6 / IMP-026:** gptel backend construction has no ERT test, so the
  `host:port` trap could recur silently.
- flakes:IMP-038 is still due to pin the gateway's flat-effort mapping
  gateway-side; EVD-002 is qualitative.

## Reconciliation Brief

### Per-slice (direct edit)
- **design.md sec-4 "Request shaping"** (F-1): openrouter uses
  `dl-gptel-flat-reasoning-effort`, so all three gateway backends send flat
  `reasoning_effort` (flakes:SPEC-001 FR-006, flakes:DEC-074). Remove the
  "openrouter keeps the nested object" wording.
- **design.md sec-4**, as a note (F-5): the openrouter and fireworks models
  carry no `:capabilities`; IMP-028 tracks this.
- **design.md sec-9** (F-2):
  - drop `my/satan-credential` from the retained list, citing cf9d419 and
    satan:SL-022 DEC-042;
  - drop the `apps/dl-eca.el` VA-1 positive-control expectation;
  - cite `dl-secret.el` and its test by symbol rather than line;
  - record that org-gcal loading was checked by a full-init smoke, since
    `just check` never loads it.
- **Selector registry** (F-3): `doctrine slice selector add 15
  lisp/test/dl-secret-test.el` as a design-target. This is load-bearing for
  conformance; mirror it in the design's target-path list.

### Governance/spec
- **DEC-005** (F-1): supersede it with a new decision. All gateway backends
  (deepseek, openrouter, fireworks) flatten to `reasoning_effort`, and deepseek
  additionally maps low→none. Cite flakes:SPEC-001 FR-006 and the user's
  direction of 2026-10-18. DEC-005 says the decision was the user's
  (2026-10-18), so the superseding decision records the user's 2026-10-18
  direction in this session ("fix DEC-005 at reconcile").

### Not for reconcile
- F-4: tolerated.
- F-5, F-6, F-7: backlog items IMP-028, IMP-026 and CHR-008.
