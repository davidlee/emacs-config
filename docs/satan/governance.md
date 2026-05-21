---
name: satan-governance
description: SATAN governance + reference — philosophy, policy, file map, modes, tools, ops, gotchas
metadata:
  type: governance
  topic: satan
  status: canon
  updated_at: 03398479
  verified_at: 03398479
---

# SATAN — Scheduled Agent for Textual Attention and Notes

Living document. Covers both governing architecture and current
operational state. Update on every meaningful change.

Companion: `CHANGELOG.md` (dated, narrative log of what landed).

## One-sentence summary

SATAN is a local, Emacs-mediated, org-backed, harness-agnostic agent
runtime whose model-facing mind lives in `~/notes/satan`, whose
authority is constrained by a broker-enforced tool membrane, and whose
evolution should remain text-first, auditable, proposal-driven, and
deliberately narrow.

## Purpose

SATAN is a local, text-first agent runtime for personal orchestration.
Not a chatbot, not a general-purpose automation daemon, not an
autonomous shell with a personality. A constrained local system that
periodically reads selected personal context, reasons over it through a
model/harness, and produces bounded, inspectable effects through a
trusted broker.

SATAN exists to help maintain alignment between stated intentions,
daily behaviour, notes and memories, projects and obligations,
recurring patterns, and local tools/workflows.

Design priority: **safe, inspectable, evolvable agency** — not maximum
agency.

## Core thesis

SATAN's identity is not any particular model, harness, editor, or CLI.
It is defined by its durable local "DNA":

```text
ROM prompt
+ self-authored memory
+ permission model
+ jail/runtime constraints
+ tool/action protocol
+ invocation schedule
+ audit trail
```

Models are interchangeable. Harnesses are interchangeable. The broker
may evolve. The identity and governance rules should remain coherent
across those changes.

## Status

| Phase | Status | Notes |
|---|---|---|
| 1 — broker + JSONL + fake harness | ✅ | landed 2026-05-19 |
| 2A — real LLM harness (OpenRouter) | ✅ | landed 2026-05-19, smoke-tested live |
| 2B — `notify_send` tool | ✅ | landed 2026-05-19 |
| 2C — `hippocampus_write` tool | ✅ | landed 2026-05-19, raw `find-file` review; renamed from `memory.add_candidate` |
| 2D — `self-edit` mode | ✅ | landed 2026-05-19, SATAN-only scope |
| 2E — mind/mechanism split | ✅ | landed 2026-05-19, prompts + tool descs in `~/notes/satan/` |
| Wired into Sleipnir (`satan.nix`) | ✅ | timers `satan-morning` 09:00, `satan-motd` 07:00 |
| 3A — protocol reification | ✅ | landed 2026-05-19; `protocol.md` + fixtures + validators on both sides |

`M-x my/satan-run RET morning` writes a SATAN-owned block into today's
daily note and a full audit bundle under `~/notes/satan/runs/<run-id>/`.
`motd` writes `~/notes/satan/motd.txt`. `self-edit` stages proposals
under `~/notes/satan/proposals/` — nothing auto-applies.

Tests: 68/68 unit ert + 16/16 python unittest + 1/1 integration ert.

## Quickstart

```sh
# Manual invocation (the morning timer also does this).
M-x my/satan-run RET morning
M-x my/satan-run RET motd
M-x my/satan-run RET self-edit          # SATAN audits its own source

# Review staged artifacts.
M-x my/satan-hippocampus                 # dired ~/notes/satan/hippocampus
find ~/notes/satan/proposals             # denote-named proposals

# Audit a finished run.
emacsclient --eval '(dl-satan-audit-verify-run "/home/david/notes/satan/runs/<RUN-ID>/")'
```

The wrapper script `~/.emacs.d/satan/bin/satan-run <mode>` invokes
`emacsclient --eval` and is what the systemd units call.

## Architecture

Trust-and-data flow, broker/harness/model/tool/output/state layers:
[[satan-architecture]].

## Ownership: mind vs mechanism

**Invariant.** All model-facing behavioural text lives under
`~/notes/satan`. Dotfiles may define mechanisms, validators, handlers,
and capability checks, but must not be the canonical source for
prompts, tool descriptions, behavioural instructions, examples, or
model-facing policy.

```text
Dotfiles contain mechanism.
~/notes/satan contains mind.
```

| Concern | Owner |
|---|---|
| ROM/system prompt, mode prompts | `~/notes/satan/prompts/<mode>.txt` |
| shared system scaffold | `~/notes/satan/system/scaffold.txt` |
| bundle-section headers (`# Now`, `# Today (raw)`, `# Source files`) | `~/notes/satan/system/framing.txt` |
| per-tool description (model-facing) | `~/notes/satan/tools/<tool-name>.md` |
| `satan_final` description (synthetic terminal tool) | `~/notes/satan/tools/satan_final.md` |
| examples / few-shot snippets, style instructions, hippocampus policy | `~/notes/satan/` |
| hippocampus entries, staged proposals | `~/notes/satan/{hippocampus,proposals}/` |
| tool name / risk / schema / capability / handler | elisp tool-spec (`dl-satan-tools-*.el`) |
| mode allowlist / harness / jail / timeouts / budgets | elisp mode-spec (`dl-satan-mode.el`) |
| JSONL protocol, validation, dispatch, audit, jailing | elisp (`dl-satan-*.el`) |

The broker assembles `manifest.json` by joining the two halves: each
allowed tool's full OpenAI-tools JSON Schema is built from the elisp
schema (mechanism) plus the notes-owned description (mind). The harness
consumes `manifest["tools"]` verbatim — it holds no canonical
descriptions of its own. Missing notes-side files signal at run-start
rather than degrading silently.

Rule of thumb: if changing the text could change what the model
chooses to do, it belongs in `~/notes/satan`.

## Source of truth

- **Canonical personal substrate**: org/denote notes. SATAN may read
  broadly through selected context assemblers, but writes only to
  explicit owned regions or staged artifacts.
- **Derived operational layer**: `bough` may cache, index, relate,
  enrich, or project org/denote state. Treat as reconstructable unless
  explicitly promoted. Operationally useful, not canonical.
- **SATAN-owned state**: lives under `~/notes/satan` — hippocampus,
  proposals, run summaries, prompt material, owned output surfaces.

## Read broadly, write narrowly

Safety depends on asymmetric access. SATAN may read selected personal
context broadly, subject to mode and privacy policy. It may write only
through narrow broker-controlled surfaces: SATAN-owned org blocks,
SATAN hippocampus files, SATAN proposal files, SATAN MOTD/status
files, local notifications, other explicitly registered low-risk
surfaces. All other effects should be staged as proposals.

## Proposal-first agency

Prefer proposals over direct mutation. Direct writes are appropriate
only when:

- target surface is owned by SATAN
- operation is low risk
- mode permits auto-application
- action validates against the tool/action contract
- audit log records it

Higher-risk actions stage. Examples requiring proposal or explicit
review: self-editing ROM/prompt/tool behaviour; expanding write scope;
changing capability policy; destructive edits; outbound communications
beyond local notification; code changes; bough structural mutation;
calendar/email/chat actions; loading generated elisp.

Central pattern:

```text
observe → infer → propose → validate → apply or stage → audit
```

## Self-modification governance

Self-editing is allowed but constrained. SATAN may propose changes to
prompts, tool descriptions, hippocampus policy, style, mode behaviour,
future tools, local documentation.

SATAN must not silently apply changes to: ROM prompt, tool
implementations, permission model, jail profile, self-edit scope,
executable code.

Self-edit proposals include: target, rationale, expected effect, risk,
rollback path where applicable, diff or concrete replacement text.
Generated code is never auto-loaded merely because SATAN wrote it.

## Harness and model agnosticism

Core protocol stays stable and simple enough that multiple adapters
can implement it. The broker should not depend on one provider's
tool-call format, one model's JSON behaviour, one CLI's terminal
transcript conventions, or one frontend's prompt assembly model.

Preferred boundary:

```text
broker writes manifest/context/prompt bundle
harness reads bundle
harness emits JSONL protocol messages
broker validates and responds
```

Harness-specific conventions belong in adapters, not in SATAN's
conceptual core.

## Protocol governance

Boring on purpose: newline-delimited JSON; explicit message types; no
transcript scraping; no free-text command parsing; structured tool
calls, results, finals; auditable transcript; strict validation at the
broker boundary.

The canonical message spec is [protocol.md](protocol.md). Shared exemplars
live at `~/.emacs.d/satan/protocol/fixtures.json` and drive validator tests on both
sides — the elisp validator (`dl-satan-protocol-validate` in
`dl-satan-protocol.el`) and the python validator (`harness/protocol.py`)
must remain in lockstep. Adding a message
type or required field means: edit the spec, add fixtures, update both
validators. Tests fail loudly otherwise.

The protocol is a membrane between untrusted reasoning and trusted
local action. Optimise for: debuggability, testability, portability,
crash recovery, explicit failure states, replayable audit logs.

## Permission governance

Capability-based. A mode grants capabilities; a tool requires
capabilities; an action is allowed only if the mode, tool, risk
policy, and validator all agree. Avoid vague categories like "trusted
model" or "safe prompt." Use explicit capabilities: read context,
write owned daily block, write MOTD, stage proposal, write hippocampus
entry, send local notification, query bough, propose self-edit. The
model is never the authority on whether an action is safe.

## Hippocampus governance

SATAN's memory is called the hippocampus and lives at
`~/notes/satan/hippocampus/` as one denote-named org file per entry.
SATAN curates the hippocampus freely — writes auto-apply, no candidate
/ confirmed ceremony. The user reviews when they want to via
`my/satan-hippocampus`; ad-hoc deletes / edits are expected.

Each entry carries provenance (`:RUN_ID:`, `:MODE:`, file mtime).
A future loop-detection / salience pass can use that to weigh
SATAN-authored entries against user-confirmed ones.

Important classes of entry: preference, behavioural pattern, standing
constraint, project fact, operating principle, rejected inference,
stale/expired belief. Hippocampus helps SATAN behave consistently
without becoming an opaque personality accretion.

## Outbound communication governance

Start local and narrow. Permitted low-risk surfaces: desktop
notification, MOTD/status text, SATAN-owned daily-note block, proposal
file, hippocampus file. Higher-impact outbound (email, chat,
calendar mutation, issue/PR comments, public posting, external API
mutation) requires explicit review. SATAN does not become socially or
operationally active by accident.

## Jail and runtime governance

Least privilege. The jail exposes only: prepared input bundle; allowed
scratch/output paths; necessary model-provider network access if
applicable; controlled environment variables. It does not expose:
arbitrary home directory, secrets, SSH keys, browser profile, mail,
full note tree with write access, database credentials, unrestricted
shell authority. If the model needs access to something sensitive, it
requests a broker tool.

## Audit governance

Every run is explainable after the fact. A run answers:

- Which mode ran?
- What prompt material was used?
- What hippocampus was visible?
- What context was visible?
- Which harness and model executed?
- Which tools were available?
- Which tool calls were requested?
- Which tool calls were allowed or denied?
- What final output was produced?
- Which actions were applied, staged, rejected, or failed?
- What errors occurred?

Auditability is a core feature, not debug scaffolding.

## Evolution principles

When extending SATAN, prefer changes that preserve or strengthen these
properties:

1. **Local first** — durable state remains local and inspectable.
2. **Text first** — behaviour and hippocampus visible as text where practical.
3. **Broker enforced** — enforcement in the trusted broker, not in prompt wording.
4. **Harness agnostic** — new runtimes plug in behind the protocol.
5. **Proposal first** — risky actions are staged before applied.
6. **Read broad, write narrow** — write surfaces stay explicit and small.
7. **Self-edit cautiously** — reflexive behaviour produces reviewable proposals, not silent mutation.
8. **No ambient authority** — models/harnesses never inherit broad host access by default.
9. **Make drift visible** — behaviour/prompt/hippocampus/permission changes auditable.
10. **Small useful loops beat grand autonomy** — a good daily block beats a half-trusted general agent.

## Architectural smells

Warning signs (not always forbidden, but require explicit
justification):

- prompts or tool descriptions hardcoded in dotfiles
- harness-specific logic leaking into the broker
- model-visible behaviour changing without notes-repo diffs
- new tools with broad shell/file/database access
- terminal transcript scraping as protocol
- generated code auto-loaded without review
- self-edit scope expanding before review UX matures
- hippocampus accumulating without curation / forgetting
- noisy notifications with low utility
- bough becoming canonical by accident
- audit artifacts missing or incomplete
- model-declared risk accepted as authoritative
- convenience bypasses around capability checks

## File map

### Emacs (`~/.emacs.d/satan/`)

| File | Role |
|---|---|
| `dl-satan.el` | Aggregator + `my/satan-run`. |
| `dl-satan-mode.el` | Mode registry; modes `morning`, `motd`, `self-edit-mech`, `self-edit-mind`. |
| `dl-satan-tick.el` | Tick mode family: weighted picker, quiet-hours gate, `dl-satan-tick-register` helper, default `tick-pulse`, `my/satan-tick`. |
| `dl-satan-tools.el` | Tool registry, dispatch, schema validator, JSON-Schema builder (from notes descriptions). |
| `dl-satan-tools-org.el` | Handlers: `org_read_context`, `org_update_owned_block`, `proposal_stage`. |
| `dl-satan-tools-notify.el` | `notify_send` (D-Bus). |
| `dl-satan-tools-hippocampus.el` | `hippocampus_write`; `my/satan-hippocampus`. Emits an `auto_rule` memory observation when called from a `memory-write` mode (cross-ref hook, [[satan-memory-design]] §10.7). |
| `dl-satan-tools-inbox.el` | `inbox_append`; `my/satan-inbox`; `my/satan-inbox-unread-count`. |
| `dl-satan-tools-agenda.el` | `agenda_read` (gcalcli → text); timeout-wrapped; calendar id from `$WORK_EMAIL`. |
| `dl-satan-tools-activity.el` | `activity_read` (panopticon's `~/.local/state/behaviour/` → histogram or focus segments); read-only. |
| `dl-satan-tools-bough.el` | `bough_read` (shell-out to `bough --json` for `node`, `recent_changes`, `active`, `day`, `week`, `project_subtree`); only path SATAN uses to read bough. |
| `dl-satan-tools-memory.el` | `memory_mark`, `memory_resonate`, `memory_show_trace` — LLM-facing tools over the memory substrate. |
| `dl-satan-memory.el` | Substrate aggregator + `my/satan-memory-{resonate,show,status}` interactive surface. |
| `dl-satan-memory-grammar.el` | Closed-world enums, alias seed, default weights for grammar v1 (mirrored in `memory/migrations/0002_grammar_v1.sql`). |
| `dl-satan-memory-canon.el` | Pure canonicalizer + rule registry; emits handles + per-handle source. Purity grep-lint enforced. |
| `dl-satan-memory-evidence.el` | Impure evidence-window assembly (panopticon + `bough_read` + git/fs) per [[satan-memory-design]] §4; deterministic truncation. |
| `dl-satan-memory-store.el` | `mark` / `resonate` / `show` against `satan_memory` via `psql` subprocess. |
| `dl-satan-memory-migrate.el` | Forward-only migration runner; `dl-satan-memory-renormalize` (§7 grammar-bump replay) + `-status`. |
| `memory/migrations/0001_init.sql` | Substrate schema (§6.2). |
| `memory/migrations/0002_grammar_v1.sql` | v1 grammar seed (aliases + namespace weights). |
| `memory/migrations/0003_memory_functions.sql` | `memory_mark_trace`, `memory_resonate`, `memory_show_trace`, `handle_weight_for`. |
| `memory/migrations/0004_grammar_v2_fixture.sql` | Operator-applied fixture bump exercising the renormalize CLI (adds `planning -> phase:orientation`). |
| `docs/satan/memory/design.md` | Substrate design (§§0–11). |
| `dl-satan-context.el` | Per-mode bundle assembly; strict `--read-required`; scaffold assembly. |
| `dl-satan-output.el` | Mode output handlers (`morning`, `motd`, `tick`, `self-edit`; the last is shared by both `self-edit-{mech,mind}` lanes). |
| `dl-satan-block.el` | Owned-block find/replace. |
| `dl-satan-jsonl.el` | Line-buffered filter + writer + `dl-satan-jsonl-prepare`. |
| `dl-satan-protocol.el` | Validator for the JSONL membrane; fixture loader; constants. |
| `docs/satan/protocol.md` | Canonical message-type spec. |
| `protocol/fixtures.json` | Shared valid/invalid exemplars consumed by both ert and python tests. |
| `dl-satan-audit.el` | Append-only artifact writer + 6-predicate verifier. |
| `dl-satan-budget.el` | Daily token ceiling: enumerates today's `runs/`, sums per-run `usage.tokens_total`, gates the broker pre-spawn. |
| `dl-satan-broker.el` | `make-process` driver: sentinel, timeout, direnv, op:// resolution, env pass; `--build-manifest`. |
| `test/dl-satan-memory-{migrate,grammar,canon,evidence,store,renormalize}-test.el` | Memory substrate ert against `satan_memory_test`; canon also enforces purity + §9.10 bough isolation lint. |
| `test/dl-satan-tools-{bough,memory,hippocampus}-test.el` | Tool-handler ert; hippocampus covers the cross-ref hook. |
| `bin/satan-run` | Shell wrapper (`emacsclient --eval`). |
| `bin/satan-run-tick` | Tick wrapper; calls `(my/satan-tick)` which picks + quiet-checks. |
| `harness/__main__.py` | Entrypoint: sys.path bootstrap + `main`. |
| `harness/protocol.py` | JSONL validator + `emit*` / `read_tool_result`. |
| `harness/bundle.py` | `load_bundle` / `load_manifest` / `build_system_prompt` / `build_tools`. |
| `harness/runloop.py` | Turn loop + budget guard + tool-call dispatch. |
| `harness/providers/{base,openrouter}.py`, `__init__.py` | `Provider` ABC, OpenAI-v1 adapter, `build_provider` registry. |
| `harness/test_gptel_harness.py` | stdlib unittest cases (no network). |
| `test/dl-satan-test.el` | Phase-3 unit ert. |
| `test/dl-satan-integration-test.el` | 1 e2e ert (skips unless `SATAN_TEST_JAIL_BIN` set). |

### Wiring

- `~/.emacs.d/init.el` — `(require 'dl-satan)` after `dl-denote-journal`.
- `~/.emacs.d/core/dl-path.el` — `"satan"` in `my/lisp-dirs`.
- `~/flakes/modules/home/emacs.nix` — `"satan"` in `configDirs`.
- `~/.emacs.d/flake.nix` — `satanFakeHarness`, `satanGptelHarness`,
  `satanJailOptions`, `satanGptelJailOptions`,
  `satan-jailed-fake-harness`, `satan-jailed-gptel-harness`. Devshell
  exposes both binaries on PATH; broker's `direnv-env` plumbing picks
  them up at spawn.
- `~/flakes/modules/home/satan.nix` — imported by Sleipnir. Units
  `satan-morning.{service,timer}` (09:00),
  `satan-motd.{service,timer}` (07:00), and
  `satan-tick.{service,timer}` (`OnBootSec=5min`,
  `OnUnitActiveSec=30min`, `RandomizedDelaySec=5min`).

### Notes tree (canonical model-facing surface)

```
~/notes/satan/
  prompts/                           # mode prompts
    morning.txt
    motd.txt
    self-edit-mech.txt               # SATAN's mechanism scope (~/.emacs.d/satan/)
    self-edit-mind.txt               # SATAN's mind scope (notes prompts+system+tools)
    tick/                            # one file per registered tick-* mode
      pulse.txt
  system/
    scaffold.txt                     # shared system-prompt scaffold (termination instruction)
  tools/                             # one markdown file per tool — model-facing description
    org_read_context.md
    org_update_owned_block.md
    proposal_stage.md
    notify_send.md
    hippocampus_write.md
    inbox_append.md
    bough_read.md
    memory_mark.md
    memory_resonate.md
    memory_show_trace.md
    satan_final.md                   # synthetic harness-side tool, canonical desc here
  motd.txt
  inbox.org                          # append-only headlines, tagged :unread:satan:
  hippocampus/                       # <ID>--<slug>__satan_hippocampus.org; rw inside jail at /satan/hippocampus
  proposals/                         # <ID>--<slug>__satan_proposal.org
  runs/<run-id>/                     # YYYYMMDDTHHMMSS-<mode>-<rand6>
    bundle.json                      # frozen input (incl. assembled :prompt)
    manifest.json                    # mode + capabilities + harness + tools[] (full JSON Schemas)
    transcript.jsonl                 # one JSON object per line
    final.json                       # validated final or {status: invalid}
    actions.json                     # {applied, staged, rejected, failed}
    stdout.log
    stderr.log
    status                           # done | failed | timed-out | invalid-protocol | budget-exceeded
```

## Modes

| Mode | Tools | Auto-apply | Budget tokens / tool-calls / wall |
|---|---|---|---|
| `morning` | `org_read_context`, `org_update_owned_block`, `proposal_stage`, `notify_send`, `hippocampus_write`, `inbox_append`, `agenda_read`, `activity_read`, `sway_border_set`, `sway_border_reset`, `bough_read`, `memory_mark`, `memory_resonate`, `memory_show_trace` | `owned` | 20000 / 8 / 90s |
| `motd` | `org_read_context`, `notify_send`, `inbox_append`, `agenda_read`, `activity_read`, `sway_border_set`, `sway_border_reset`, `bough_read`, `memory_mark`, `memory_resonate`, `memory_show_trace` | `owned` (motd surface owned by output handler; written from `satan_final.summary`) | 10000 / 4 / 45s |
| `tick-*` | `org_read_context`, `notify_send`, `inbox_append`, `sway_border_set`, `sway_border_reset`, `bough_read`, `memory_mark`, `memory_resonate`, `memory_show_trace` | `owned` (only `inbox_append`) | 3000 / 4 / 30s |
| `self-edit-mech` | `proposal_stage`, `sway_border_set`, `sway_border_reset`, `bough_read`, `memory_resonate`, `memory_show_trace` | `none` | 50000 / 20 / 180s |
| `self-edit-mind` | `proposal_stage`, `sway_border_set`, `sway_border_reset`, `bough_read`, `memory_resonate`, `memory_show_trace` | `none` | 50000 / 20 / 180s |

Capabilities: `morning` and `motd` (and `tick-*`) carry `memory-write` so
the memory_mark + hippocampus cross-ref hook are admitted; `self-edit-*`
lanes are read-only against the substrate.

All three use OpenRouter with `anthropic/claude-haiku-4.5` by default.
Override per-mode in `dl-satan-mode.el`: `:provider`, `:model`,
`:budget-tokens`.

## Tools

| Name | Risk | Auth | Effect |
|---|---|---|---|
| `org_read_context` | read | — | Read today/week/inbox text. |
| `org_update_owned_block` | low | capability `write-daily` | Replace owned `#+begin_satan` block (target=today). |
| `proposal_stage` | low | capability `stage-proposal` | Write a denote proposal file. |
| `notify_send` | low | capability `notify` | D-Bus desktop notification. |
| `hippocampus_write` | low | capability `hippocampus-write` | Append a denote hippocampus entry (SATAN-owned, auto-applied). |
| `inbox_append` | low | capability `inbox-write` | Append a headline to `~/notes/satan/inbox.org` (SATAN-owned, auto-applied; preferred over `notify_send` for non-urgent messages). |
| `agenda_read` | read | — | Fetch the work calendar via `gcalcli`. Calendar id read from `$WORK_EMAIL`; wrapped in `timeout(1)` so a stalled gcalcli can't freeze the broker. |
| `activity_read` | read | — | Read panopticon's behaviour state from `~/.local/state/behaviour/`. `scope="today"` returns the daily histogram; `scope="recent_focus"` / `recent_browser` return the last N focus / browser segments; `scope="current"` returns the live focused-window snapshot (`app_id`, `workspace`, `output`, `title`, `pid`). PII redaction is handled by the producer (firefox URLs stripped to origin, incognito dropped). The `current` scope intentionally passes `title` through — see open thread "current-scope title leak". |
| `bough_read` | read | — | Shell-out wrapper around `bough --json` — only path SATAN uses to read bough.  Scopes: `node`, `recent_changes`, `active`, `day`, `week`, `project_subtree`. |
| `memory_mark` | low | capability `memory-write` | Persist an `observation` trace into `satan_memory`. The broker canonicalizes evidence deterministically; the LLM supplies typed hints (no raw handles).  Stamped `trace_origin = llm_mark`. |
| `memory_resonate` | read | — | Inverted-index lookup over `trace_handles`; returns matches scored by `weight * trace.strength`.  No state mutation in v1. |
| `memory_show_trace` | read | — | Round-trip a trace by id (handles, sources, links). |

The python harness intercepts a synthetic `satan_final(summary,
actions[])` tool call as the terminal signal and emits the broker's
`final` record. Plain-content responses with no tool calls are coerced
into `final` with `reason=no_tool_calls`. Budget exhaustion: harness
self-terminates with `reason=budget_tokens`.

## Operations

```sh
# Build the jailed harnesses.
nix build .#satan-jailed-fake-harness  --no-link --print-out-paths
nix build .#satan-jailed-gptel-harness --no-link --print-out-paths

# Standalone protocol smoke (no Emacs) — fake harness.
JAIL=$(nix build .#satan-jailed-fake-harness --no-link --print-out-paths)/bin/jailed-satan-fake-harness
mkdir -p /tmp/satan-smoke && SATAN_RUN_ID=smoke SATAN_RUN_DIR=/tmp/satan-smoke \
  "$JAIL" <<< '{"type":"tool_result","id":"c1","ok":true,"result":{"content":""}}'

# Unit ert.
emacs --batch -L core -L lisp -L org -L satan -L satan/test \
  -l satan/test/dl-satan-test.el -f ert-run-tests-batch-and-exit

# Integration ert (real bwrap jail, fake harness).
JAIL=$(nix build .#satan-jailed-fake-harness --no-link --print-out-paths)/bin/jailed-satan-fake-harness
SATAN_TEST_JAIL_BIN=$JAIL emacs --batch -L core -L lisp -L org -L satan -L satan/test \
  -l satan/test/dl-satan-integration-test.el -f ert-run-tests-batch-and-exit

# Python harness unit tests.
cd ~/.emacs.d/satan/harness && python -m unittest test_gptel_harness -v

# Audit a real run.
emacsclient --eval '(dl-satan-audit-verify-run "/home/david/notes/satan/runs/<RUN-ID>/")'

# Inspect timer state.
systemctl --user list-timers satan-*
journalctl --user -u satan-morning.service --since today
```

## Conventions / gotchas

### Bundle `:now` block

Every context-fn includes a `:now` plist via `dl-satan-context-now`:
`iso_date`, `weekday`, `iso_week`, `time`, `tz_offset`, `tz_name`.
The broker renders this as a fixed `# Now` section between the
assembled prompt and any `today_text` / source-file sections (see
`dl-satan-context--render-prompt` and `~/notes/satan/system/framing.txt`),
so the model always sees the same date/time/tz framing regardless of
mode. Single source of truth — never set `:date`/`:time` separately.

### Owned-block syntax

Custom block, not a dynamic-block, not a drawer:

```org
#+begin_satan :block satan :owner SATAN :updated [2026-05-19 Tue 07:30]
…body…
#+end_satan
```

Inert to org's dblock updater; `dl-satan-block-replace` is idempotent.

### `json-serialize` arrays

Elisp lists become objects unless coerced to vectors.
`dl-satan-jsonl-prepare` walks payloads: plists (car keyword) preserved;
non-plist lists → vectors; recurses. Applied at every JSON write
boundary (audit, outbound send). **Never call `json-serialize` directly
on a SATAN payload.**

### Failed-action shape

Plist `(:action ACTION :reason MSG)`, never the improper cons
`(ACTION . MSG)` — `json-serialize` rejects improper lists.

### Run-id

`format-time-string "%Y%m%dT%H%M%S" + "-" + mode + "-" + 6-hex-random`.
The `YYYYMMDDT` prefix is load-bearing: `dl-satan-budget` uses it to
enumerate today's runs without parsing manifests.

### Self-edit lanes (mech vs mind)

Self-editing is split into two proposal-only lanes that share governance
defaults (50000-token budget, 20 tool calls, 180-second timeout,
`proposal_stage` only, `auto-apply none`) but read different roots:

| Mode | Source roots | Stamped `:MODE:` |
|---|---|---|
| `self-edit-mech` | `dl-satan-self-edit-mech-roots` (default `~/.emacs.d/satan/`) | `self-edit-mech` |
| `self-edit-mind` | `dl-satan-self-edit-mind-roots` (default `~/notes/satan/{prompts,system,tools}/`) | `self-edit-mind` |

Both lanes write proposals to `~/notes/satan/proposals/`; the
`:MODE:` property in each denote file distinguishes them. Mode specs
reference defcustoms via `:source-roots-var` so the user can recustomize
roots without redefining modes. The shared context-fn
`dl-satan-context-self-edit` reads either `:source-roots` (direct) or
`:source-roots-var` (indirect) from the mode spec; sources are
abbreviated paths (`~/notes/...`, `~/.emacs.d/...`).

### Tick mode family

`tick-*` modes are short, frequent, lightly-budgeted runs fired every
~30 minutes by `satan-tick.timer`. The wrapper `bin/satan-run-tick`
calls `my/satan-tick`, which:

1. Returns early if `dl-satan-tick-quiet-p` is non-nil. Default
   quiet window is 22:00–07:00 inclusive of 22 / exclusive of 07,
   wraparound supported. Set `dl-satan-tick-quiet-hours` to nil to
   disable.
2. Samples a mode name from `dl-satan-tick-pool` (defcustom alist of
   `(MODE-NAME . WEIGHT)`; default `(("tick-pulse" . 1))`).
3. Spawns the chosen mode via `my/satan-run`, which still passes
   through the daily-token-ceiling gate.

Each tick mode is registered via `dl-satan-tick-register SHORT-NAME
&rest OVERRIDES`. The helper applies the standard defaults
(`org_read_context` + `notify_send` + `inbox_append` tool surface,
`(notify inbox-write)` capabilities, 3000-token / 4-call / 30-second
budget, `dl-satan-context-tick` + `dl-satan-output/tick`,
`anthropic/claude-haiku-4.5`). Prompts live at
`~/notes/satan/prompts/tick/<short-name>.txt`. Add a tick by writing a
prompt file and calling `(dl-satan-tick-register "name")` from the
config.

### Daily token ceiling

`dl-satan-budget-daily-tokens` (default 400000) caps total tokens spent
under `dl-satan-runs-dir` per local day. Pre-spawn, the broker sums
each today-prefixed run's max `usage.tokens_total` log event. If the
ceiling is met, the broker writes a slim audit bundle for the new
run-id with `status=budget-exceeded`, a synthetic `final.json` carrying
`reason=budget_daily_tokens`, and skips the child entirely. Set to nil
to disable. Status `budget-exceeded` is a valid terminal — the audit
verifier accepts it.

### direnv-driven exec-path

`dl-satan-direnv-dir` (default `user-emacs-directory`) is resolved via
`envrc--export` at spawn time and merged into `process-environment`.
Means the jailed binary lives in the `.emacs.d` devshell; no global
`home.packages` install.

### Jail env

`SATAN_RUN_ID`, `SATAN_PROVIDER`, `SATAN_MODEL`, `SATAN_BUDGET_TOKENS`
forwarded via `try-fwd-env`. `SATAN_RUN_DIR`, `SATAN_HIPPOCAMPUS` set
to fixed paths inside the jail (`/satan/run`, `/satan/hippocampus`).
`$HOME/notes` is ro-bound to `/satan/notes`.

### Key resolution (op://)

Mode `:provider` symbol maps via `dl-satan-broker-provider-key-vars`
(`openrouter` → `OPENROUTER_API_KEY`, plus `anthropic`, `openai`,
`deepseek`). Broker calls `my/op-read-env` at spawn to resolve any
`op://` ref to plaintext, wrapped in `condition-case` so a locked 1P
doesn't crash the run. Resolved plaintext is forwarded into the jail.

### Four traps from the Nix integration

(See [docs/emacs/traps.md](../emacs/traps.md) for the full table. Repeated
here for SATAN-specific relevance.)

1. **Flake builds see only git-tracked files** — `git add` new `.el` or
   `harness/*.py` before `home-manager switch` or
   `nix build .#satan-jailed-gptel-harness`.
2. **`:ensure nil` is "don't install"** — n/a for SATAN itself (no
   `use-package` blocks here), but watch in surrounding modules.
3. **Never `setq` preloaded native-comp vars** — n/a for SATAN.
4. **`trusted-content` entries must be `~/` form** — n/a for SATAN.
5. **Harness build runs `ruff check`** — the
   `pkgs.stdenv.mkDerivation` shape introduced in phase 3B replaced
   `pkgs.writers.writePython3Bin` (single-file only).  `checkPhase`
   runs `ruff check --select E,F,W --ignore E501,E402 .`; the legacy
   W503 / E704 ignores were dropped because ruff doesn't emit them.

### Naming

- `dl-satan-MODULE` for the elisp `provide` symbol.
- `dl-satan-MODULE-name` for public internals; `dl-satan-MODULE--name`
  for private.
- `my/satan-*` for user-callable commands (`my/satan-run`,
  `my/satan-hippocampus`).
- Tool names: `domain_verb` (`org_read_context`, `notify_send`).
  Underscored, not dotted: must match `^[a-zA-Z0-9_-]+$` so the schema
  survives every OpenAI-compatible adapter (OpenRouter → Amazon Bedrock
  rejects dots; OpenAI's own validator does too).

## External dependencies

- **panopticon** (`~/dev/panopticon`, own repo) — captures desktop
  behaviour into `~/.local/state/behaviour/{raw,segments,histograms,current}/`.
  v0.1 sway watcher + firefox extension + segmentizer live as of
  2026-05-19. SATAN consumes via `activity_read` (read-only, no IPC
  from the broker — handler runs in Emacs and reads files directly).
  See `~/dev/panopticon/HANDOVER.md`.

## Open threads

Numbered for cross-referencing in commits / changelog.

1. **Real-API live smoke** — ✅ done 2026-05-19. Morning run against
   OpenRouter produced a daily-note SATAN block and a full
   `transcript.jsonl` with `usage` log events.
2. **`org-roam` backlinks in morning context** —
   `dl-satan-context-morning` currently only dumps today's note text +
   prompt. Surfacing backlinks for unresolved-loop items would let the
   model thread yesterday's open questions into today's plan.
3. **Hippocampus / proposal review UX (magit-style)** — v1 is raw
   `find-file` / dired (`my/satan-hippocampus`). When volume
   warrants, a `magit-status`-style buffer over `proposals/` +
   `hippocampus/` with `a`pply / `r`eject / `s`nooze actions.
4. **Budget-exhaustion UX** — ✅ done 2026-05-19. On first budget
   breach the harness emits `log{kind=budget_warning}` and appends a
   system-role nudge to the chat; the model gets one turn to call
   `satan_final`. If it doesn't, the harness force-terminates with
   `final{reason=budget_tokens}` (the old behaviour, now an escape
   hatch rather than the primary path).
5. **Pi / Zerostack harness adapter** — same `Provider` interface,
   different runtime. Plug-in via env (`SATAN_PROVIDER=pi`). Not
   started.
6. **Self-describing manifest** — ✅ done 2026-05-19 (phase 2E).
   Broker writes full JSON Schema for each allowed tool into
   `manifest.json["tools"]`; harness reads verbatim. Descriptions are
   loaded from `~/notes/satan/tools/<name>.md` (mind/mechanism split).
7. **Self-edit scope expansion** — currently
   `dl-satan-self-edit-root = ~/.emacs.d/satan/`. Broader (full
   `~/.emacs.d/`) is on the table when SATAN's edit suggestions prove
   trustworthy.
8. **`org_read_context` scope coverage** — only `today | week | inbox`.
   `org-agenda`, `org-roam` graph queries, recently-edited files would
   all be useful.
9. **Bundle-section framing in `build_system_prompt`** — ✅ done
   2026-05-19 (phase 3D). Section headers (`# Now`, `# Today (raw)`,
   `# Source files`) live in `~/notes/satan/system/framing.txt`; the
   broker renders the full system prompt and writes it into
   `bundle["prompt"]`; the harness is a passthrough
   (`return bundle["prompt"]`). No canonical model-facing prose lives
   in dotfiles anymore.
10. **`activity_read` current-scope title leak** — `scope="current"`
    returns sway's focused-window snapshot verbatim, including the
    `title` field. Sway IPC titles surface browser tab page-titles,
    editor file paths, Slack thread subjects, etc. — anything the
    focused window puts in its title bar. When this lands in the LLM
    request body the provider can log it. Acceptable for now; tighten
    later either by (a) stripping `:title` SATAN-side or (b) having
    panopticon write a `current/sway-public.json` without title for
    consumers like SATAN to read.

## Preferred shape of future work

Improvements usually fall into one of these categories:

- **Better context** — agenda; backlinks; recently-edited notes;
  unresolved loops; bough graph queries; project summaries.
- **Better review** — proposal review UI; hippocampus review UI;
  accept/reject/snooze flows; diff-based self-edit review.
- **Better portability** — second harness adapter; self-describing
  manifests (done — phase 2E); provider-neutral tool schema generation.
- **Better governance** — clearer capability policy; stronger audit
  verification; narrower jail profiles; better failure handling.
- **Better usefulness** — daily planning loop; evening reflection loop;
  weekly pattern review; capture triage; MOTD/status loop.

Avoid adding autonomy before improving review, audit, and context.

## When implementation conflicts with this document

Either:

1. change the implementation to restore the invariant, or
2. deliberately revise this document and explain why the governing
   principle changed.

Do not let accidental implementation drift become architecture.
