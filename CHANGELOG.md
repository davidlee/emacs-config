# Changelog

Notable changes to this Emacs config. Loosely dated; not versioned.

## 2026-05-19 — SATAN: real LLM harness (phase-2 A)

Replaces the phase-1 fake harness with `satan-gptel-harness`, an
OpenAI-compatible chat-completions driver (OpenRouter v1 by default).
The harness is provider-agnostic via a `Provider` abstract base — keys
and model id come from env (`SATAN_PROVIDER`, `SATAN_MODEL`,
`<PROVIDER>_API_KEY`).  Future providers (Anthropic direct, OpenAI,
DeepSeek, Pi/Zerostack) plug in by implementing `Provider.complete`.

- `satan/harness/gptel_harness.py` — main harness.  Termination signal
  is a `satan.final(summary, actions[])` tool call; adapter intercepts
  it and emits the broker's `final` record.  Plain-content responses
  with no tool calls are coerced into a final with
  `reason=no_tool_calls`.
- Budget: harness tallies `prompt_tokens + completion_tokens` reported
  by the provider; emits per-turn `log` events with cumulative usage;
  graceful self-termination via synthetic `final` with
  `reason=budget_tokens` once a turn crosses
  `SATAN_BUDGET_TOKENS`.  Broker's existing `:budget-tool-calls` +
  `:timeout-seconds` remain the backstops.
- `satan/harness/test_gptel_harness.py` — five unit tests covering the
  termination paths, budget exhaustion, and tool-call filtering.
  Stdlib `unittest`; no network.
- `flake.nix` — `satanGptelHarness` (`writePython3Bin` with
  `python3Packages.openai`), `satanGptelJailOptions` (forwards
  `SATAN_PROVIDER`/`SATAN_MODEL`/`SATAN_BUDGET_TOKENS` + four provider
  key vars), `satan-jailed-gptel-harness` (profile `specDev` for
  network).
- `dl-satan-broker.el` — `dl-satan-broker-provider-key-vars` map;
  resolves `op://` refs via `my/op-read-env` at spawn (condition-case
  so a locked 1Password doesn't crash the run); forwards
  `SATAN_PROVIDER`/`SATAN_MODEL`/`SATAN_BUDGET_TOKENS` + selected key
  into the child env.
- `dl-satan-mode.el` — `morning` and `motd` now drive
  `jailed-satan-gptel-harness` against `anthropic/claude-haiku-4.5` via
  openrouter.  Budgets: morning 20k tokens / 8 tool calls / 90s wall;
  motd 5k tokens / 4 tool calls / 45s wall.
- `satan-jailed-fake-harness` retained as the test fixture for the
  existing integration ert.
- Smoke: 15/15 unit ert + 1/1 integration ert + 5/5 python unittest
  green.  Standalone protocol smoke against real openrouter confirms
  `ready` emission, network reach, error path clean.

## 2026-05-19 — SATAN: broker + JSONL protocol + jailed fake harness

Phase-1 of the SATAN local agent runtime (see `SATAN.local.md`).  Emacs
is the broker and capability authority; a bubblewrap-jailed child
process is the harness; they exchange newline-delimited JSON over
stdin/stdout; only the broker mutates durable state.

- `satan/` — new module bucket.
  - `dl-satan-jsonl.el` — line-buffered filter + writer.  `json-serialize`
    rejects bare lists, so `dl-satan-jsonl-prepare` walks payloads and
    coerces non-plist lists to vectors.
  - `dl-satan-block.el` — find/replace owned org blocks of the form
    `#+begin_satan :block NAME :owner SATAN :updated [...]` /
    `#+end_satan`.  Refuses multi-match; creates-at-end on none-match.
  - `dl-satan-audit.el` — append-only writer for
    `runs/<run-id>/{manifest,bundle,transcript,final,actions,status}`
    plus a six-predicate verifier that proves the
    `SATAN.local.md:601-616` auditability invariant.
  - `dl-satan-tools.el` + `dl-satan-tools-org.el` — registry, allowlist
    + schema check, three handlers (`org.read_context`,
    `org.update_owned_block`, `proposal.stage`).
  - `dl-satan-mode.el` — `morning` and `motd` mode-specs.
  - `dl-satan-context.el`, `dl-satan-output.el` — context assembler +
    handlers.
  - `dl-satan-broker.el` — `make-process` driver: line-buffered filter,
    timeout timer, tool-call dispatch, sentinel runs output handler.
  - `dl-satan.el` — `my/satan-run MODE` interactive entry.
  - `satan/bin/satan-run` — shell wrapper for systemd/cron via
    `emacsclient --eval`.
  - `satan/test/*.el` — 15 unit tests + 1 end-to-end integration test
    against the real jailed binary (skips unless `SATAN_TEST_JAIL_BIN`
    is set).
- `flake.nix` — adds `satan-jailed-fake-harness` derivation built via
  `pkgs.writers.writePython3Bin`, profile = `offline`.  Jail mounts
  `~/notes` read-only at `/satan/notes` and
  `~/notes/satan/hippocampus` read-write at `/satan/hippocampus`.
  Forwards `SATAN_RUN_ID`, sets `SATAN_RUN_DIR=/satan/run` inside the
  jail.  Exposes `jailPkgs` as flake `packages` so the binary builds
  via `nix build .#satan-jailed-fake-harness`.
- `core/dl-path.el` — adds `satan` to `my/lisp-dirs` and
  `trusted-content`.
- `init.el` — `(require 'dl-satan)`.
- `~/notes/satan/{hippocampus,proposals,runs}/` — on-disk layout.
- `~/flakes/modules/home/satan.nix` — systemd user services and timers
  for `satan-morning` (07:30 daily) and `satan-motd` (07:00 daily).
  **Not** imported by `Sleipnir.nix` — staged for review.
- `~/flakes/modules/home/emacs.nix` — adds `satan` to `configDirs` so
  the Nix wrapper's use-package parser scans the bucket.

Phase-1 non-goals: real model harness adapter (fake only), memory
candidate review UI, ROM management beyond a static prompt file, the
`self_edit` mode, network egress filtering, multi-step tool-call
reasoning loops, D-Bus notifications.

## 2026-05-18 — secrets: 1Password resolution + zsh env sourcing

API keys move out of plaintext on disk. `~/.config/zsh/env.zsh` now
holds `op://vault/item/field` refs instead of secret strings; resolution
happens on demand.

- `lisp/dl-secret.el` — three concerns merged into one module:
  - `my/op-read` / `my/op-read-env` — resolve refs via 1Password CLI,
    session-cached; `my/op-forget` clears the cache.
  - `my/auth-source-secret` — generic wrapper around
    `auth-source-search` (lambda-secret + utf-8 handling).
  - Auto-sources `~/.config/zsh/env.zsh` at load (only sets vars that
    are currently unset, so terminal-launched Emacs keeps resolved
    values).
- `apps/dl-gptel.el` — OpenRouter backend switched to
  `(lambda () (my/op-read-env "OPENROUTER_API_KEY"))`. Lambda form
  re-resolves per request; no stale-pin risk.
- `AGENTS.md` — new "Secrets and env vars" section documents the
  resolution path and the dl-secret API.

Sway-launched Emacs (which never runs zshrc) now sees the same API
keys as a terminal session, without any keys touching disk.

## 2026-05-18 — crash diagnostics: stderr wrapper + SIGUSR2 backtrace

Gui locked + all frames vanished while editing an org buffer; no
coredump, no journal entry. Fuzzel-spawned pgtk emacs has stdout/stderr
pointed at `/dev/null`, so wayland/compositor disconnects and late
fatal messages were unrecoverable.

- `~/.local/bin/emacs-logged` — launcher wrapper, `exec emacs "$@"`
  with stderr appended to `~/.local/state/emacs/stderr.log`; previous
  session rotated to `stderr.log.1` on each start. Header line records
  timestamp + pid + args.
- `~/.local/share/applications/emacs.desktop` — local override (XDG
  precedence over Nix) so fuzzel routes through the wrapper.
- `init.el` — `(setq debug-on-event 'sigusr2)`; `pkill -USR2 emacs`
  during a freeze drops into the debugger with a backtrace.

Files live outside the repo (state + XDG launcher dirs); noted here so
future-me knows where to look.

## 2026-05-18 — org faces scale with text-scale; new-frame bg syncs to theme

`core/dl-faces.el` — org heading/code faces moved to float `:height`
multipliers and table-driven via new `my/org-face-styles` (levels 1-8 +
title + block/code/verbatim). C-mousewheel / `text-scale-adjust` now
scales them since float heights chain through `default`. `core/dl-theme.el`
— `my/sync-frame-colors-to-theme` on `enable-theme-functions` copies
current `default` bg/fg into `default-frame-alist`, so frames opened
after the bootstrap no longer inherit the `#000000` anti-flash colour
from `dl-interface.el`.

## 2026-05-17 — tier-2 lambda-emacs cherry-picks

Seven small commands lifted from lambda-emacs, cleaned up, slotted into
existing family maps:

- `my/toggle-window-dedicated` (`C-c w P`) — pin selected window to its
  buffer. Lambda's version had a `(let (window …))` typo that left
  `window` nil; rewritten against `selected-window`.
- `my/window-exchange-buffer` (`C-c w x`) — swap two windows' buffers
  via `ace-window`, focus stays put. Uses the already-installed
  `ace-window` (`editing/dl-motion.el`).
- `my/delete-current-buffer-file` (`C-c f K`) — delete file on disk +
  kill buffer (confirm). Lambda fell back to `ido-kill-buffer`;
  replaced with `kill-current-buffer` since ido isn't in play.
- `my/move-file` (`C-c f M`) — `write-file` then delete the old.
- `my/tmp-buffer` (`C-c b t`) — timestamped throwaway in the *current*
  major mode (lambda's version silently dropped to fundamental-mode
  despite the docstring).
- `my/unfill-paragraph` (`M-Q`) — Stefan Monnier's inverse of
  `fill-paragraph`, in `core/dl-prose.el`.
- `my/forward-or-backward-sexp` (`C-c j p`) — vim `%` style match-paren
  jump, in `editing/dl-motion.el`.

New file `lisp/dl-file-ops.el` for the two file commands (loaded from
`init.el`). Window / buffer / motion / prose commands appended to
existing module files. Bindings centralised in `core/dl-keymap.el`
under `my/bind`; KEYS.md updated for `f`, `b`, `w`, `j` sections.

Skipped from the candidate list: `lem-jump-in-buffer` (redundant —
`C-c o h` and `C-c s o` already cover it cleanly).

## 2026-05-17 — modernize last `defadvice`

`core/dl-core.el` — the pre-2.0 `defadvice` form on `find-file`
(`make-directory-maybe`) rewritten as a named defun
`dl-core--make-parent-directory-maybe` plus `(advice-add 'find-file
:before ...)`.  Behaviour-preserving; the latent
`(file-exists-p nil)` edge case (when `file-name-directory` returns
nil) is preserved as in the original.

## 2026-05-17 — naming policy + migration

Naming convention written into `AGENTS.md` (between "The four traps"
and "Common debugging commands"):

- `dl-MODULE` for file/`provide` symbols.
- `dl-MODULE-name` for module's public internals; `dl-MODULE--name` for
  private (defcustoms always module-owned).
- `my/name` for personal commands and their helper/variable families
  (`my/` propagates through the helper cluster even when the helpers
  live in a `dl-MODULE` file — role beats file).
- Grandfathered: `my-X-map` keymaps (`my/bind` + meow leader-mirror
  discover by this name) and `meow-setup` (meow docs require that
  exact function name).

Migration in two single-file passes:

- **`apps/dl-shpool.el`** — `my-shpool` defgroup and 5 defcustoms
  (`-command`, `-known-sessions`, `-restore-sessions`, `-auto-restore`,
  `-debug`) renamed to `dl-shpool-*`, plus all ~55 internal references
  (`replace_all`).  Orphan customize entry
  `(my-shpool-known-sessions ...)` removed from `custom-vars.el`.  A
  `(dl-shpool-known-sessions ...)` entry was already present under the
  target name; its value (`".emacs.d" "hris" "team" "claude"`) becomes
  the canonical saved list.  Two names from the old entry (`"flakes"`,
  `"example"`) dropped — re-add via M-x customize if you still use
  them; the cache auto-grows otherwise.
- **`lang/dl-nix.el`** — 5 `dl-nix/X` slash-prefix names renamed to
  `dl-nix-X` (`-flake`, `-nixos-host`, `-home-user`, `-nixd-config`,
  `-set-workspace-config`), plus internal references.  No customize
  state to migrate.

After this pass the codebase is policy-compliant.  `rg "my-shpool|dl-nix/"`
returns empty.

## 2026-05-17 — polish: named hooks, fold consolidation, shpool/interface tidy

Low-leverage polish from the review:

- **`apps/dl-magit.el`** — the anonymous lambda on `git-commit-mode-hook`
  (`(lambda () (ws-butler-mode -1))`) extracted to
  `my/git-commit-disable-ws-butler`.  Named hooks survive
  `.emacs.desktop` restore more cleanly and are easier to remove.
- **`editing/dl-fold.el`** — 36 bare `add-hook` calls (5 for
  `outline-minor-mode`, 15 for `hs-minor-mode`, 16 for
  `treesit-fold-mode`) consolidated into three `use-package` blocks
  with `:hook` lists (`outline`, `hideshow` — both built-in with
  `:ensure nil` — and `treesit-fold`).  ~50 lines down to ~25.
  Language-group structure preserved as inline comments inside the
  `:hook` argument.  The four commented-out kotlin/swift/elixir/zig
  hooks dropped; a one-line comment notes how to re-add.
- **`apps/dl-shpool.el`** — `my/shpool-attach-args` renamed to
  `my/shpool--attach-args` (`--` private prefix matches the rest of
  the file's namespace; only caller is `my/shpool--open`).
- **`core/dl-interface.el`** — `(mapc (lambda (hook) (add-hook ...)) ...)`
  over a `let`-bound hook list rewritten as a `dolist`.  Same effect,
  half the line count, no closure overhead.

The audit's claim about redundant `customize-save-variable` calls in
`dl-shpool.el` (lines 298–303 and 317–319) was wrong — re-reading both
functions, `my/shpool-add-current-to-restore` adds to *both*
`restore-sessions` and `known-sessions` so saving both is correct, and
`my/shpool-remove-from-restore` only touches `restore-sessions` and
only saves `restore-sessions`.  No change.

The note about `(use-package hydra :demand t)` in `core/dl-keybind.el`
being the only `:demand` in the file is informational only — it has to
be eager because downstream files (`dl-keymap.el`) reference the
`hydra-…/body' entry points generated by `defhydra`.

## 2026-05-17 — face scatter cleanup: all attrs in dl-faces.el

The two remaining face strays from the review's §7 ("face customization
belongs in dl-faces") moved.  Verified with rg: no `set-face-attribute`
/ `face-spec-set` / `custom-set-faces` / `:custom-face` outside
`core/dl-faces.el` (and the auto-generated `custom-vars.el`).

- `core/dl-meow.el` — the `dl-meow--apply-indicator-faces` defun, its
  call from meow's `:config`, and the `enable-theme-functions` add-hook
  all gone.  Replaced in `core/dl-faces.el` by `my/apply-meow-indicator-faces`
  (renamed for `my/apply-X-faces` consistency) under a
  `(with-eval-after-load 'meow ...)` block that does the call + hook
  wiring once meow loads.  `defface dl-meow-indicator-inactive` and
  `dl-meow-indicator` stay in dl-meow — those are package scaffolding
  (face *definition* + modeline helper), not customization.
- `editing/dl-fold.el` — the `set-face-attribute 'treesit-fold-replacement-face`
  block from treesit-fold's `:config` moved to a
  `(with-eval-after-load 'treesit-fold ...)` block in dl-faces.

## 2026-05-17 — visual layer: dl-font → dl-faces, dl-interface slimmed

Two questions the audit raised about `core/dl-font.el` and `core/dl-interface.el`:
**(a)** the file named "fonts" was actually the universal face-customization
hub (font roles + every `set-face-attribute` in the codebase); **(b)**
dl-interface had become a kitchen sink (startup chrome + global modes
+ window helpers + popup tamers + scroll-key overrides, all in one
file).  Resolved both.

**`dl-font.el` → `dl-faces.el`** — `git mv` rename; `provide`/`require`
and file header updated.  `init.el:12` follows.  The file's content is
unchanged structurally, just better-named.

**`my/apply-fonts` now fires at startup and on theme rotation.** It was
defined but never called at the top level — fonts were coming from
whatever the theme set, and manual `M-x my/apply-fonts` was the only
path to your role/height/weight customizations.  Added a top-level
`(my/apply-fonts)` plus `(add-hook 'enable-theme-functions
#'my/apply-fonts)`.  Function signature now `(&rest _)` so it slots
directly onto the hook (same shape as `dl-meow--apply-indicator-faces`,
the only other face-applier with a theme-reload hook).

**`dl-interface.el` split (approach A from the design pass)**:

- `split-and-follow-horizontally` / `split-and-follow-vertically`,
  `(use-package transpose-frame ...)`, and `(winner-mode 1)` moved to
  `lisp/dl-window.el` where the rest of the window helpers live.  The
  stale comment at the top of dl-window pointing back to dl-interface
  is updated.
- `(use-package shackle ...)` and `(use-package popper ...)` extracted
  to new `core/dl-popups.el`.  Sibling of dl-interface; required in
  init.el right after it.
- `(global-set-key (kbd "C-v") ...)` / `M-v` (the View-half-page
  overrides) and the `(require 'view)` they need moved to
  `core/dl-keybind.el` next to the other ergonomic chord bindings.

After the split dl-interface owns just chrome + frame + global display
modes + per-mode hooks + the remaining package wrappers
(`spacious-padding`, `diminish`, `nerd-icons` + `nerd-icons-completion`,
`beacon`, `breadcrumb`) — coherent.

**Incidentals along the way**:

- Typo `(use-short-anwswers t)` in dl-interface's `:custom` removed
  (set a phantom variable; the correctly-spelled `use-short-answers`
  is already in `dl-core.el`).
- Duplicate top-level `(global-prettify-symbols-mode t)` removed; the
  `:custom` line earlier in the same use-package block already enables
  it.

**Touched:** `init.el`, `core/dl-faces.el` (renamed from `dl-font.el`),
`core/dl-popups.el` (new), `core/dl-interface.el`, `core/dl-keybind.el`,
`lisp/dl-window.el`.  `home-manager switch` required (new file).

## 2026-05-17 — quality review: trivial fixes + lazy-loading + eglot consolidation

Sweep audit (`REVIEW.md` for the full report).

**Trivial fixes** — `init.el` duplicate `(require 'dl-term)` removed; 4 dead commented `set-face-attribute` / `set-frame-font` lines deleted. Save-time bug closed in `editing/dl-persist.el`: `my/eglot-format-buffer-if-connected` was wired both buffer-local (via `my/eglot-on-save-setup`) and globally on `before-save-hook`, firing twice in eglot buffers — global add removed. Orphan `<f9>` binding next to `toggle-maximize-buffer` in `lisp/dl-buffer-management.el` removed; same binding already lives in `core/dl-keybind.el`. Duplicate `with-eval-after-load 'org` face block in `core/dl-font.el` removed — `my/apply-fonts` already calls `my/apply-org-faces`. `completion/dl-vertico.el` file header said `dl-orderless.el`; fixed. Redundant `(use-package savehist :init (savehist-mode))` in `dl-vertico.el` dropped — `dl-completion.el` enables savehist earlier in init order.

**Lazy-loading** — `org/dl-org.el`: `use-package org` now defers via `:mode "\\.org\\'"`; the bare top-level `(setq ...)` block (which duplicated `org-startup-indented` and `org-hide-emphasis-markers` already in `:custom`) folded into `:custom`. `org-bullets-bullet-list` moved into `org-bullets`' own `:custom` and the package now defers via `:hook (org-mode . org-bullets-mode)`. The anonymous margin/hl-line lambda in `org-mode-hook` extracted to `my/org-setup-margins` (named hooks survive `.emacs.desktop` restore more cleanly).

`apps/dl-eaf.el`: `:demand t` removed from all four packages. `eaf` itself now declares `:commands (eaf-open eaf-open-browser eaf-open-pdf-viewer eaf-open-image-viewer)`; the apps keep `:after eaf` so load order is preserved when an entry command pulls eaf in. Largest single startup-time win in this pass.

**Eglot consolidation** — `my/eglot-connected-p`, `my/eglot-format-buffer-if-connected`, `my/eglot-organize-imports-if-connected`, and `my/eglot-on-save-setup` moved from `editing/dl-persist.el` to `dev/dl-eglot.el`. `editing/dl-persist.el` is now strictly *session* persistence (file revert + autosave + undo-fu). The organize-imports hook was previously global on `before-save-hook` (firing on every save, no-op outside eglot buffers); it now installs buffer-local via `my/eglot-on-save-setup`, mirroring the format-buffer pattern. `lang/dl-nix.el`: the eager `(use-package eglot :config (add-to-list 'eglot-server-programs ...))` (which pulled eglot at startup) replaced with `with-eval-after-load 'eglot`; nixd registration now waits until eglot actually loads.

**Use-package dedup** — Four duplicate `use-package` forms removed:

- `(use-package dired ...)` in `apps/dl-dirvish.el` deleted; identical settings already in `apps/dl-dired.el`.
- `(use-package diredfl ...)` in `editing/dl-project.el` deleted; canonical home is `apps/dl-dired.el`.
- `(use-package markdown-mode ...)` in `lang/dl-lang-common.el` deleted; its `visual-line-mode` hook lifted into the existing form in `lang/dl-markdown.el`.
- `(use-package nerd-icons :defer t)` in `apps/dl-dired.el` deleted; canonical home is `core/dl-interface.el` (which also configures `nerd-icons-completion`).

**Overlapping `(use-package emacs ...)` blocks** — The block in `completion/dl-vertico.el` was a pure duplicate: `context-menu-mode` was already enabled in `core/dl-interface.el:111`, and `enable-recursive-minibuffers` / `read-extended-command-predicate` were already in `completion/dl-completion.el`. The one genuinely cross-cutting setting, `minibuffer-prompt-properties` (locks cursor out of the prompt — applies beyond vertico), lifted into `dl-completion.el`. Block removed.

`editing/dl-project.el`'s `(use-package emacs ...)` block had nothing to do with projects: `major-mode-remap-alist` (treesitter remap) moved to `dev/dl-treesit.el` next to `treesit-auto`; the remaining `:hook ((prog-mode . electric-pair-mode))` collapsed to a top-level `add-hook`. Block removed.

**Buglet** — `completion/dl-completion.el` had `(keymap-set minibuffer-mode-map "TAB" 'minibuffer-complete)` inside its `:custom` block, where the form was treated as `(VAR=keymap-set VALUE=minibuffer-mode-map ...)` and never actually bound TAB. Moved into a proper `:bind (:map minibuffer-mode-map ...)` clause.

After this pass, the seven remaining `(use-package emacs ...)` blocks each own a coherent domain: `dl-core` (defaults), `dl-backup` (backup), `dl-interface` (UI), `dl-persist` (auto-revert + history), `dl-completion` (minibuffer + completion), `dl-elisp` (elisp-mode), and the new minimal one in `dl-eaf` / N-A. No emacs-block lives in `dl-project` or `dl-vertico` anymore.

**Touched:** `init.el`, `core/dl-font.el`, `completion/dl-completion.el`, `completion/dl-vertico.el`, `editing/dl-persist.el`, `editing/dl-project.el`, `lisp/dl-buffer-management.el`, `lang/dl-markdown.el`, `lang/dl-lang-common.el`, `lang/dl-nix.el`, `org/dl-org.el`, `apps/dl-eaf.el`, `apps/dl-dired.el`, `apps/dl-dirvish.el`, `dev/dl-eglot.el`, `dev/dl-treesit.el`, `REVIEW.md` (new).

## 2026-05-17 — lambda-emacs lifts: meow polish, user-buffer cycling, window helpers

Three groups picked from `./lambda-emacs/` and `./meow.local.el`.

- **Meow `:custom` block** (`core/dl-meow.el`).
  Added `meow-use-cursor-position-hack`, `meow-use-clipboard`,
  `meow-goto-line-function = consult-goto-line`,
  `meow--kbd-delete-char = <deletechar>`, `<…>` registered as the
  `a` thing.  Terminal-disable hook renamed
  `my-disable-meow-in-terminal` → `dl-meow--disable-in-terminals`
  to match file convention; vterm `meow-mode-state-list` entry
  dropped (the hook does `(meow-mode -1)` which supersedes the
  state-list lookup and removes the indicator/cursor too).
  Lambda's magit cooperation block (put magit in normal state, unset
  `j`/`k`) was tried and reverted: forcing meow normal state in magit
  made meow's minor-mode keymap shadow magit's single-letter bindings
  (`s`, `c`, `l`, …); the `j`/`k` unset only frees those two.
  Correct shape if revisited is the vterm/ghostel pattern (disable
  meow entirely in `magit-mode` buffers).
- **User-buffer cycling** (`lisp/dl-buffer-management.el`).
  `my/user-buffer-p` filters `*…*` and dired buffers;
  `my/next-user-buffer` / `my/previous-user-buffer` skip past them.
  Bound at `C-c b n` / `C-c b p` (replacing raw next/previous-buffer)
  and mirrored to Meow leader `SPC [` / `SPC ]` for flick cycling.
  File header fixed (`.le` → `.el`); added `(require
  'dl-buffer-management)` to `init.el` (was unloaded — F9
  `toggle-maximize-buffer` was dead code).
- **Window helpers** (`lisp/dl-window.el` — new).
  - `C-c w s` / `w v` now `split-and-follow-{horizontally,vertically}`
    (existing defuns in `core/dl-interface.el`, previously unbound) —
    split and move point into the new pane.
  - `C-c w S` / `w V` keep the raw `split-window-{below,right}` for
    when you want focus to stay put.
  - `C-c w f` → `transpose-frame` (swap horizontal ⇄ vertical splits
    across the whole frame).  The transpose-frame package was already
    declared in `core/dl-interface.el` and bound at `C-x 7`; `w f`
    is the leader-friendly alias.  Strictly more general than the
    2-window-only flip I almost wrote — caught before merging.
  - `C-c w c` / `w C` → `my/rotate-windows[-backward]` (cycle buffers
    around non-dedicated windows; distinct from transpose, which
    rotates the layout).  `w r` is taken by the resize hydra, so
    rotate landed on `c` (cycle).

Deferred avenue documented in `KEYS.md`: nil-out
`meow-keypad-{meta,ctrl-meta,literal}-prefix` + `-start-keys` to
release `SPC g` / `SPC m` (currently aliased to `SPC G` / `SPC M`).
Not adopted — would lose Meow's `SPC c …` / `SPC x …` keypad
dispatchers and the literal-input escape.

**Touched:** `core/dl-meow.el`, `core/dl-keymap.el`,
`lisp/dl-buffer-management.el`, `lisp/dl-window.el` (new), `init.el`,
`KEYS.md`.

## 2026-05-17 — window-resize hydra (first defhydra)

`hydra-window-resize` lands at `C-c w r`.  Sticky modal: arrow keys
grow/shrink the selected window in the matching direction (`<right>`
wider, `<up>` taller, etc.), `=` balances, `q` exits.

Hydra was previously deferred (`use-package hydra :commands defhydra`)
with no actual hydras defined; promoted to `:demand t` so `defhydra`
is in scope when `dl-keymap.el` references the `…/body` entry point.
`declare-function` placeholder added in `dl-keymap.el` to silence the
byte-compiler "not known to be defined" warning during cold compile.

**Touched:** `core/dl-keybind.el`, `core/dl-keymap.el`, `KEYS.md`.

## 2026-05-17 — Policy lint + ready-player squatter

The deferred-sweep audit (entry below) cleared all `C-c <letter>`
Policy violations in tracked `.el` files, but uncovered one foreign-
package squatter the previous audits had missed.  A small lint keeps
it from coming back.

- **`ready-player` was silently owning `C-c m`.**  `ready-player-mode`
  installs a "Ready Player" keymap globally on activation, clobbering
  `my-term-map` after `dl-keymap.el` had bound it.  No `my/bind`
  warning fired because the install bypasses `my/bind`.  Fix:
  `(setq ready-player-set-global-bindings nil)` via `:custom` in
  `apps/dl-dired.el`.  Term family restored at `C-c m`.
- **`core/dl-policy-lint.el` — new.**  Walks `mode-specific-map` and
  reports any single-letter binding whose value isn't a `my-*-map`
  family map or a Policy-reserved singleton (`C-c a/c/l`).
  - `M-x my-policy-lint` pops `*Policy Lint*` with offending key +
    binding + reason (`foreign-map` / `foreign-command`).
  - Silent startup check via `emacs-startup-hook`: logs a single
    `*Messages*` line iff violations exist; never opens a buffer.
  - Catches what `my/bind`'s collision warning can't — foreign
    packages binding `C-c <letter>` from their own `:config`.

Required: a one-line `(require 'dl-policy-lint)` after
`(require 'dl-keymap)` in `init.el`.  Family allowlist
(`my-policy-lint-family-maps`) needs updating when a new tier-1
prefix lands.

**Touched:** `core/dl-policy-lint.el` (new), `core/dl-keymap.el`
(unchanged for lint), `apps/dl-dired.el`, `init.el`, `KEYS.md`.

## 2026-05-17 — keymap policy deferred sweep

Cleared the four remaining Policy stragglers from the previous audit.
After this pass, no `C-c <letter>` global bindings live outside
`core/dl-keymap.el`.

- **`C-c s q` / `s Q` — visual-regexp.**  `vr/query-replace` and
  `vr/replace` lifted out of `editing/dl-search.el` into the central
  search map.  Lowercase = interactive (common), uppercase = one-shot
  replace (less common).  Isearch chords `C-r` / `C-s` stay in
  `dl-search.el` (they shadow Emacs globals, not personal keys).
- **`C-c n r …` — roam compartment.**  Six org-roam bindings squatting
  on tier-1 `C-c r` moved into a `my-roam-map` sub-prefix under notes.
  Reflects Phase-1 reality: roam stays wired (db autosync, capture
  templates) but isn't the primary navigator.  If/when promoted back
  to a daily tool, lift out of the compartment.
- **`apps/dl-slack.el` global bindings deleted.**  Module currently
  uninstalled (`init.el:76`); the `C-c S …` family would have squatted
  on tier-1 `S` the moment slack returned.  Mode-local maps
  (`slack-mode-map` etc.) retained — those are package-owned.  Header
  comment in the file flags the next-time refactor requirement.
- **Doc rot trims.**  `(global-set-key (kbd "C-c h") …)` comment in
  `lisp/dl-insert-elisp-header.el` removed (`C-c h` is Policy-banned
  as the modal gateway).  Dead commented combobulate `use-package`
  block in `editing/dl-multi-edit.el` deleted (`combobulate-key-prefix
  "C-c o"` reference was stale; `C-c o` is now the Org map).

**Touched:** `core/dl-keymap.el`, `editing/dl-search.el`,
`org/dl-org-roam.el`, `apps/dl-slack.el`,
`lisp/dl-insert-elisp-header.el`, `editing/dl-multi-edit.el`,
`KEYS.md`.

## 2026-05-17 — keymap audit fixes

Audit pass against the freshly-Policy-ied keymap surfaced four real
bugs and one Policy violation; all addressed.

**Critical: `C-c s` was unreachable.** `dl-search.el` called
`(rg-enable-default-bindings)`, which does
`(global-set-key (kbd "C-c s") rg-global-map)` — silently replacing
`my-search-map` (whose 11 scope-ladder bindings I'd just centralised)
with rg.el's transient menu. Verified against the live session:
`C-c s` resolved to `rg-menu`; `C-c s s`/`s p` etc. were unbound.
Fix: drop `rg-enable-default-bindings`; expose `rg-menu` at `C-c s g`
in the central map. `consult-ripgrep` remains the common path at
`s r` / `s R` / `M-s r`.

**`C-c t B` double-bound.** `tab-line-mode` shadowed by
`global-tab-line-mode` (last-write-wins; `my/bind` collision warning
fired silently to `*Messages*` on every startup). Fix: `t B` =
buffer-local `tab-line-mode`, `t G` = `global-tab-line-mode`,
mirroring the existing `l`/`L` line-numbers pattern.

**Embark had no working keys.** `C-c a embark-act` was overwritten by
`org-agenda` (correct per Policy clause 6); `C-;  embark-dwim` was
overwritten by `dl-motion.el`'s `avy-goto-char-timer`. Both embark
verbs were silently dead. Fix: `C-, embark-act` and `C-' embark-dwim`.
Displaces `goto-last-change` and `avy-goto-char-2` from those chords.
`goto-last-change-reverse` stays at `C-.`; `avy-goto-char-2` rescued
to `C-c j 2`.

**`C-c j` Policy violation.** `dl-motion.el` had
`("C-c j" . avy-goto-line)` — a single binding squatting on a
top-level family letter from outside `dl-keymap.el`. Fix: new
`my-jump-map` at `C-c j` declared centrally (`j j` line, `j c` char
timer, `j 2` 2-char, `j w` word). Chord bindings `C-:` / `C-;` in
`dl-motion.el` retained as escape hatches.

**Touched:** `core/dl-keymap.el`, `completion/dl-embark.el`,
`editing/dl-motion.el`, `editing/dl-search.el`, `KEYS.md`.

Deferred (Policy violations not swept this pass): `C-c q r` /
`C-c q q` visual-regexp in `dl-search.el` (not lifted central);
`C-c r …` org-roam (CHANGELOG previously flagged as "wired but
unused" — candidate for deletion next pass); `C-c S …` slack (the
whole module is currently disabled at `init.el:76`).

## 2026-05-17 — keymap policy + tier-1 families fleshed out

Written keybinding policy in `KEYS.md` (three-tier grammar — family
prefix at `C-c <letter>`, lower/upper variants within a family,
capital sub-prefixes for compartments), four previously-thin/empty
maps populated, project promoted to a parallel family.

**`C-c p` — project (new tier-1 family).**  Letters mirror
`project.el`'s `C-x p <letter>` defaults so muscle memory between the
two prefixes is identical.  `p p / f / b / k / d / D / c / r / g /
v / e / s / !`.  `C-c f F` (was `project-find-file`) and `C-c f p`
(was `project-switch-project`) retired — the file family is files
again.

**`C-c s` — search (scope ladder).**  Lowercase narrows, uppercase
widens.  `s s` line / `s S` line-multi; `s r` ripgrep (project) /
`s R` ripgrep (prompt dir); `s i` imenu (buffer) / `s I` imenu
(project); `s o` outline; `s d` find filenames; `s m` / `s M`
mark-ring / global-mark-ring; `s .` line-at-symbol.  Existing `C-c s
…` `:bind` block in `completion/dl-consult.el` retired; the letter
set rotated (`s g/f/l` → `s r/d/s`) for ladder consistency.  Two
helpers (`my/consult-line-symbol-at-point`,
`my/consult-ripgrep-prompt-dir`) live in `dl-consult.el`.

**`C-c e` — eval.**  Lowercase reads to minibuffer; uppercase
prints/inserts.  `e e` / `E` last sexp (read / print); `e f` defun;
`e r` region; `e b` buffer; `e i` ielm; `e s` scratch; `e x`
eval-expression; `e m` pp-macroexpand.

**`C-c o` — org (re-scoped).**  Cross-buffer entry points only —
in-buffer Org commands stay at Org's own `C-c C-<x>` (mode-specific
space, Org owns it).  `o h` heading (buffer) / `o H` heading
(agenda); `o j` clock-goto / `o i` clock-in-last / `o O` clock-out;
`o r` refile; `o q` `my/org-ql-find-here` (file-scoped, complementing
corpus-scoped `n q`); `o b` switchb; `o L` insert-link-global.  New
wrapper `my/org-ql-find-here` in `org/dl-org-ql.el`.

**Disabled session map retired.**  `C-c j` / `my-session-map` and
its commented easysession binds removed from `core/dl-keymap.el`;
which-key label dropped; meow leader entry dropped.  Easysession can
reclaim `j` (or land elsewhere) if it returns.

**`KEYS.md` overhaul.**  New `## Policy` section codifies the
three-tier grammar (Tier 1 family / Tier 2 variant / Tier 3
compartment) with the reserved-letters note (`C-c h` avoided because
`h` is the modal gateway).  Prefix index updated (drop `j`, add
`p`, retag `s`/`e`/`o`).  Full content sections added for
`C-c o / s / p / e`.  Three stale claims fixed: `which-key-idle-delay`
is `0.3`, not `1e6 (off)`; "empty maps" deferred-item retired; "re-enable
session map" deferred-item retired.

**Touched:** `core/dl-keymap.el`, `completion/dl-consult.el`,
`org/dl-org-ql.el`, `KEYS.md`.

Deferred (unchanged): hydras (window-resize is the natural first);
remaining `:bind` migrations into the prefix structure (`dl-embark`,
`dl-motion`, `dl-search`, `dl-fold`); `C-c d` (diagnostics) and
`C-c k` (config) reserved per the Policy budget.

## 2026-05-17 — work compartment in `~/notes`

First-class work compartment under `~/notes/work/`, mirroring the
existing class taxonomy plus two work-native classes (`meetings/`,
`people/`).  `work.org` reroled from a sparse log into the curated
dashboard described in `work.local.md`; the pre-change contents are
preserved verbatim at `work/archive/legacy-work.org`.

**Filesystem (notes repo).** New subtree:

```
work/
  inbox.org             :work:inbox:
  intake/  journal/  weekly/  meetings/  people/
  projects/  areas/  sources/  references/  slips/  indexes/
  attachments/  archive/
  archive/legacy-work.org   ← verbatim copy of pre-change work.org
```

`work.org` itself is now the dashboard (priorities, commitments,
waiting-on, deadlines, active projects, people, meetings, daily +
weekly work review checklists, entry-point links) with
`#+filetags: :work:index:`.  Single commit in the notes repo.

**Path module.** `core/dl-notes-paths.el` extended with 16 work
constants (`dl-notes-work-file`, `dl-notes-work-dir`, then per-class
subdir constants for `inbox`, `intake`, `journal`, `weekly`,
`meetings`, `people`, `projects`, `areas`, `sources`, `references`,
`slips`, `indexes`, `attachments`, `archive`).  New `my/notes-ensure-dirs`
creates any missing personal or work directories at load time (and
on-demand) — a fresh clone is self-bootstrapping.

**Constructors.** `my/denote--new` now accepts a class string *or* a
list of class strings; work constructors prepend two keywords (`work`
+ class), so a meeting note ends up
`work/meetings/<id>--<slug>__work_meeting_<extras>.org` with
`:work:meeting:` in `#+filetags:`.  Eight new constructors land:
`my/denote-new-work-{project,area,source,slip,reference,index,
meeting,person}`.  `denote-known-keywords` extended with `meeting`,
`person`, `work`, and the cross-boundary tags `work-relevant`,
`work-adjacent`, `management`, `technical-leadership`.

**Journal/weekly.** `org/dl-denote-journal.el` refactored: the file-
name builder, skeleton builder, and `ensure-file` helper now take dir
/ suffix / tags arguments.  Personal `my/journal-note`, `my/weekly-note`,
`my/journal--ensure-today` continue to work unchanged; new
`my/work-journal-note`, `my/work-weekly-note`, and
`my/work-journal--ensure-today` write to `work/journal/` and
`work/weekly/` with `__work_journal.org` / `__work_weekly_journal.org`
suffixes and `:work:journal:` / `:work:weekly:journal:` tags.

**Capture.** Nested `("w" "Work")` group with six children:

```
w i  Work inbox        work/inbox.org           * TODO …                :work:
w j  Work journal      today's work journal     * %U %?                 under * Log
w t  Work task         work/inbox.org           * TODO %?               :work:task:
w m  Work meeting      work/inbox.org           * %? :work:meeting:     + ATTENDEES/DATE drawer
w p  Work person       work/inbox.org           * %? :work:person:      + WHO drawer
w r  Work reference    work/inbox.org           * %? :work:reference:   + URL/AUTHOR/DATE/LICENSE/TRUST drawer
```

Same shape as the existing `s/S/r` source/slip/reference pipeline:
fast capture into `work/inbox.org`; durable promotion via the work
constructors.  `w j` uses `my/work-journal--ensure-today` as the
capture target so the file is created with skeleton on first touch
of the day.

**Agenda.** Three scopes via `org-agenda-custom-commands` rather than
modal `org-agenda-files` mutation:

```
C-c a a   default dispatcher (combined union — the new default)
C-c a p   personal-only
C-c a w   work-only
C-c a c   combined (explicit)
```

`my/org-agenda-refresh-files` walks personal + work scopes with
`directory-files-recursively` and stores three lists
(`my/org-agenda-{personal,work,combined}-files`).  Custom commands
bind `org-agenda-files` to the appropriate list per invocation —
boundary by directory custody, not tag.  Crossover via `:work-relevant:`
deferred; appending a filtered list to `my/org-agenda-work-files` is
the one-line extension when that pattern materialises.

Excluded by design (mirrors the existing personal exclusion):
`areas/`, `indexes/`, `references/`, `sources/`, `slips/`, `archive/`,
`attachments/`, `intake/` and their work counterparts.

**Review.** Six work commands mirror the personal set 1:1, factored
through small private helpers (`my/review--open-inbox`,
`my/review--dired-newest`, `my/review--weekly-with-waiting`,
`my/review--stale-cutoff`):

```
my/review-work-inbox
my/review-work-intake
my/review-work-weekly
my/review-work-stale
my/review-work-references-retained
my/review-work-references-untrusted
```

Plus `my/work-org-ql-find` — work-scoped wrapper around `org-ql-find`
bound to `C-c n W q`.

**Keymap.** `C-c n W` is a fourth notes sub-prefix alongside
`N / m / v`.  Constructors live directly under `W` (so personal
constructors at `C-c n N …` aren't overloaded); reviews under `W v`.
Eighteen new binds total.  `SPC n W …` works automatically through
the existing `my-notes-map` Meow leader mirror — `W` is not in the
keypad reserved set (`g`, `m`, `c`, `x`).

**Touched:** `core/dl-notes-paths.el`, `org/dl-denote.el`,
`org/dl-denote-templates.el`, `org/dl-denote-journal.el`,
`org/dl-org-capture.el`, `org/dl-org-agenda.el`, `org/dl-review.el`,
`core/dl-keymap.el`, `NOTES.md`, `KEYS.md`.  Notes repo: `work.org`,
`work/inbox.org`, `work/archive/legacy-work.org`.  No new requires in
`init.el` — all extensions live in modules already loaded.

Deferred: cross-boundary `:work-relevant:` agenda inclusion; work
deadlines / people-followups / active-projects review surfaces
(add when friction earns them).

## 2026-05-17 — notes system overhaul, Phase 7 (root-note triage)

Content-level work in `~/notes/`. No Emacs-config changes — just
re-homing the 6 root-level Denote notes left after Phase 1 into class
subdirs, and adding the reference metadata block to the 2 LLM-era
markdowns so the Phase 6 review queries start surfacing them.

**Re-homing.** Six `git mv`s, history preserved. Classification:

| Note | New dir | Signal |
|---|---|---|
| `substrate__emacs_idea_project_tech.org` | `projects/` | `:project:` tag in filename |
| `emacs-note-system__emacs_org_project_tech.org` | `projects/` | `:project:` tag in filename |
| `ricing-emacs__emacs_oss_tech.org` | `projects/` | content: TODO/NEXT list of emacs packages = active workstream |
| `risk-governance-glossary__…` | `indexes/` | content: glossary ≡ index per plan |
| `proficiency-with-emacs__emacs_org_pkm_tech.org` | `areas/` | content: topic map for ongoing emacs learning |
| `orchestration__ai_design_dev_tech.org` | `areas/` | content: standing principles in a domain |

The plan said all 6 had explicit class tags. Only 2 actually did; the
rest were classified from content. No external file-path-based links
existed (only the files' own `#+identifier:` lines reference them) so
no link surgery was needed. Denote-id-based links would survive a
move regardless.

Note for `ricing-emacs` in `projects/`: agenda now pulls in its
TODO/NEXT items (`dl-notes-projects-dir` is in `org-agenda-files`).
That's the intended shape of project-tier notes; if any item should
not be agenda-visible, change its keyword.

**Reference metadata.** Both Markdown references in `references/`
gained the metadata block the Phase 1 plan specified
(`status: raw`, `trust: unreviewed`, `captured-at:`). Each updated
its `tags:` list to start with `reference`. The plan said both were
LLM-generated; only one actually is:

- `pkm-research-report__pkm_research_slop.md` — LLM-generated (has
  ChatGPT/Claude `citeturn…` citation markers). Tags now include
  `reference, llm, untrusted`; `source: llm-generation` added.
- `how-a-researcher-uses-denote__emacs_pkm_web.md` — human-written
  blog post from lambdaland.org. Tags include `reference, web`;
  `source-url: https://lambdaland.org/posts/2025-07-11_research_notes/`
  added; trust still `unreviewed` until reviewed.

**Verification.** Both Phase 6 review queries now match:
`my/review-references-retained` (ripgrep `status: raw`) → 2 hits.
`my/review-references-untrusted` (ripgrep `untrusted` /
`trust: unreviewed`) → 2 hits.

**Out of scope:** `~/tasks/{10_daily, 20_weekly, 30_projects,
50_notes}` legacy markdown (per plan: "out of scope for the Emacs
config but flagged"). Single-format `archive/`, `attachments/`,
`intake/` triage is also a content task and will happen as captures
roll through.

That closes the planned overhaul. Phases 1-7 done; everything left is
either content (triaging incoming captures) or downstream
elaborations (more `dl-review` queries, more capture templates as
they earn their keep, eventual `dl-citar.el` if a bibliography ever
materializes).

## 2026-05-17 — notes system overhaul, Phase 6 (review module)

Phase 6: `org/dl-review.el` lands with six review commands wired
under the `C-c n v …` sub-prefix that Phase 4 stubbed out. Two
shapes:

- **Navigational** — open the buffer you want for a review pass.
- **Reporting** — surface items matching a review predicate, via
  `org-ql` for Org files or `consult-ripgrep` for the mixed
  `references/` formats (.org / .md / .pdf / .html).

```
C-c n v i   my/review-inbox                 open inbox + jump to first TODO
C-c n v I   my/review-intake                dired intake/, sorted newest first
C-c n v w   my/review-weekly                open weekly note + side window of WAITING items
C-c n v s   my/review-stale                 org-ql: WAITING items untouched > my/review-stale-days (7 default)
C-c n v r   my/review-references-retained   ripgrep: references with `status: raw`
C-c n v u   my/review-references-untrusted  ripgrep: `:untrusted:` tag or `trust: unreviewed`
```

**Stale-WAITING predicate.** Approximation: a WAITING item is stale
if no timestamp (active or inactive) in its subtree falls within the
last `my/review-stale-days` (defvar, default 7). Captured as
`(and (todo "WAITING") (not (ts :from CUTOFF)))`. Not exact — true
"time in WAITING" requires walking LOGBOOK state-change entries — but
the timestamp-of-anything-recent approximation is honest enough for
weekly triage. The user can flip the defvar to tighten.

**References review uses ripgrep, not org-ql.** `references/` is
explicitly multi-format per the plan (LLM markdowns, PDFs, web
clippings, .org files). Both `v r` and `v u` use `consult-ripgrep`
against the literal metadata strings (`status: raw`,
`trust: unreviewed`, `:untrusted:`) so any format with those flags
shows up. Current matches: zero — the 2 existing LLM .md references
predate the Phase 1 metadata convention and haven't been tagged.
Tagging them is a content-level task (Phase 7-ish), unblocked but
not done.

**`my/review--notes-files`** picks the query universe:
`inbox.org`, `projects/`, `areas/`, `sources/`, `slips/`,
`journal/`, `weekly/`. References excluded — they're not authored
content. Intake also excluded — it's an object dump, not Org.

**Touched:** `org/dl-review.el` (NEW; `git add`-ed so the flake
parser sees it), `core/dl-keymap.el` (six binds under
`my-notes-review-map`), `init.el` (`require 'dl-review`).

Phase 7 (root-note triage; promote the 6 root-level Denote notes
into class subdirs; tag the 2 LLM .md references for review) is the
last config-related slice — and it's mostly content work, not
Emacs-config work.

## 2026-05-17 — notes system overhaul, Phase 5 (org-ql + consult-notes + consult-org)

Phase 5 of the notes overhaul: install the new retrieval tools and
wire them to the existing Phase 4 keybinds. Concrete saved-search and
review commands continue to defer to Phase 6 (`dl-review.el`).

**New modules:**

- `org/dl-org-ql.el` — installs `org-ql`. `C-c n q` (`org-ql-find`)
  bound in Phase 4 now resolves. The dashboards/queries mentioned in
  the plan land in Phase 6 alongside the review commands — they're
  the same body of work (`my/notes-stale-items`, weekly review etc.
  are all `org-ql` queries).
- `completion/dl-consult-notes.el` — installs `consult-notes` with
  per-class file-dir sources backed by `dl-notes-*-dir` constants:

  ```
  Journal     j    Slips       S    Areas       a
  Weekly      w    References  r    Sources     s
  Projects    p    Indexes     i
  ```

  Narrow keys are typed at the consult prompt to scope to one class
  (e.g. `j SPC` for journal only). `consult-notes-denote-mode` is
  enabled on top so bare Denote-named files at `dl-notes-root` (the 6
  root-level notes pending Phase 7 triage) are still picked up.

**`consult-org-heading` binding** (consult bundles `consult-org`):

- `C-c o h` (`my-org-map "h"`) — in-buffer outline search. Lives in
  `core/dl-keymap.el` so it inherits the meow leader mirror
  (`SPC o h`).

**citar skipped.** Plan §5 says "only if a bibliography exists. Skip
otherwise." `rg -l 'citar|bibliography'` against `~/notes` returned
nothing meaningful — no `.bib` files, no `bibliography:` org-cite
front matter. Adding `citar` now would be speculative. The Phase 2
"deferred module" `org/dl-citar.el` stays unborn until there's
content to back it.

**Nix install verified.** Both packages landed in the new
`emacs-packages-deps` derivation under:

```
share/emacs/site-lisp/elpa/{org-ql-20250421.133, consult-notes-20260222.1928}
```

(Plus transitive deps `org-super-agenda`, `peg`, `ts`.) `consult-org`
needs no install — bundled with `consult`.

**Note for the running session.** The currently-running Emacs is
still backed by the *old* wrapper's elpa cache, so a restart is
needed to load `org-ql` / `consult-notes` from the proper path
on init. In the meantime, the live-eval workflow used to verify
phase 5 added the new elpa subdirs to `load-path` ad-hoc; that's
session-local and goes away on restart, which is the right shape.

**Touched:** `org/dl-org-ql.el` (NEW), `completion/dl-consult-notes.el`
(NEW), `core/dl-keymap.el` (consult-org-heading bind), `init.el`
(two requires).

Phase 6 (review workflow — `dl-review.el` with inbox/intake/weekly
sweeps and stale-item queries) and Phase 7 (root-note triage) remain.

## 2026-05-17 — notes system overhaul, Phase 4 (capture pipeline + `C-c n …` consolidation)

Phase 4 of the notes overhaul (plan
`~/.claude/plans/yes-use-dl-for-staged-quiche.md`). Two slices: capture
templates aligned with the promotion pipeline, and a single
`C-c n …` namespace with three sub-prefixes.

**New module: `org/dl-denote-templates.el`** — class constructors that
wrap `denote` per class. Each prompts for title + extra keywords, then
calls `denote` with the class tag prepended and the right subdir:

```
my/denote-new-project    -> projects/    :project:
my/denote-new-area       -> areas/       :area:
my/denote-new-source     -> sources/     :source:
my/denote-new-slip       -> slips/       :slip:
my/denote-new-reference  -> references/  :reference:
my/denote-new-index      -> indexes/     :index:
```

Class is encoded twice — by file location *and* by the leading keyword
— so downstream filters (org-ql, consult-notes, agenda regex) can pick
either signal.

**Capture rework (`org/dl-org-capture.el`).** Old template letters
`i / f / P / r` were replaced with a pipeline-aligned set; old `j`
datetree (`journal/log.org`) was retired in favour of appending into
today's Denote-named journal file:

```
c   Inbox text        -> inbox.org   * TODO …
j   Journal (today)   -> today's denote journal, under * Log
s   Source intake     -> inbox.org   * … :source:    + URL/AUTHOR drawer
S   Slip intake       -> inbox.org   * … :slip:
r   Reference intake  -> inbox.org   * … :reference: + URL/AUTHOR/DATE/LICENSE/TRUST drawer
p   Protocol          unchanged (sprig/org-capture-extension)
L   Protocol Link     unchanged
```

The `j` target uses a new helper `my/journal--ensure-today` in
`dl-denote-journal.el`, which creates today's file with the skeleton if
absent so capture has somewhere to land before the user has hit
`C-c n j` for the day. The helper is shared with `my/journal-note`
itself (extracted alongside `my/journal--today-file` and
`my/journal--today-skeleton`).

Dropped templates: `i` (renamed to `c`), `f` (use `c` and delete the
TODO marker, or `denote`/class constructors), `P` (use `C-c n N p`),
old `r` "Reading note" (repurposed for reference intake). The
`f` file-intake template the plan flagged as optional is not yet
written — intake-dir workflow is content-level (Phase 7).

**Keymap consolidation (`core/dl-keymap.el`).** Single `my-notes-map`
at `C-c n` (mirrored as `SPC n` via mode-specific-map = meow leader),
with three sub-prefixes (`my-notes-new-map`, `my-notes-manage-map`,
`my-notes-review-map`). Full table:

```
C-c n c   org-capture                          C-c n N p   new project
C-c n j   my/journal-note                      C-c n N a   new area
C-c n w   my/weekly-note                       C-c n N s   new source
C-c n n   denote                               C-c n N S   new slip
C-c n f   consult-notes              (Ph5)     C-c n N r   new reference
C-c n s   consult-notes-search…     (Ph5)     C-c n N i   new index
C-c n l   org-store-link                       C-c n N j   journal today
C-c n i   denote-link                          C-c n N w   weekly
C-c n o   org-open-at-point-global
C-c n g   org-mark-ring-goto                   C-c n m r   denote-rename-file
C-c n b   denote-backlinks                     C-c n m R   …-using-front-matter
C-c n q   org-ql-find               (Ph5)     C-c n m k   denote-rename-file-keywords
                                               C-c n m t   denote-rename-file-title
C-c n v   (review prefix — commands Ph6)
```

Phase-5 bindings (`f / s / q`) are wired to symbols that aren't yet
installed; the void-function error only surfaces if pressed before
Phase 5 lands. Cheaper than stubbing them out twice — `declare-function`
forms at the top of `dl-keymap.el` keep the byte-compiler quiet.

Plan §4b had split keyword edits into `m k` (add) and `m K` (remove),
but denote 3.x collapsed those into a single editor
(`denote-rename-file-keywords`) that prepopulates the existing list and
lets the user add or remove inline. Collapsed the bindings to match:
`m k` only, `m K` unbound.

**Migrations from previous bindings**:

- `C-c n n / l / b / r / R` (`:bind` block in `dl-denote.el`) → moved to
  `my-notes-map` (`n` denote, `i` denote-link [was `l`], `b` backlinks,
  `m r` rename, `m R` front-matter rename). The `dl-denote.el` `:bind`
  block was removed.
- `C-c n j / w` (`global-set-key` in `dl-denote-journal.el`) → moved to
  `my-notes-map`. The redundant `(define-key … "C-c n d" nil)` retire-
  binding is gone too — `C-c n d` simply isn't defined anymore.

**Denote known-keywords extended** to include the full class set
(`area`, `slip`, `index`, `weekly`) so completion at the keyword prompt
suggests them.

**Touched:** `org/dl-denote-templates.el` (NEW — `git add`-ed so the
flake parser sees it), `org/dl-org-capture.el` (template rewrite),
`org/dl-denote-journal.el` (factored helpers; binds moved out),
`org/dl-denote.el` (binds moved out; known-keywords extended),
`core/dl-keymap.el` (notes map + sub-prefixes + meow leader mirror),
`init.el` (`require 'dl-denote-templates`).

Phases 5-7 (org-ql / consult-notes / citar; review workflow; root-note
triage) remain.

## 2026-05-17 — notes system overhaul, Phase 3 (Denote-named journaling) + org-modern fix

**Journaling moves to Denote naming.** `dl-denote-journal.el` rewritten:

- `my/journal-note` (new name; replaces `my/daily-note`) →
  `journal/YYYYMMDDT000000--YYYY-MM-DD-<weekday>__journal.org`. Today
  resolves to `20260517T000000--2026-05-17-sunday__journal.org`,
  matching the 5 migrated files from Phase 1.
- `my/weekly-note` (kept the name) → `weekly/<monday-id>--YYYY-w<NN>__weekly_journal.org`.
  Identifier anchors on the ISO-week Monday, so the file sorts to the
  start of its week regardless of which day it's first opened. Today
  resolves to `20260511T000000--2026-w20__weekly_journal.org`.
- New helper `my/journal--iso-monday` shifts a time back to its ISO
  Monday using `%u` (1=Mon … 7=Sun).
- Templates set `#+title:`, `#+filetags:`, `#+date:` on first-open;
  body skeletons unchanged from before.

**Keybind rebind** (per the agreed Phase 4 keymap):

- `C-c n d` (was `my/daily-note`) — unbound via
  `(define-key global-map ... nil)`.
- `C-c n j` → `my/journal-note` (new).
- `C-c n w` → `my/weekly-note` (unchanged).

Roll-own rather than upstream: denote 4.1.3 in the Nix overlay ships
without the `denote-journal` submodule (split off in 4.x and not yet
packaged here). The roll-own is ~40 lines and lets us keep the exact
filename convention the migrated files use (`T000000` + weekday-in-slug).

The Phase 2 `j` capture template (datetree in `journal/log.org`) is
left in place — different ergonomic shape (quick fragment append vs.
full-page operational log). Retire later if it goes unused.

**org-modern fix** (longstanding no-op, flagged in Phase 2):

```elisp
;; was:
(use-package org-modern
  :after
  (add-hook 'org-mode-hook #'org-modern-mode)
  (add-hook 'org-agenda-finalize-hook #'org-modern-agenda))

;; now:
(use-package org-modern
  :hook ((org-mode            . org-modern-mode)
         (org-agenda-finalize . org-modern-agenda)))
```

`:after` takes a package list, so the two `add-hook` forms were being
parsed as package names and silently dropped — `org-modern-mode` was
never actually attached to `org-mode-hook`. Now it auto-enables on
every Org buffer (no more manual toggle).

**Touched:** `org/dl-denote-journal.el` (rewrite), `org/dl-org.el`
(org-modern hooks).

## 2026-05-17 — notes system overhaul, Phase 2 (module decomposition)

Pure refactor: split `org/dl-org.el` into focused modules. No behaviour
change — every binding, template, advice, and var resolves the same as
before.

**New modules** (all under `org/`, all tracked via git so the Nix flake
parser picks them up):

- `dl-org-capture.el` — capture templates (7: `i/f/j/P/r/p/L`),
  `my/capture-body`, `my/capture-entry`, `my/sanitize-link-description`,
  `my/org-capture-delete-client-frame` + the
  `my/org-capture-delete-frame-on-finalize` flag, advice on
  `org-capture-finalize`/`kill`, and the `C-c c` global binding.
- `dl-org-agenda.el` — `org-agenda-files` (now derived from
  `dl-notes-*` constants), `C-c a` global binding. Custom agenda
  commands land here in Phase 5.
- `dl-org-links.el` — `C-c l` (`org-store-link`). Home for the Phase 4
  consolidated `C-c n l/i/o/g` link namespace.
- `dl-denote-journal.el` — `my/daily-note`, `my/weekly-note`, and their
  `C-c n d/w` bindings. Home for the Phase 3 Denote-named rewrite.

**Slimmed `dl-org.el`**: keeps org defaults (directory, todo keywords,
tag-alist, log-done, return-follows-link, speed-commands), org-modern
and org-bullets styling, and the mode-hook spacing tweak. Everything
else moved out.

**init.el load order** (in section `;; Org`):

```
(require 'dl-org)
(require 'dl-org-capture)
(require 'dl-org-agenda)
(require 'dl-org-links)
(require 'dl-denote)
(require 'dl-denote-journal)
(require 'dl-org-roam)
```

**Modules deferred** rather than created empty (per "no half-finished
implementations"):

- `dl-denote-templates.el` — class constructors (`my/denote-new-project`
  etc). Phase 3/4 when they have content.
- `dl-org-ql.el` / `dl-citar.el` — Phase 5, when the packages land.
- `dl-review.el` — Phase 6.
- `dl-writing.el` — `core/dl-prose.el` already covers prose/spelling
  cleanly; the plan's `dl-writing.el` is redundant with what exists.
  Keeping `dl-prose.el` where it is.

**Known pre-existing bug** (left untouched, flagged for later):
`org-modern`'s `use-package` block uses `:after` followed by `add-hook`
calls — `:after` takes a package list, not body forms, so the hooks
never get added. `org-modern-mode` is currently not actually enabled on
`org-mode-hook`. Fix: change `:after` to `:config` (or `:hook`). Not
part of Phase 2's "no behaviour change" promise.

**Touched:** `init.el`, `org/dl-org.el` (slimmed), 4 new modules under
`org/`.

## 2026-05-17 — notes system overhaul, Phase 1 (paths + dirs + TODO)

First slice of the notes-system overhaul plan
(`~/.claude/plans/yes-use-dl-for-staged-quiche.md`). No new packages, no
module decomposition — just the substrate.

**Filesystem.** `~/notes` was a symlink to `~/tasks/00_inbox/`; promoted
in place: `rm` the symlink, `mv ~/tasks/00_inbox ~/notes`. Reorganised
inside the new real `~/notes/`:

- Created `intake/ journal/ weekly/ projects/ areas/ sources/ slips/
  indexes/ references/ attachments/ archive/`.
- `_archived/` → `archive/`, `assets/` → `attachments/`, `context/` →
  `references/` (the two LLM research markdowns land here; will need
  `:reference:llm:untrusted:` tags on review per the plan).
- 5 daily files in `2026/YYYY-MM-DD.org` → renamed to Denote-style
  `YYYYMMDDT000000--yyyy-mm-dd-weekday__journal.org` under `journal/`.
- Deleted empty placeholders (`indices/`, `notes/`, `refs/`, `writing/`)
  whose names don't match the new vocab. `projects/` was already
  on-name; kept.
- 6 root-level Denote notes left at root — homing into class subdirs is
  Phase 7 triage (content, not config).
- `.git/`, `.gitignore`, `.org-roam.db` preserved via the bulk dir
  move. Corpus history intact.
- `~/tasks/{10_daily, 20_weekly, 30_projects, 40_areas, 50_notes,
  90_archive}` left untouched — legacy parking, separate triage.

**New module: `core/dl-notes-paths.el`.** Single source of truth for
notes paths. Defines `dl-notes-root`, `dl-notes-inbox-file`, and
per-class dir constants (`dl-notes-{intake,journal,weekly,projects,
areas,sources,slips,indexes,references,attachments,archive}-dir`), plus
`my/notes-path` for joining segments under root. Required early in
`init.el` (after `dl-core`).

**Downstream rewires** (replace string literals with constants):

- `org/dl-org.el`: `org-directory`, `org-default-notes-file`,
  `org-agenda-files`, all capture-template file paths, and
  `my/daily-note`/`my/weekly-note` now derive from `dl-notes-*`. Daily
  and weekly point at the new `journal/`/`weekly/` dirs but keep the
  simple `YYYY-MM-DD.org` / `YYYY-WNN.org` naming for now — Denote-named
  rewrite is Phase 3. Agenda dropped the (gone) `writing/` and added
  `weekly/`. Duplicate `(global-set-key "C-c c" #'org-capture)` (had
  shadowed itself at L130) removed.
- `org/dl-denote.el`: `denote-directory` → `dl-notes-root`.
- `org/dl-org-roam.el`: `org-roam-directory` → `(file-truename
  dl-notes-root)`. Roam stays wired but unused (separate
  acceleration layer per the plan; not the primary navigator).

**TODO state expansion.** Old: `TODO NEXT WAIT | DONE CANCELLED`. New:
`TODO NEXT STARTED WAITING(w@/!) | DONE(d!) CANCELED(c@) MOVED(m@)`.
Logging triggers added (`!` for done, `@` for waiting/canceled/moved).
One existing match (`work.org:5` had `** WAIT`) swept via `sed` to
`WAITING`. `CANCELLED` → `CANCELED` rename had no matches.

**Touched:** `core/dl-notes-paths.el` (new — tracked via git so the Nix
flake parser sees it), `init.el`, `org/dl-org.el`, `org/dl-denote.el`,
`org/dl-org-roam.el`, plus the filesystem migration outside the repo.

Phases 2-7 (module decomposition, Denote-based journaling, capture
template rework + keymap consolidation, org-ql/consult-notes/citar,
review workflow, root-note triage) remain.

## 2026-05-16 — org-protocol capture from Firefox

Wired up [sprig/org-capture-extension](https://github.com/sprig/org-capture-extension)
end-to-end. Three bugs found en route:

- **Desktop handler used `%F` (files) instead of `%u` (URL)**, so the
  Emacs-provided `emacsclient.desktop` silently dropped the
  `org-protocol://` URI and created a blank frame. New
  `~/.local/share/applications/org-protocol.desktop` (tracked via the
  sparse `~/` worktree) handles the scheme with `%u`, `--create-frame`,
  `--no-wait`.
- **`(concat org-directory "protocol.org")`** produced
  `~/notesprotocol.org`. Replaced with `expand-file-name`.
- **Duplicate template key `p`**: "Project task" shadowed "Protocol"
  (assoc returns first match). Renamed Project task to `P`.

Templates corrected to use the org-protocol plist keys (`%:link`,
`%:description`) instead of `%u` (which is the inactive timestamp, not
the URL) and `%c` (clipboard pollution).

Two improvements from the sprig README, with safety tweaks:

- **`my/sanitize-link-description`** replaces `[` `]` in the `L`
  template's description so ArXiv-style titles don't break the
  `[[link][desc]]` syntax.
- **Auto-close the emacsclient frame** after `org-capture-finalize` /
  `org-capture-kill`.  Uses a boolean flag set by the template (cleaner
  than sprig's counter) and guards with `(frame-parameter nil 'client)`
  + `(cdr (frame-list))` so manual `C-c c p` from the main frame is
  safe and the last frame is never deleted.  Refile is covered by the
  finalize advice — refile calls finalize internally.

**Touched:** `org/dl-org.el`, `~/.local/share/applications/org-protocol.desktop`.

## 2026-05-16 — session leader + meow `h` as C-c, autosave hook fix

Two related cleanups around the leader system.

**`my-session-map` (`C-c j` / `SPC j` / `h j`).** Easysession's defaults
were `C-c s*`, which `define-key` silently descended into `my-search-map`
(squatting in the search namespace). Moved them onto their own prefix
with which-key labels and meow leader mirror, via `my/bind`:

```
C-c j s   save           C-c j r   rename
C-c j l   load           C-c j R   reset
C-c j L   load+geometry  C-c j u   unload
                         C-c j d   delete
```

**Meow normal `h` → `mode-specific-map`.** Bound `h` directly to the C-c
keymap, so `h f f`, `h j s` etc. work from normal state as a third path
alongside `C-c` and `SPC`. Bonus over `SPC`: lowercase `g` / `m` work
without the capital workaround (no meow-keypad in the way). Dropped
`meow-left` — home-row arrows live on a layer.

**Autosave bug.** `(add-hook 'after-focus-change-function …)` was wrong
— that variable holds a single function (`#'ignore` advised by
`blink-cursor--rescan-frames`), not a hook list. `add-hook` cons'd the
function onto the existing advised form, producing an uncallable list and
spamming `Invalid function:` on every focus event. Replaced with
`add-function :after`, arity-tolerant via a `&rest _` wrapper.

**Touched:** `core/dl-keymap.el`, `editing/dl-persist.el`, `KEYS.md`.

## 2026-05-16 — file manager: dired/dirvish + yazi/broot wrappers

Consolidated the file-management stack on Dired + Dirvish, with Yazi and
Broot reachable as ghostel terminals that hand a path back to Emacs on
exit. Single home for everything under `my-file-map` (`C-c f` / `SPC f`):
`d` dired-jump, `D` dirvish, `t` dirvish-side, `F` project-find-file, `p`
project-switch, `y` yazi, `b` broot. Existing `f/s/S/r` kept.

Retired `dired-preview`, `dired-sidebar`, `nerd-icons-dired`, `dired-subtree`,
plus a duplicate `recentf` block in `editing/dl-persist.el` and the stray
`("C-c f" . dirvish-dwim)` bind that was shadowing the prefix. `C-x C-n`
moved from `dired-sidebar-toggle-sidebar` to `dirvish-side`.

Yazi uses `--cwd-file`, Broot uses `--outcmd` (parses the `cd PATH` line —
use **alt-enter** to fire `:cd`). Sentinel kills the ghostel buffer on exit.

See `FILE_MANAGER.md` for the full layout and the traps hit along the way
(missing `(require 'dl-dirvish)` in `init.el`, `lexical-binding` cookie on
the wrong line).

**Touched:** `apps/dl-dired.el`, `apps/dl-dirvish.el`, `core/dl-keymap.el`,
`core/dl-interface.el`, `editing/dl-project.el`, `editing/dl-persist.el`,
`init.el`.

## 2026-05-16 — nixd over nil, with flake-aware completion

Switched the Nix LSP from `nil` to `nixd` and fed it workspace settings so it
can evaluate the flake at `~/flakes`:

- `nixpkgs.expr` resolves to the flake's own nixpkgs input → completion for
  real package attrs (`pkgs.<TAB>`).
- `options.nixos` → `nixosConfigurations.Sleipnir.options` (option completion
  + docs under `config.*` in NixOS modules).
- `options.home-manager` → `homeConfigurations.david.options` (same for HM
  modules).
- `formatting.command` → `alejandra`, matching the flake's treefmt.

Hostname and HM user are hardcoded constants in `lang/dl-nix.el`. First
completion in a session is slow (full flake eval); subsequent calls are
cached. Activate with `M-x eglot-reconnect` in a `.nix` buffer.

**Touched:** `lang/dl-nix.el`.

## 2026-05-16 — vterm → ghostel

Replaced the vterm/multi-vterm/vterm-toggle stack with [ghostel](https://github.com/dakra/ghostel)
(libghostty-vt). Shpool session management (`apps/dl-shpool.el`) was ported to
ghostel's API in the same change — `shpool attach` is now spawned directly via
`ghostel-exec` instead of "open vterm, then send `exec shpool attach NAME`".

**Touched:** `apps/dl-term.el`, `apps/dl-shpool.el`, `core/dl-keymap.el`.

### Recovery — restoring vterm

To roll back, drop ghostel and reinstate the three blocks below in
`apps/dl-term.el`, plus the old `my-term-map` bindings in `core/dl-keymap.el`.

`apps/dl-term.el` (was the entire ghostel section):

```elisp
(use-package vterm
  :commands vterm
  :custom
  (vterm-kill-buffer-on-exit t)
  :bind (:map vterm-mode-map
          ("C-c <escape>" . vterm-send-escape))
  :config
  (setq vterm-max-scrollback 100000))

(use-package multi-vterm
  :after vterm
  :commands (multi-vterm multi-vterm-next multi-vterm-prev))

(defun my/vterm-named (name)
  "Open or create a named (for NAME) vterm buffer."
  (interactive "sVTerm name: ")
  (let ((buf-name (format "*vterm:%s*" name)))
    (if (get-buffer buf-name)
      (pop-to-buffer buf-name)
      (vterm buf-name))))

(use-package vterm-toggle
  :custom
  (vterm-toggle-hide-method 'delete-window)
  (vterm-toggle-fullscreen-p nil)
  :bind (([C-f1] . vterm-toggle)
          ([C-f2] . vterm-toggle-cd))
  :init
  (add-to-list 'display-buffer-alist
    '((lambda (buffer-or-name _)
        (let ((buffer (get-buffer buffer-or-name)))
          (equal major-mode 'vterm-mode)))
       (display-buffer-reuse-window display-buffer-at-bottom)
       (dedicated . t)
       (reusable-frames . visible)
       (window-height . 0.3)))
  :config
  (define-key vterm-mode-map [(control return)] #'vterm-toggle-insert-cd)
  (define-key vterm-mode-map (kbd "M-n")        #'vterm-toggle-forward)
  (define-key vterm-mode-map (kbd "M-p")        #'vterm-toggle-backward))
```

`core/dl-keymap.el` — replace the current `ghostel`/`ghostel-other` lines:

```elisp
(my/bind my-term-map "t" #'multi-vterm      "vterm")
(my/bind my-term-map "n" #'multi-vterm-next "vterm-next")
(my/bind my-term-map "P" #'multi-vterm-prev "vterm-prev")
```

`apps/dl-shpool.el` — shpool used to `(vterm buf-name)` then send
`exec shpool attach NAME\n` via `vterm-send-string` + `vterm-send-return`.
Mode checks were `'vterm-mode'`. Git history at this commit's parent has the
full pre-port version if needed.
