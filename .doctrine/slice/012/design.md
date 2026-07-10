# SL-012 Design: Extract SATAN to standalone Elisp package

## Decisions

### D1 — Repository boundary

Target: `/workspace/satan/` (mounted rw in the jail; `~/dev/satan` on host, also
ro-mounted into the jail for uniform path resolution).

**Everything moves:**

| Source (`.emacs.d/`) | Destination (`/workspace/satan/`) |
|---|---|
| `satan/*.el` (64 files) | `satan/*.el` (symbols renamed) |
| `satan/test/*.el` (61 files) | `satan/test/*.el` |
| `satan/harness/` (Python) | `satan/harness/` |
| `satan/bin/` (4 scripts) | `satan/bin/` |
| `satan/memory/` (SQL migrations) | `satan/memory/` |
| `satan/protocol/` (JSONL fixtures) | `satan/protocol/` |
| `satan/patterns.eld` | `satan/patterns.eld` |
| `docs/satan/**` | `docs/**` (flattened) |
| `bin/elisp-locate-paren-error` | `bin/` (**copy** — config keeps its own; D7) |
| `dev/dl-test.el` | `dev/satan-test.el` (**copy**, parameterised; D7) |

**What stays in `.emacs.d/`:**
- `.doctrine/**` (SL-002..SL-011, DE-001..DE-010) — historical records
- `.doctrine/slice/012/**` — this slice's governance
- `.spec-driver/policies/POL-001-*` — policy remains

**No `.doctrine/` bootstrap in the satan repo** for this slice. Deferred follow-up.

**Destination scaffold already exists.** `/workspace/satan/` holds an empty
`justfile`, empty `src/` and `test/` dirs, and a copied `.emacs.d` flake
(description still "flake for doing emacs"). Cleanup is in scope: delete the
leftover `src/`/`test/` dirs, fix the flake description, replace the empty
justfile per D7.

### D2 — Layout: preserve `satan/` directory

The load-path entry is the satan repo root, so `.el` files live in `satan/`
subdirectory (unchanged structure). This avoids structural refactoring.

### D3 — Rename sweep

| From | To | Scope |
|---|---|---|
| `dl-satan-*` symbols | `satan-*` | All `.el` + `test/*.el` |
| `dl-satan` (provide/feature) | `satan` | Entry point `satan/satan.el` |
| `dl-satan-db-*` | `satan-db-*` | Internal — same module, new prefix |
| `my/satan-*` interactive | `satan-*` | Package-owned commands |
| `my/op-read-env` | **unchanged** | External soft dep (`dl-secret`) |
| `my/journal--*` | **unchanged** | External soft dep (journal) |
| `(require 'dl-satan)` in init.el | `(use-package satan …)` | Consumer |
| `dl-satan-*` in doctor.el | `satan-*` via `declare-function` | Consumer |
| `(require 'dl-notes-paths)` in 6 files | dropped | Replaced by `satan-notes-root` |

All `satan/bin/*` scripts: update emacsclient `--eval` function names (`my/satan-run` → `satan-run`, etc.).

Docs (`docs/satan/**`) — regenerate or update. Sample paths and symbol names
embedded in prose should reflect new naming. Do not rewrite entire docs; use
search-replace for mechanical name changes, hand-edit where context demands.

Harness Python (`satan/harness/`) — no rename. References SATAN env vars
(`SATAN_RUN_ID`, etc.) which are wire-level, not symbol names.

### D4 — Coupling: `dl-notes-paths` → defcustoms

**Actual coupling surface (verified 2026-07-10):** **10 files** require
`dl-notes-paths` (`context, mode, motive, patch-prompt, tools-atsatan,
tools-hippocampus, tools-inbox, tools-notes, tools-org, tools`), using **4
symbols**: `dl-notes-root` (22×), `dl-notes-journal-dir` (3×),
`dl-notes-weekly-dir` (1×), `dl-notes-inbox-file` (1×).

Two new surfaces in the satan package (`satan/satan.el` or dedicated
`satan/satan-custom.el`):

```elisp
(defcustom satan-notes-root "~/notes"
  "Root directory of the notes corpus.
SATAN derives owned paths as ${satan-notes-root}/satan/...
and standard corpus paths (journal/, weekly/, inbox.org) below it."
  :type 'directory
  :group 'satan)

(defcustom satan-journal-today nil
  "Zero-arg function returning today's journal file path, or nil.
When non-nil, SATAN calls this to include today's journal in
context assembly.  The function must ensure the file exists
before returning its path."
  :type '(choice (const :tag "None" nil)
                 function)
  :group 'satan)

(defun satan-notes-path (&rest segments)
  "Join SEGMENTS below `satan-notes-root'."
  ...)
```

**Path derivation, not more defcustoms.** The non-root symbols are derived
from `satan-notes-root` at the use sites via `satan-notes-path`:

| Old symbol | Replacement |
|---|---|
| `dl-notes-root` | `satan-notes-root` |
| `dl-notes-journal-dir` | `(satan-notes-path "journal")` — where not absorbed by `satan-journal-today` |
| `dl-notes-weekly-dir` | `(satan-notes-path "weekly")` |
| `dl-notes-inbox-file` | `(satan-notes-path "inbox.org")` |

This couples satan to the standard corpus layout under the root — accepted:
satan already assumes `${root}/satan/...` layout for its owned paths, and one
knob beats five. If a consumer ever needs a divergent layout, promote the
specific path to a defcustom then.

Consumer wiring in `.emacs.d/init.el`:

```elisp
(use-package satan
  :custom
  (satan-notes-root "~/notes")
  (satan-journal-today
   (lambda ()
     (my/journal--ensure-today)
     (my/journal--today-file dl-notes-journal-dir "journal"))))
```

The 10 files drop `(require 'dl-notes-paths)`; journal-today references
(`dl-satan-context.el`, `dl-satan-tools-org.el`) use
`(funcall satan-journal-today)` when non-nil.

Weekly journal (`dl-satan-tools-org.el` line 51: `my/journal--week-file`) is a
second journal surface. Deferred — keep the soft `declare-function` pattern for
now (its dir argument becomes `(satan-notes-path "weekly")`). If satan needs
richer weekly awareness later, add `satan-journal-week`.

### D5 — Load-path wiring

`core/dl-path.el` changes:

```elisp
;; Before
(defvar my/lisp-dirs
  '("lisp" "core" "editing" "completion" "apps" "org" "dev" "lang" "satan")
  ...)

;; After
(defvar my/lisp-dirs
  '("lisp" "core" "editing" "completion" "apps" "org" "dev" "lang")
  ...)

(defvar my/checkout-lisp-dirs
  '("checkout" "elpa/org-timeblock" "~/dev/satan/satan")
  ...)
```

This puts satan on the load-path alongside other external checkouts, before
`init.el` runs. The `use-package satan` form needs no `:load-path`.

### D6 — flake.nix updates

**`/workspace/satan/flake.nix`** (the satan repo):
- Harness source `./satan/harness` resolves after `satan/` is moved in — no change
- Strip config-specific jail definitions (pi, opencode, claude, dirge)
- Keep: `satanFakeHarness`, `satanGptelHarness`, jailed wrappers, `bubblewrap`
- Devshell: keep `postgresql_18`, `supabase-cli`, `emacsclient-commands`, `just`, `doctrine`

**`/workspace/flakes/modules/home/satan.nix`** (host systemd units):
- `ExecStart` paths: `%h/.emacs.d/satan/bin/` → `%h/dev/satan/satan/bin/`
- Function names in wrapper scripts updated per D3

**`/workspace/.emacs.d/flake.nix`** (the config repo — was wrongly assumed
untouched):
- Builds `satanGptelHarness` from `src = ./satan/harness` (line ~156) — breaks
  the moment `satan/` moves. Remove.
- Also defines `satanFakeHarness`, `satanJailOptions` (jail binds + `SATAN_*`
  env), and jailed wrappers. These are exactly what D6 keeps in the satan repo
  flake — they move OUT of the config flake; any config-flake consumers of
  those outputs repoint to the satan repo flake or are removed.
- The jail bind `--bind "$HOME/dev/satan" "/workspace/satan"` already exists
  there (marked `## Migration !!`) — see OQ-1/D8.

**Other flakes unchanged.** The emacs module (`pub/emacs.nix`) doesn't mention
satan. Daemon modules (`satan-attrd.nix`, `satan-patcher.nix`) reference their
own repos unchanged.

### D7 — Test infrastructure

**`.emacs.d/`** — `dev/dl-test.el` drops `satan/test` from `dl-test-suite-dirs`.
`just check` no longer runs satan tests.

**Test runner moves with the tests.** A naive `mapc load-file test/*.el` recipe
regresses on behaviour `dev/dl-test.el` already owns: (a) suites that `require`
a sibling for fixture macros get loaded twice → ERT "redefined (or loaded
twice)" batch errors — dl-test skips already-`featurep`d files; (b) the
production-socket refusal preflight (no `SATAN_DB_HOST` /
`SATAN_FAILOVER_TO_SYSTEM_DB` in batch → loud error before loading any test).
So: copy `dev/dl-test.el` into the satan repo as `dev/satan-test.el`, suite
dirs parameterised to `'("satan/test")`, symbols renamed per D3. The config's
`dl-test.el` keeps `lisp/test` only. Deliberate clone — the repo boundary is
the DRY boundary now.

**Linter script:** `bin/elisp-locate-paren-error` lives in `.emacs.d/bin/` and
is not in the D1 move table. Copy it into the satan repo's `bin/` (self-
contained script; config keeps its own copy).

**`/workspace/satan/`** — `justfile` (replaces the empty scaffold one):

```justfile
check: lint test

lint:
    #!/usr/bin/env bash
    set -euo pipefail
    for f in satan/*.el; do
        bin/elisp-locate-paren-error "$f"
    done

test:
    #!/usr/bin/env bash
    set -euo pipefail
    emacs --batch -L ./satan -L ./dev \
      -l satan-test --eval "(satan-test-run-batch)"
```

No `SATAN_DB_HOST` default baked into the recipe — the runner's preflight
fails loud without it, matching the existing refusal pattern
(`mem.fact.satan.test-db-isolation`; `dl-satan-db.el` additionally guards the
production socket in batch).

PSQL/supabase: the satan repo's devshell already provides `postgresql_18` and
`supabase-cli`. Tests that need a DB self-isolate via the existing
`SATAN_DB_HOST` pattern; suites skip DB tests when the DB is unreachable.

### D8 — flake mount paths (jail)

The host does `~/dev/satan` → jail at `/workspace/satan` (rw) and `~/dev/satan` (ro).
This lets both `/workspace/satan/satan` and `~/dev/satan/satan` resolve in the
jail. `dl-path.el` uses `~/dev/satan/satan` which works everywhere.

Implementation: add a ro bind mount for `~/dev/satan` in the jail's flake config
OR a symlink on the host (`~/dev/satan → /workspace/satan`). Exact mechanism
determined during phase planning. Note the rw bind
`$HOME/dev/satan → /workspace/satan` already exists in `.emacs.d/flake.nix`
(marked `## Migration !!`); only the `~/dev/satan`-shaped path is missing
inside the jail.

### D9 — Ordering: SL-011 lands first

`slice-012.toml` carries `after = SL-011`. SL-011 (SATAN tick performance:
observe and bound) is still in design and adds new surface into the same tree
this slice moves and renames: `dl-satan-trace.el`, `dl-satan-trace-call`, five
timeout defcustoms, tick/subprocess JSONL trace rows.

**Contract:** SL-011 is implemented and closed before SL-012 execution begins.
The rename sweep is glob-driven (`satan/*.el`, `rg 'dl-satan-'`), not
count-driven, so it absorbs SL-011's new module mechanically — no design
change here, but file/test counts cited in this document are design-time
snapshots, not gates. If SL-011 is descoped or stalls, `/consult` before
reordering: running SL-012 first invalidates SL-011's design (paths, symbol
names) and forces its rewrite.

## Current vs target behaviour

**Before:**
- `init.el` → `(require 'dl-satan)` loads from load-path (satan/ dir via `my/lisp-dirs`)
- SATAN is a subdirectory of the config, not a package
- Symbols: `dl-satan-*`, interactive: `my/satan-*`
- Hard requires `dl-notes-paths`

**After:**
- `dl-path.el` adds `~/dev/satan/satan` to `my/checkout-lisp-dirs`
- `init.el` → `(use-package satan :custom …)`
- SATAN is a standalone package in its own repo
- Symbols: `satan-*`, interactive: `satan-*`
- Two defcustoms (`satan-notes-root`, `satan-journal-today`) replace `dl-notes-paths`

## Verification

- `just check` green in `.emacs.d` (lisp tests, doctor checks)
- `just check` green in `/workspace/satan` (full ERT suite — count unpinned per
  D9, lint, byte-compile)
- `dl-sleipnir-doctor` SATAN checks pass (mode registry, budget, memory DB, sensors, patch)
- Symbol rename complete:
  - `rg 'dl-satan-' satan/` empty in satan repo
  - `rg 'my/satan-' satan/` empty in satan repo
  - `rg 'dl-satan-'` zero hits in `.emacs.d` outside `.doctrine/`, `.spec-driver/`, `CHANGELOG.md`
- `M-x satan-run RET morning` works from Emacs
- `satan/bin/*` scripts work (emacsclient calls resolve new function names)
- Byte-compilation clean — `emacs --batch -L ./satan --eval "(batch-byte-compile)" satan/*.el`
- `~/.config/git/hooks/post-commit` symlink resolves (re-linked to
  `~/dev/satan/satan/bin/satan-git-post-commit`) and a test commit appends a
  segment row
- `.emacs.d` flake evaluates (`nix flake check` or equivalent) after satan
  outputs removed

## Risks

- **Test regressions across repo boundary.** satan tests currently run in-process
  with the full config. After extraction they run in batch with only satan on
  the load-path. Some tests may implicitly depend on config-level setup
  (defcustoms, helper functions). Mitigation: run satan test suite in isolation
  early, fix leaks. Phase exit criterion: `just check` green in the satan repo.
- **flakes breakage.** The satan repo's flake was copied, not exercised. Harness
  build may fail until paths settle. Mitigation: flake build is separate phase
  with its own VT gate.
- **Bin scripts call emacsclient.** If Emacs server isn't running or the package
  isn't loaded, `satan-run` fails. Existing behaviour unchanged.
- **Rename completeness.** One missed `dl-satan-` reference in a require form
  breaks loading. Verification gate: `rg 'dl-satan-' satan/` returns empty in
  the satan repo.
- **`satan/bin/satan-git-post-commit`** may reference `.emacs.d/satan/` paths
  internally. Audit during implementation.
- **Global git hook symlink breaks on move.**
  `~/.config/git/hooks/post-commit → ~/.emacs.d/satan/bin/satan-git-post-commit`
  is manual machine setup (global `core.hooksPath`); the move invalidates the
  target and silently kills the git-activity sensor feed. Mitigation: re-link
  step in the move phase + verification line above.
- **Memory corpus / boot snapshot staleness.** 17 memory files reference
  `dl-satan-*` symbols or `.emacs.d/satan` paths; the boot sector's SATAN
  orientation says code lives in `~/.emacs.d/satan/`. Docs-update scope covers
  `docs/satan/**` only. Mitigation: `/reviewing-memory` pass + boot-sector
  re-seat as a closure step (see Follow-ups).

## Follow-ups

- `/reviewing-memory` pass over the 17 satan-referencing memories + boot-sector
  re-seat (`doctrine reseat` / `infra boot`) once the move lands — paths and
  symbol names in the corpus go stale at merge.

## Open questions

1. **Flake jail mount mechanism.** How exactly to ensure `~/dev/satan` resolves
   in the jail. The rw bind `$HOME/dev/satan → /workspace/satan` already exists
   in `.emacs.d/flake.nix`; missing piece is a `~/dev/satan`-shaped path inside
   the jail. Options: (a) add second ro bind in flake, (b) host-side symlink.
   Decision deferred to phase planning — verify during implementation.
2. **`satan-journal-today` vs per-mode journal access.** Current code uses
   `my/journal--today-file` in context assembly and `my/journal--week-file` in
   `tools-org`. The defcustom covers today; weekly is YAGNI for now. Add when
   needed.
3. **`patterns.eld` data file.** Does it contain any `dl-` or `my/` keys that
   need renaming? Verify during implementation; likely no (it's SATAN-internal
   data, not symbol references).
