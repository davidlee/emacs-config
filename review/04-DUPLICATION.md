# 04-DUPLICATION.md — Duplication & near-duplication

## Repeated pattern: mode/capability/tool allowlist specification

The governance doc defines mode allowlists declaratively. The broker uses `dl-satan-mode.el`'s mode-spec `:tools` list to gate tool calls. However, several files replicate mode-to-tool mapping logic:

**`dl-satan-tools-atsatan.el`** registers tick-agent with tool allowlist additions (`patch_job_create`, `patch_job_status`) via `dl-satan-tick-register` at load time. This duplicates the mode-spec tool list that `dl-satan-mode.el` already maintains for `self-edit-{mech,mind}`.

**`dl-satan-mode.el`** defines all mode specs. **`dl-satan-tools-atsatan.el`** adds tools to the tick-agent mode at load time via `dl-satan-tick-register`. The governance doc (§2.6) warns: "Tool-spec `:modes` is documentary only; the broker does not consult it."

confidence: medium — the `:tools` allowlist lives in mode specs (`dl-satan-mode.el`), but tools-atsatan.el adds tools dynamically at register-time. Two sources of truth.

## Repeated pattern: evidence-assembly imports across perceptual layer

Files importing from the memory substrate (grammar, canon, evidence, store):

- `dl-satan-percept.el`: requires `dl-satan-memory-canon`, `dl-satan-memory-evidence`, `dl-satan-memory-grammar`
- `dl-satan-observer.el`: requires all four (`dl-satan-memory-canon`, `dl-satan-memory-evidence`, `dl-satan-memory-grammar`, `dl-satan-memory-store`)
- `dl-satan-tools-hippocampus.el`: requires all four
- `dl-satan-tools-memory.el`: requires all four

These are legitimate consumers — each provides a different surface over the substrate. Not flagged as duplication.

**Positive finding**: `dl-satan-tank.el` requires `dl-satan-memory-evidence`, `dl-satan-memory-store`, `dl-satan-memory-grammar`, and `dl-satan-broker` — this is a wide import set spanning both memory substrate and broker.

confidence: medium

## Repeated literal strings: capability names

The capability string `"notify"` appears in 9 tool files:

- `dl-satan-tools-activity.el`
- `dl-satan-tools-agenda.el`  
- `dl-satan-tools-bough.el`
- `dl-satan-tools-docs.el`
- `dl-satan-tools-hippocampus.el`
- `dl-satan-tools-inbox.el`
- `dl-satan-tools-notes.el`
- `dl-satan-tools-org.el`
- `dl-satan-tools-sway.el`

Wait — `"notify"` is the risk level in tool specs, appearing in `(:risk "notify")` in tool registrations. This is the standard pattern; not duplication.

More relevant: `"read-only"` risk level or `"notify"` as a capability name vs risk string.

Let me check: capability strings like `"hippocampus-write"`, `"inbox-write"`, `"memory-write"`, `"patch-job-create"` appear in both:
- Tool specs (risk/capability plists in `dl-satan-tools*.el`)
- Mode specs (`:capabilities` in `dl-satan-mode.el`)

The capability system is designed for this (governance §Permission governance) — these are references, not duplication.

confidence: low — intentional coordination, not accidental duplication.

## Magic numbers: budget/token/timeout constants

Several files define numeric budgets:

| File | Constant | Default |
|---|---|---|
| `dl-satan-budget.el` | `dl-satan-budget-daily-tokens` | 400000 (now 2M per CHANGELOG) |
| `dl-satan-mode.el` | Per-mode `:budget-tokens` | 20000/10000/3000/50000 |
| `dl-satan-tick.el` | `dl-satan-tick-register` defaults | 3000 tokens, 4 calls, 30s |
| specific modes | Per-mode overrides | Various |

These are intentional per-mode tunables, not magic numbers.

## Duplicate function bodies

Potential near-duplicate pairs to investigate:

1. `dl-satan-patch-worktree-create` (70 LOC) and `dl-satan-patch-store--parse-row` (238 LOC) — both parse worktree/branch paths. The worktree create function constructs paths; parse-row reads DB rows. Likely distinct but warrants a quick glance.

2. `dl-satan-observer.el` and `dl-satan-percept.el` both import memory-canon + memory-evidence + memory-grammar + audit, and both assemble data structures from the substrate and audit trail. Observer (`dl-satan-observer-classify` at L474, 51 LOC) and percept percept-build share some structural DNA.

confidence: low — speculative; no actual body-level matching performed.

## Repeated env-var forwarding

`dl-satan-broker.el` and `dl-satan-patch-adapter-pi.el` both forward `SATAN_RUN_ID`, `SATAN_PROVIDER`, `SATAN_MODEL`, `SATAN_BUDGET_TOKENS` into child process environments. This is intentional (broker for model harness, adapter-pi for coding agent) but the env-var list should be checked for drift. Both use the same set currently (verified in 02-DEPENDENCIES analysis).

confidence: high — matched across both sides.
