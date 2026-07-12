# Design SL-013: Note-system revival: subtree promotion + review views

<!-- Reference forms (.doctrine/glossary.md § reference forms): entity ids padded
     (SL-020, REQ-059, ADR-004); doc-local refs bare — OQ-1 (§6), D1 (§7),
     R1 (§10), Q1. -->

## 1. Design Problem

The denote note system is write-only: capture works, promotion and retrieval
are dead (61 journals vs ~15 durable notes, 23 `denote:` links total, four
undrained capture surfaces). Two mechanisms are missing:

1. **Promotion** — turning a journal/inbox subtree into a durable denote note
   is a manual multi-step chore, so it never happens.
2. **Resurfacing** — journal open items and protocol.org captures are
   invisible to every review view, so captured content dies silently.

## 2. Current State

- `org/dl-denote.el` (37 lines) — denote config, `denote-directory` =
  `dl-notes-root` (`~/notes`, or `/workspace/notes` in the jail).
- `org/dl-review.el` (158 lines) — review surfaces, personal + work mirrors,
  bound under `C-c n v` / `C-c n W v`. Scans inbox.org, projects/, areas/,
  sources/, slips/, journal/, weekly/ — **not** protocol.org, and has no
  journal-open-items or recent-notes view.
- `org/dl-org-capture.el:120,134` — two org-protocol templates target
  `(my/notes-path "protocol.org")` heading "Inbox". No path var exists for it.
- Journal open items use the standard todo sequence (8× TODO, 1× NEXT
  currently open across the corpus); no journal-specific keyword scheme.
- `denote-org` package **not installed**; denote + denote-explore already come
  via emacs-overlay's use-package parse.
- Keymap free slots: `p` on `my-notes-map`; `j`, `n`, `p` on
  `my-notes-review-map` (and same on the work review map).

## 3. Forces & Constraints

- Nix wiring (AGENTS.md): new `(use-package denote-org)` and any new `.el`
  file require `git add` + `home-manager switch` before they exist at
  runtime. Tests depending on `denote-org` cannot run before the switch.
- DRY: `dl-review.el` already owns review queries — extend it, no parallel
  module. `my/review--open-inbox`, `my/review--stale-cutoff` are reusable.
- Storage layout is fixed (`dl-notes-paths.el` defconsts, personal + work
  mirror).
- compile-angel byte-compiles on save: zero-warning discipline,
  `declare-function` for not-yet-installed packages (existing precedent at
  `dl-keymap.el:243`).

## 4. Guiding Principles

- Kill friction at the promotion step; one keystroke, one prompt.
- Extend existing surfaces; smallest diff that closes the loop.
- Provenance: promotion must leave a visible, linked trace in the journal.
- Views before rituals: make the drain cheap, don't legislate the habit.

## 5. Proposed Design

### 5.1 System Model

Two independent parts:

**A. Promote** — new module `org/dl-denote-promote.el`:

```
my/denote-promote-subtree            (interactive, C-c n p)
  ├─ guard: org-mode buffer, heading at point
  ├─ completing-read class dir      (curated: my/denote-promote-targets)
  ├─ record: origin marker, heading level, heading text
  ├─ let ((denote-prompts nil)
  │       (denote-directory <chosen dir>))
  │     denote-org-extract-org-subtree   ; moves subtree → new note
  ├─ capture: new note's path/ID/title from the note buffer it leaves current
  └─ back at origin: insert stub heading  "*… → [[denote:ID][title]]"
```

Curated targets (relative to `dl-notes-root`): `slips`, `sources`,
`references`, `projects`, `areas`, plus work mirrors `work/slips`,
`work/sources`, `work/references`, `work/projects`, `work/areas`. Built from
the existing `dl-notes-*-dir` defconsts, not re-derived.

**B. Review gap-fill** — three additions to `dl-review.el` + one path var:

| Command | Query / mechanism | Binding |
|---|---|---|
| `my/review-journal-open` | org-ql `(todo)` over journal + weekly dirs | `C-c n v j` |
| `my/review-protocol` | `my/review--open-inbox` on `dl-notes-protocol-file` | `C-c n v p` |
| `my/review-recent-notes` | dired on explicit file list (`(dired (cons dl-notes-root FILES))`, paths relative to root): durable-dir org files sorted by mtime desc, newest 30 | `C-c n v n` |

Work variants where the compartment exists: `my/review-work-journal-open`
(`C-c n W v j`), `my/review-work-recent-notes` (`C-c n W v n`). protocol.org
is a single shared file (both capture templates target the personal path) —
no work variant.

`dl-notes-protocol-file` defconst added to `core/dl-notes-paths.el`;
`dl-org-capture.el` templates switch to the var (removes the duplicated
literal). protocol.org joins `my/review--notes-files`; note the stale view
only surfaces todo-keyworded entries, so plain protocol captures are drained
via `my/review-protocol` (open + triage), not the WAITING report — that is
the honest limit of this slice.

### 5.2 Interfaces & Contracts

```elisp
;; dl-denote-promote.el
(defvar my/denote-promote-targets ...)         ; alist (label . dir), built from dl-notes-*-dir
(defun my/denote-promote-subtree () ...)       ; the one command
(defun my/denote-promote--stub (level id title) ...) ; pure: stub heading string

;; dl-review.el additions
(defun my/review--journal-files () ...)        ; journal + weekly dirs, realm-parameterised if cheap
(defun my/review-journal-open () ...)
(defun my/review-work-journal-open () ...)
(defun my/review-protocol () ...)
(defun my/review--recent-note-files (dirs n) ...) ; pure-ish: sorted file list
(defun my/review-recent-notes () ...)
(defun my/review-work-recent-notes () ...)
```

Stub contract: replaces the extracted subtree at the same outline level:

```org
* → [[denote:20260712T101010][Heading text]]
```

(level preserved: `**` if the promoted subtree was level 2, etc.)

### 5.3 Data, State & Ownership

No new persistent state. New note files are ordinary denote notes owned by
the corpus. The stub lives in the origin file. `my/denote-promote-targets`
is derived config, not user data.

### 5.4 Lifecycle, Operations & Dynamics

Promote flow edge-ordering matters: the origin position must be captured as a
marker **before** `denote-org-extract-org-subtree` mutates the buffer, and
the stub inserted **after** the new note's identity is known. The upstream
command leaves the new note buffer current (verify on install, R2); the
wrapper must `save-excursion`-equivalently restore the origin window/buffer.

Failure modes: user quits the target prompt (clean abort, buffer untouched);
extract signals (no subtree at point) — guard first with
`org-before-first-heading-p`.

### 5.5 Invariants, Assumptions & Edge Cases

- INV-1: promote never loses content — subtree text ends up in exactly one
  place (the new note), plus a stub link at the origin.
- INV-2: the new note always lands inside `dl-notes-root`, so denote links
  resolve after the `denote-directory` let unwinds.
- INV-3: heading tags → note keywords (upstream behaviour; filetags of
  journals are `journal`, acceptable inheritance).
- Edge: promoting a subtree containing sub-headings — upstream moves the
  whole subtree; fine, that is the point.
- Edge: promote from unsaved buffer — org-ql/denote unaffected; stub lands in
  buffer, user saves as normal.
- Assumption: let-binding `denote-directory` to a subdir for the duration of
  one extract call is safe (denote uses it for target dir + ID-uniqueness
  scan; timestamp IDs make cross-subdir collision negligible).

## 6. Open Questions & Unknowns

- OQ-1 (resolved at install-time): exact buffer/window state
  `denote-org-extract-org-subtree` leaves behind, and whether it returns the
  new file path. Wrapper design tolerates both "returns path" and "leaves
  buffer current"; pin the mechanism in the first red test after
  `home-manager switch`.

## 7. Decisions, Rationale & Alternatives

- D1 **Wrap upstream, don't reimplement.** `denote-org-extract-org-subtree`
  already handles title-from-heading, keyword inheritance, date derivation.
  Alternative (own implementation over `denote` primitives, ~40 lines) gives
  control but duplicates upstream logic. Wrapper + stub insertion ≈ 20 lines.
- D2 **Curated target list** over denote's subdirectory prompt (lists
  journal/, weekly/, intake/ — misfile bait) or default-to-slips (hides the
  classification decision entirely). User-confirmed.
- D3 **Heading stub + link** at extraction site, level-preserving. Journal
  keeps provenance; outline structure intact. User-confirmed.
- D4 **New module** `dl-denote-promote.el` rather than growing `dl-denote.el`
  (pure config) — the command has logic + tests; module stays single-purpose.
  The `(use-package denote-org :commands (denote-org-extract-org-subtree))`
  form lives in the new module — `:commands` keeps the load lazy so requiring
  `dl-denote-promote` pre-switch (tests, byte-compile) does not hard-fail on
  the missing package; `declare-function` + `skip-unless` cover the rest.
- D5 **Extend `dl-review.el`** for views — it owns review queries; adding a
  parallel module would be the exact parallel-implementation smell.
- D6 **`(todo)` org-ql predicate** for journal open items — matches any
  not-done keyword in the configured sequence (TODO/NEXT/STARTED/WAITING/
  MAYBE); corpus inspection shows plain TODO/NEXT usage, no bespoke scheme.
- D7 **Explicit-file-list dired** for recent notes (dired accepts
  `(dired (cons "name" files))`) — spans multiple class dirs without
  recursive-dired noise; reuses no new packages.

## 8. Risks & Mitigations

- R1 `denote-org` not parseable by emacs-overlay / name mismatch at switch
  time → mitigation: wire nix first (phase 1), verify before writing the
  wrapper; `declare-function` keeps byte-compile green meanwhile.
- R2 upstream extract behaviour differs from docs (OQ-1) → first test pins
  it; wrapper isolates the dependency to one call site.
- R3 org-ql `(todo)` over 61+ journal files slow → org-ql caches per-file;
  journal files are small; accept, measure only if felt.
- R4 stub insertion corrupts origin buffer on partial failure → insert stub
  only after note creation succeeded; guard + marker discipline; ert covers
  the quit path.

## 9. Quality Engineering & Validation

TDD red/green/refactor. Tests in new `org/dl-denote-promote-test.el` and new
`org/dl-review-test.el` (none exists today), following
`dl-denote-journal-test.el` conventions (batch-runnable, fixture macros).

- VT promote: temp `denote-directory` fixture; assertions — note file created
  in chosen class dir, subtree gone from origin, stub present at same level
  with resolving `denote:` ID, tags→keywords carried. Quit-at-prompt leaves
  origin byte-identical. `skip-unless (require 'denote-org nil t)` so the
  suite passes pre-switch.
- VT stub helper: pure string cases (levels 1–3, title escaping).
- VT review queries: temp corpus with planted TODO/NEXT/DONE journal
  headings; `org-ql-select` returns exactly the open ones.
  `my/review--recent-note-files` ordering + N-cap on planted mtimes.
- VH: promote a real journal subtree end-to-end; each new view surfaces a
  known item; keymap discoverability (which-key labels).
- Gates: `bin/elisp-locate-paren-error` per edited file, byte-compile zero
  warnings, `just check` green.

## 10. Review Notes

Adversarial self-pass (2026-07-12), findings integrated:

- RN-1 `(dired (cons NAME files))` claim was wrong — first element is the
  default-directory, not a label. Fixed §5.1: root = `dl-notes-root`,
  relative paths.
- RN-2 bare `(use-package denote-org)` requires at load → pre-switch
  hard-fail for tests/byte-compile. Fixed §5.1/D4: `:commands` autoload.
- RN-3 protocol.org entries are plain headings, so putting the file in the
  stale-WAITING scan buys little; drain path is `my/review-protocol`.
  Limitation named in §5.1.
- RN-4 curated target list includes work class dirs (10 entries), a widening
  of the user-approved "5 personal dirs" answer — justified by scope's
  "work parity where it falls out free"; flagging rather than hiding it.
- RN-5 marker semantics on deletion (markers collapse to deletion start)
  confirmed compatible with stub insertion point (§5.4).
- RN-6 no `dl-review-test.el` exists; named as new file in §9.
