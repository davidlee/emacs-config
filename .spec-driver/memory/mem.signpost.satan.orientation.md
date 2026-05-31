---
id: mem.signpost.satan.orientation
name: SATAN agent orientation
memory_type: signpost
status: active
confidence: high
tags: [satan, onboarding]
summary: "Start-here pointers for agents working on the SATAN broker: architecture layers, key docs, DRY gotchas, refactoring conventions"
provenance:
  sources:
    - docs/satan/INDEX.md
    - docs/satan/governance.md
    - docs/satan/refactor/extraction-policy.md
    - POL-001
  verified: "2026-05-31"
scope:
  globs: [satan/**, docs/satan/**]
links:
  out:
    - id: DE-003
  missing:
    - raw: POL-001
---

# SATAN agent orientation

SATAN is the Emacs-hosted AI agent broker. ~16,600 lines of elisp across 56
files in `satan/`, plus 35+ ert test files.

## Start here

1. **Architecture overview**: `docs/satan/INDEX.md` — one-line hooks into every
   doc chunk. Read `governance.md` and `architecture.md` first.
2. **Key docs**: `docs/satan/memory/design.md` (substrate grammar + store),
   `docs/satan/perceptual-design.md` (percept/resonance/sensors/motive),
   `docs/satan/patch/brief.md` (patch agent), `docs/satan/attributes/` (attribute layer).
3. **Policy**: [[POL-001]] — SATAN module extraction policy. Determines what
   stays in the broker and what gets extracted to daemons.

## Architecture layers (file map)

| Layer | Files | Role |
|-------|-------|------|
| Core | `dl-satan.el`, `-broker.el`, `-mode.el`, `-protocol.el`, `-output.el`, `-jsonl.el`, `-audit.el` | Entry point, broker lifecycle, mode registry, wire protocol, output handlers, JSONL, audit log |
| Memory | `dl-satan-memory.el`, `-store.el`, `-grammar.el`, `-canon.el`, `-evidence.el`, `-migrate.el` | Trace storage (psql), grammar, canonicalizer, evidence assembly, migrations |
| Tools | `dl-satan-tools.el`, `-tools-{org,hippocampus,inbox,memory,bough,patch,notes,docs,notify,sway,agenda,activity,vcs,motive,atsatan}.el` | Tool registry + 15 tool modules |
| Perceptual | `dl-satan-percept.el`, `-resonance.el`, `-motive.el`, `-sensor-{alerts,curiosity,wpm}.el` | Percept capsule, auto-resonance, motive file, sensor probes |
| Patch | `dl-satan-patch.el`, `-store.el`, `-worktree.el`, `-runner.el`, `-adapter.el`, `-adapter-pi.el`, `-prompt.el`, `-classify.el`, `-inbox.el`, `-listener.el` | Patch job store (psql), worktree management, runner, adapters |
| Attributes | `dl-satan-attribute.el`, `-listener.el`, `-render.el` | Broker→daemon outcome enqueue, LISTEN consumer, capsule render |
| Observer | `dl-satan-observer.el`, `-classify.el` | Outcome classification of prior interventions |
| Intervention | `dl-satan-intervention.el`, `-mark.el` | Intervention create/classify/lookup API + manual mark |
| Scheduling | `dl-satan-tick.el`, `-budget.el`, `-block.el`, `-tank.el` | Tick modes, token budget, org-block writer, observation tank |
| Context | `dl-satan-context.el` | Bundle assembly (prompt + framing + percept + resonance + motive + sensors + attributes) |

## Key invariants

- **Trust boundary stays in Emacs** (POL-001). Daemons are transports; authority over user-visible surfaces stays in the broker.
- **psql is the only DB interface**. 10 files talk to postgres; all via `call-process` to `psql`. No elisp PG libraries.
- **Tools are registered at load time** via `dl-satan-tool-register`. Mode→tool allowlists are on mode specs.
- **The broker's spawn sequence** (in `dl-satan-broker--spawn`) runs percept build → resonance → motive read → sensor alerts → curiosity/WPM probes → bundle assembly → process spawn. Order matters; it's a flat 185-line `let*`.
- **Code lives in `~/.emacs.d/satan/`; model-facing content lives in `~/notes/satan/`** (prompts, scaffolding, framing, tool descriptions, hippocampus, motives).

## DRY gotchas (as of 2026-05-31)

- **psql `--query` is cloned 4 times** (`memory-store`, `patch-store`, `attribute`, `memory-migrate`). `memory-store` lacks `-q` (welcome-banner suppression). [[DE-003]] will extract `dl-satan-db.el`.
- **`--prep-value` is cloned 3 times** for JSON serialisation prep. The canonical `dl-satan-jsonl-prepare` already exists. [[DE-003]].
- **`slugify` is cloned 3 times**. Canonical home: `dl-satan-memory-canon--slugify`. [[DE-003]].

## Refactoring conventions

- Rust is the target language for SATAN-orbit daemons (POL-001).
- One binary per extraction; shared types in `satan-core` crate.
- Every extraction gets a disable switch (cf. `dl-satan-patch-runner-enabled`).
- See [[POL-001]] for the earns-the-seat test: "does it use the editor as an editor?"
