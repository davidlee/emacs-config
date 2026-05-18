# SATAN — Local Agent Runtime

Living document.  Counterpart: `SATAN.local.md` (design brief, frozen).
This file captures what is built, how it runs, where it lives, the
gotchas, and the open threads.  Update on every meaningful change.

## Status

| Phase | Status | Notes |
|---|---|---|
| 1 — broker + JSONL + fake harness | ✅ | landed 2026-05-19 |
| 2A — real LLM harness (OpenRouter) | ✅ | landed 2026-05-19 |
| 2B — `notify.send` tool | ✅ | landed 2026-05-19 |
| 2C — `memory.add_candidate` tool | ✅ | landed 2026-05-19, raw `find-file` review |
| 2D — `self-edit` mode | ✅ | landed 2026-05-19, SATAN-only scope |
| Wired into Sleipnir (`satan.nix`) | ✅ | timers `satan-morning` 07:30, `satan-motd` 07:00 |

`M-x my/satan-run RET morning` writes a SATAN-owned block into today's
daily note and a full audit bundle under `~/notes/satan/runs/<run-id>/`.
`motd` writes `~/notes/satan/motd.txt`.  `self-edit` stages proposals
under `~/notes/satan/proposals/` — nothing auto-applies.

Tests: 24/24 unit ert + 8/8 python unittest + 1/1 integration ert.

## Quickstart

```sh
# Manual invocation (the morning timer also does this).
M-x my/satan-run RET morning
M-x my/satan-run RET motd
M-x my/satan-run RET self-edit          # SATAN audits its own source

# Review staged artifacts.
M-x my/satan-memory-candidates           # dired ~/notes/satan/memory/candidates
find ~/notes/satan/proposals             # denote-named proposals

# Audit a finished run.
emacsclient --eval '(dl-satan-audit-verify-run "/home/david/notes/satan/runs/<RUN-ID>/")'
```

The wrapper script `~/.emacs.d/satan/bin/satan-run <mode>` invokes
`emacsclient --eval` and is what the systemd units call.

## File map

### Emacs (`~/.emacs.d/satan/`)

| File | Role |
|---|---|
| `dl-satan.el` | Aggregator + `my/satan-run`. |
| `dl-satan-mode.el` | Mode registry; modes `morning`, `motd`, `self-edit`. |
| `dl-satan-tools.el` | Tool registry, dispatch, schema validator. |
| `dl-satan-tools-org.el` | Handlers: `org.read_context`, `org.update_owned_block`, `proposal.stage`. |
| `dl-satan-tools-notify.el` | `notify.send` (D-Bus). |
| `dl-satan-tools-memory.el` | `memory.add_candidate`; `my/satan-memory-candidates`. |
| `dl-satan-context.el` | Per-mode bundle assembly (incl. `dl-satan-context-self-edit`). |
| `dl-satan-output.el` | Mode output handlers (`morning`, `motd`, `self-edit`). |
| `dl-satan-block.el` | Owned-block find/replace. |
| `dl-satan-jsonl.el` | Line-buffered filter + writer + `dl-satan-jsonl-prepare`. |
| `dl-satan-audit.el` | Append-only artifact writer + 6-predicate verifier. |
| `dl-satan-broker.el` | `make-process` driver: sentinel, timeout, direnv, op:// resolution, env pass. |
| `bin/satan-run` | Shell wrapper (`emacsclient --eval`). |
| `prompts/{morning,motd,self-edit}.txt` | Mode prompts. |
| `harness/gptel_harness.py` | OpenAI-compatible chat-completions driver; `Provider` ABC + `OpenRouterProvider`. |
| `harness/test_gptel_harness.py` | 8 stdlib unittest cases, no network. |
| `test/dl-satan-test.el` | 24 unit ert. |
| `test/dl-satan-integration-test.el` | 1 e2e ert (skips unless `SATAN_TEST_JAIL_BIN` set). |

### Wiring

- `~/.emacs.d/init.el` — `(require 'dl-satan)` after `dl-denote-journal`.
- `~/.emacs.d/core/dl-path.el` — `"satan"` in `my/lisp-dirs`.
- `~/flakes/modules/home/emacs.nix` — `"satan"` in `configDirs`.
- `~/.emacs.d/flake.nix` — `satanFakeHarness`, `satanGptelHarness`,
  `satanJailOptions`, `satanGptelJailOptions`,
  `satan-jailed-fake-harness`, `satan-jailed-gptel-harness`.  Devshell
  exposes both binaries on PATH; broker's `direnv-env` plumbing picks
  them up at spawn.
- `~/flakes/modules/home/satan.nix` — imported by Sleipnir.  Units
  `satan-morning.{service,timer}` (07:30) and
  `satan-motd.{service,timer}` (07:00).

### Notes tree

```
~/notes/satan/
  motd.txt
  hippocampus/                       # rw inside jail at /satan/hippocampus
  proposals/                         # <ID>--<slug>__satan_proposal.org
  memory/candidates/                 # <ID>--<slug>__satan_memory.org
  runs/<run-id>/                     # YYYYMMDDTHHMMSS-<mode>-<rand6>
    bundle.json                      # frozen input
    manifest.json                    # mode + tools + harness + capabilities
    transcript.jsonl                 # one JSON object per line
    final.json                       # validated final or {status: invalid}
    actions.json                     # {applied, staged, rejected, failed}
    stdout.log
    stderr.log
    status                           # done | failed | timed-out | invalid-protocol
```

## Modes

| Mode | Tools | Auto-apply | Budget tokens / tool-calls / wall |
|---|---|---|---|
| `morning` | `org.read_context`, `org.update_owned_block`, `proposal.stage`, `notify.send`, `memory.add_candidate` | `owned` | 20000 / 8 / 90s |
| `motd` | `org.read_context`, `org.update_owned_block`, `notify.send` | `owned` | 5000 / 4 / 45s |
| `self-edit` | `proposal.stage` | `none` | 50000 / 20 / 180s |

All three use OpenRouter with `anthropic/claude-haiku-4.5` by default.
Override per-mode in `dl-satan-mode.el`: `:provider`, `:model`,
`:budget-tokens`.

## Tools

| Name | Risk | Auth | Effect |
|---|---|---|---|
| `org.read_context` | read | — | Read today/week/inbox text. |
| `org.update_owned_block` | low | capability `write-daily` or `write-motd` | Replace owned `#+begin_satan` block. |
| `proposal.stage` | low | capability `stage-proposal` | Write a denote proposal file. |
| `notify.send` | low | capability `notify` | D-Bus desktop notification. |
| `memory.add_candidate` | medium | capability `memory-candidate` | Write a denote memory-candidate file. |

The python harness intercepts a synthetic `satan.final(summary,
actions[])` tool call as the terminal signal and emits the broker's
`final` record.  Plain-content responses with no tool calls are coerced
into `final` with `reason=no_tool_calls`.  Budget exhaustion: harness
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
non-plist lists → vectors; recurses.  Applied at every JSON write
boundary (audit, outbound send).  **Never call `json-serialize` directly
on a SATAN payload.**

### Failed-action shape

Plist `(:action ACTION :reason MSG)`, never the improper cons
`(ACTION . MSG)` — `json-serialize` rejects improper lists.

### Run-id

`format-time-string "%Y%m%dT%H%M%S" + "-" + mode + "-" + 6-hex-random`.

### direnv-driven exec-path

`dl-satan-direnv-dir` (default `user-emacs-directory`) is resolved via
`envrc--export` at spawn time and merged into `process-environment`.
Means the jailed binary lives in the `.emacs.d` devshell; no global
`home.packages` install.

### Jail env

`SATAN_RUN_ID`, `SATAN_PROVIDER`, `SATAN_MODEL`, `SATAN_BUDGET_TOKENS`
forwarded via `try-fwd-env`.  `SATAN_RUN_DIR`, `SATAN_HIPPOCAMPUS` set
to fixed paths inside the jail (`/satan/run`, `/satan/hippocampus`).
`$HOME/notes` is ro-bound to `/satan/notes`.

### Key resolution (op://)

Mode `:provider` symbol maps via `dl-satan-broker-provider-key-vars`
(`openrouter` → `OPENROUTER_API_KEY`, plus `anthropic`, `openai`,
`deepseek`).  Broker calls `my/op-read-env` at spawn to resolve any
`op://` ref to plaintext, wrapped in `condition-case` so a locked 1P
doesn't crash the run.  Resolved plaintext is forwarded into the jail.

### Four traps from the Nix integration

(See `AGENTS.md` for the full table.  Repeated here for SATAN-specific
relevance.)

1. **Flake builds see only git-tracked files** — `git add` new `.el` or
   `harness/*.py` before `home-manager switch` or
   `nix build .#satan-jailed-gptel-harness`.
2. **`:ensure nil` is "don't install"** — n/a for SATAN itself (no
   `use-package` blocks here), but watch in surrounding modules.
3. **Never `setq` preloaded native-comp vars** — n/a for SATAN.
4. **`trusted-content` entries must be `~/` form** — n/a for SATAN.

5. **`writePython3Bin` lints with ruff** — `import x, y, z` fails E401;
   `def f(): ...` one-liners fail E704.  See `flake.nix` `flakeIgnore`
   list for the codes we currently silence.

### Naming

- `dl-satan-MODULE` for the elisp `provide` symbol.
- `dl-satan-MODULE-name` for public internals; `dl-satan-MODULE--name`
  for private.
- `my/satan-*` for user-callable commands (`my/satan-run`,
  `my/satan-memory-candidates`).
- Tool names: `domain.verb` (`org.read_context`, `notify.send`).

## Open threads

Numbered for cross-referencing in commits / changelog.

1. **Real-API live smoke** — never executed against openrouter from
   inside Emacs.  Manual: `M-x my/satan-run RET morning` while 1P is
   unlocked; verify daily-note SATAN block + `transcript.jsonl`
   `log` events with `usage`.
2. **`org-roam` backlinks in morning context** —
   `dl-satan-context-morning` currently only dumps today's note text +
   prompt.  Surfacing backlinks for unresolved-loop items would let the
   model thread yesterday's open questions into today's plan.
3. **Memory / proposal review UX (magit-style)** — v1 is raw
   `find-file` / dired (`my/satan-memory-candidates`).  When volume
   warrants, a `magit-status`-style buffer over `proposals/` +
   `memory/candidates/` with `a`pply / `r`eject / `s`nooze actions.
4. **Budget-exhaustion UX** — harness self-terminates with a synthetic
   `final{reason=budget_tokens}`.  Smoother: emit a `system` log
   message, let the LLM wind down naturally with its own `satan.final`
   on the next turn.
5. **Pi / Zerostack harness adapter** — same `Provider` interface,
   different runtime.  Plug-in via env (`SATAN_PROVIDER=pi`).  Not
   started.
6. **Self-describing manifest** — `gptel_harness.py` currently
   hardcodes `TOOL_SCHEMAS`.  Future: broker writes full JSON Schema
   for each allowed tool into `manifest.json`, harness reads it.  Lets
   a tool be added in elisp alone, no harness edit.  Tracking comment
   lives in `gptel_harness.py` at the `TOOL_SCHEMAS` definition.
7. **Self-edit scope expansion** — currently
   `dl-satan-self-edit-root = ~/.emacs.d/satan/`.  Broader (full
   `~/.emacs.d/`) is on the table when SATAN's edit suggestions prove
   trustworthy.
8. **`org.read_context` scope coverage** — only `today | week | inbox`.
   `org-agenda`, `org-roam` graph queries, recently-edited files would
   all be useful.

## Counterpart

- `SATAN.local.md` — design brief, frozen.  Read first for intent and
  invariants.  This file (`SATAN.md`) for current state.
- `CHANGELOG.md` — dated, narrative log of what landed.
