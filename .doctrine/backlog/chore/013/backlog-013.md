# CHR-013: Elisp lint gate: config byte-compiles warning-free

<!-- Backlog item body — context, detail, links. The structured, queried fields
     live in the sister `backlog-NNN.toml`; this prose is free-form and is never
     structurally parsed (the storage rule). -->

Make every tracked config `.el` byte-compile with zero errors and zero
warnings under Flymake's elisp backend, and keep it that way.

Baseline (2026-11-10): 246 diagnostics in 65 of 180 files. Kinds: undefined
function (83), function maybe undefined at runtime (52), unused lexical
variable (39), free variable (46), other (~25: obsolete APIs, defface
without `:group`, macro defined too late, malformed function, load failures).

Approach:
- `bin/elisp-lint` reproduces `elisp-flymake--batch-compile-for-flymake`
  with the load path `lang/dl-elisp.el` hands Flymake, over every tracked
  `.el` (excluding `elpa/`, `themes/`). `just lint` runs it; `just check`
  fails on any diagnostic.
- Fix order per `lang/dl-declare.el`: `require` when the file needs the
  library anyway; `declare-function` / `defvar` only for deliberate soft
  dependencies. Test files require the module under test.
- Checkdoc notes are out of scope.

Governance: the user chose a backlog item over a slice on 2026-11-10
(sized at one session, mostly mechanical).

## Progress (2026-11-10)

Done, uncommitted:
- Gate: `dev/dl-lint.el` (+ `lisp/test/dl-lint-test.el`), `bin/elisp-lint`,
  `just lint`, `check: lint`. Exclusions (`dl-lint-excluded`) are shared with
  live Flymake via `lang/dl-elisp.el`: init.el (compiling it boots the whole
  config: gpg prompts, processes), themes/noctalia-theme.el (generated
  elsewhere), compost/, .spec-driver/.
- Environment parity: `core/dl-package.el` (package activation, extracted
  from early-init.el); `bin/elisp-compile-child` loads it before compiling
  and drops `kill-emacs-hook` on exit so a scratch child never writes state
  files (recentf, project-window-list). Flymake uses the same child
  (`elisp-flymake-byte-compile-executable`). This alone removed ~90 false
  positives (autoloaded commands, `:vc` packages in elpa/).
- Fixes across ~45 files; full lint is clean.

Real defects found on the way:
- `dl-satan--compile-stale` ran during any compile that loaded the config
  and crashed it (nil dest file); now skipped under `byte-compile-current-file`.
- `dl-faces` applied org faces at load, depending on org-faces being loaded
  first; now applied when org-faces loads.
- `dl-claude`: `:config` called two defcustoms as functions; the error
  skipped `claude-code-ide-emacs-tools-setup`, which now runs.
- `dl-nushell`: hook added to `nushell-ts-mode` instead of `-hook`.
- Tests whose `let` bound package variables lexically (isolation silently
  void): dl-agent-review, dl-gptel-mcp, dl-session.
- dl-umbriel-buffer-test: macros used before definition.
- Three test files failed to load after `meow-setup` moved to dl-meow-map.

- Duplicate `a` in `my-org-map` (org-agenda / org-store-link) broke two
  tests; store-link moved to `l` (user's choice, 2026-11-11).

`just check` green: lint clean, 587/589 ERT pass (2 skipped).
Lint run: ~17 s (package-initialize per child).
