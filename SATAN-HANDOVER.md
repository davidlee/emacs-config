# SATAN — Phase-1 Handover

Counterpart to `SATAN.local.md` (design brief).  This file records what
was actually built, where it lives, the deltas from the brief, the
gotchas hit, and the entry points for phase 2.

## Status

Phase 1 complete and live on Sleipnir as of 2026-05-19.
`M-x my/satan-run RET morning` writes a SATAN-owned block into today's
daily note and a full audit bundle under `~/notes/satan/runs/<run-id>/`.
`motd` mode writes `~/notes/satan/motd.txt`.  16/16 ert tests green
(15 unit + 1 e2e against the real jailed binary).

## File map

### Emacs (`~/.emacs.d/satan/`)

| File | Role |
|---|---|
| `dl-satan.el` | Aggregator + `my/satan-run`. |
| `dl-satan-mode.el` | Mode registry; built-ins `morning`, `motd`. |
| `dl-satan-tools.el` | Tool registry, dispatch, schema validator. |
| `dl-satan-tools-org.el` | Handlers: `org.read_context`, `org.update_owned_block`, `proposal.stage`. |
| `dl-satan-context.el` | Per-mode bundle assembly. |
| `dl-satan-output.el` | Mode output handlers (`morning`, `motd`). |
| `dl-satan-block.el` | Owned-block find/replace. |
| `dl-satan-jsonl.el` | Line-buffered filter + writer + `dl-satan-jsonl-prepare` (list→vector normalizer). |
| `dl-satan-audit.el` | Append-only artifact writer + 6-predicate verifier. |
| `dl-satan-broker.el` | `make-process` driver, sentinel, timeout, direnv plumbing. |
| `bin/satan-run` | Shell wrapper (`emacsclient --eval`). |
| `prompts/{morning,motd}.txt` | Static prompts. |
| `test/dl-satan-test.el` | 15 unit ert. |
| `test/dl-satan-integration-test.el` | 1 e2e ert (skips unless `SATAN_TEST_JAIL_BIN` set). |

### Wiring

- `~/.emacs.d/init.el` — `(require 'dl-satan)` after `dl-denote-journal`.
- `~/.emacs.d/core/dl-path.el` — `"satan"` in `my/lisp-dirs`.
- `~/flakes/modules/home/emacs.nix` — `"satan"` in `configDirs`.
- `~/.emacs.d/flake.nix` — `satanFakeHarness`, `satanJailOptions`,
  `satan-jailed-fake-harness` derivation; `packages = jailPkgs` exposed
  for `nix build .#satan-jailed-fake-harness`.
- `~/flakes/modules/home/satan.nix` — `flake.homeModules.satan` with
  `satan-morning` and `satan-motd` user units (uses `%h` not
  `config.home.homeDirectory`).  **NOT imported by Sleipnir.nix.**

### Notes tree

```
~/notes/satan/
  motd.txt
  hippocampus/           # rw inside jail at /satan/hippocampus
  proposals/             # denote-named: <ID>--<slug>__satan_proposal.org
  runs/<run-id>/         # YYYYMMDDTHHMMSS-<mode>-<rand6>
    bundle.json
    manifest.json
    transcript.jsonl
    final.json
    actions.json
    stdout.log
    stderr.log
    status               # done | failed | timed-out | invalid-protocol
```

## Deltas from `SATAN.local.md`

- **Owned-block syntax**: custom block `#+begin_satan :block NAME :owner SATAN :updated [TS]` / `#+end_satan` (not a dynamic-block, not a drawer).  Inert to org's dblock updater.
- **Failed-action shape**: plist `(:action ACTION :reason MSG)`, not the
  improper cons `(ACTION . MSG)` the original sketch implied.
  Improper lists broke `json-serialize`.
- **`json-serialize` arrays**: elisp lists become objects unless coerced
  to vectors.  `dl-satan-jsonl-prepare` walks payloads: plists (car
  keyword) preserved; non-plist lists → vectors; recurses.  Applied at
  every JSON write boundary (audit, outbound send).
- **Run-id minting**: `format-time-string "%Y%m%dT%H%M%S" + "-" + mode + "-" + (random 16^6)` as 6-hex.
- **direnv-driven exec-path**: `dl-satan-direnv-dir` (default
  `user-emacs-directory`) is resolved via `envrc--export` at spawn time
  and merged into `process-environment`.  Means the jailed binary lives
  in the .emacs.d devshell; no global `home.packages` install.
- **Jail env**: `SATAN_RUN_ID` is forwarded (`try-fwd-env`).
  `SATAN_RUN_DIR` and `SATAN_HIPPOCAMPUS` are set to fixed paths inside
  the jail (`/satan/run`, `/satan/hippocampus`).  `$HOME/notes` is
  ro-bound to `/satan/notes`.

## Gotchas (learned the hard way)

1. **`json-serialize` rejects bare lists** as if they were ill-formed
   plists.  Always pass through `dl-satan-jsonl-prepare` before
   serializing.
2. **`import-tree ./modules`** in `~/flakes/flake.nix` evaluates *every*
   `modules/home/*.nix` eagerly to register `flake.homeModules.*`, even
   if the host doesn't import them.  Any unbound reference (e.g.
   `config.home.homeDirectory` when `config` isn't passed) breaks
   `home-manager switch` for unrelated reasons.  Use systemd specifiers
   (`%h`) for paths instead.
3. **`writePython3Bin` lints with ruff**: `import x, y, z` on one line
   fails E401.  Split imports onto separate lines.
4. **`mode-name` is a dynamic variable** in Emacs (the modeline name).
   Don't shadow as a function argument; use `name` or a satan-prefixed
   symbol.

## Phase-2 entry points

- **Real harness adapter.**  Replace `:cmd "jailed-satan-fake-harness"`
  in `dl-satan-mode.el`'s morning mode with a new derivation
  `satan-jailed-gptel-harness` (or pi/openrouter/zerostack).  Switch
  the jail profile to `specDev` to get network and re-use
  `jailEnvOptions` (`try-fwd-env "OPENROUTER_API_KEY"` already in
  `flake.nix:47-49`).  The adapter must:
  - Read the bundle from `$SATAN_RUN_DIR/bundle.json`.
  - Stream JSONL on stdout: `ready` → 0..N `tool_call`s, reading each
    `tool_result` from stdin → `final`.
  - Bound by mode `:budget-tool-calls` (broker enforces; child gets a
    `tool_result ok=false error="budget exhausted"` on overflow).
- **`memory.add_candidate` tool.**  Add to
  `dl-satan-tools-org.el`-style sibling; write to
  `~/notes/satan/memory/candidates/<denote-id>...`.  Register
  in `dl-satan-tools` with risk `'medium`; gate behind a new mode
  capability.
- **`notify.send` tool.**  D-Bus via `notifications-notify`.  No
  existing wiring (see CHANGELOG / earlier finding).
- **Self-edit mode.**  Mode allowlist is `proposal.stage` only;
  `:auto-apply 'none`.  Output handler writes staged elisp patches
  into `~/notes/satan/proposals/` with `.patch.org` content.
- **Wire `satan.nix` into Sleipnir.**  Add
  `homeModules.satan` to the `imports` list in
  `~/flakes/modules/home/Sleipnir.nix`.  Then `home-manager switch`.
  Verify with `systemctl --user list-timers` showing `satan-morning`
  and `satan-motd`.  Make sure `emacsclient` resolves to a running
  Emacs (the user starts the server from `init.el` — service is
  disabled per AGENTS.md).

## Verification commands

```sh
# Build the jailed fake harness.
nix build .#satan-jailed-fake-harness --no-link --print-out-paths

# Standalone protocol test (no Emacs).
JAIL=$(nix build .#satan-jailed-fake-harness --no-link --print-out-paths)/bin/jailed-satan-fake-harness
mkdir -p /tmp/satan-smoke && SATAN_RUN_ID=smoke SATAN_RUN_DIR=/tmp/satan-smoke \
  "$JAIL" <<< '{"type":"tool_result","id":"c1","ok":true,"result":{"content":""}}'

# Unit tests.
emacs --batch -L core -L lisp -L org -L satan -L satan/test \
  -l satan/test/dl-satan-test.el -f ert-run-tests-batch-and-exit

# End-to-end ert.
JAIL=$(nix build .#satan-jailed-fake-harness --no-link --print-out-paths)/bin/jailed-satan-fake-harness
SATAN_TEST_JAIL_BIN=$JAIL emacs --batch -L core -L lisp -L org -L satan -L satan/test \
  -l satan/test/dl-satan-integration-test.el -f ert-run-tests-batch-and-exit

# Audit a real run.
emacsclient --eval '(dl-satan-audit-verify-run "/home/david/notes/satan/runs/<RUN-ID>/")'
```

## Open questions for phase 2

- Should `dl-satan-context-morning` include `org-roam` backlinks for
  unresolved-loop items?  Currently just dumps today's note text +
  prompt.
- Memory candidate review UI — Magit-style status buffer of
  `proposals/` plus `M-x my/satan-review-proposals` that opens each
  and offers (a)pply/(r)eject/(s)nooze?  Phase 1 ships proposals as
  raw denote files; review is `find-file`.
- Tool-call budget: currently denies after threshold by sending
  `ok=false`.  Better UX maybe to send a `system` log message and let
  the harness wind down to a `final`.
