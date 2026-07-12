# Note-system revival: subtree promotion + review views

## Context

Diagnosis (2026-07-12) of the denote note system (plan note
`projects/20260516T212927--emacs-note-system`): capture works, promotion and
retrieval are dead. 61 journals vs ~15 durable notes; 23 `denote:` links in the
whole corpus; four capture surfaces (inbox.org, protocol.org, intake/, journal
headings) none of which drain. Root cause: journal-scratch → durable-note
promotion is fully manual (create, retype, re-tag, link back), and nothing
resurfaces captured content.

Corrective finding during scoping: `org/dl-review.el` (158 lines) already
exists — navigational + reporting review surfaces bound under `C-c n v` /
`C-c n W v`. Phase 4 was *partially* built. Remaining gaps are narrower than
the original diagnosis assumed.

## Scope & Objectives

**A. One-keystroke promotion (the biggest lever).**
Wrap `denote-org-extract-org-subtree` (from the `denote-org` package — not yet
installed) so a journal/inbox subtree at point becomes a durable denote note in
a prompted class dir, leaving a `denote:` link behind at the extraction site.
Bind under the notes keymap. New small module or addition to `dl-denote.el`.

**B. Review-view gap-fill in `dl-review.el` (extend, don't rebuild):**
- Unresolved journal "Next" view — journal content currently dies silently.
- Add `protocol.org` (capture target, `my/notes-path "protocol.org"`, see
  `dl-org-capture.el:120`) to the scanned review surfaces — it is invisible
  to every existing view.
- Recently-touched durable notes view (promotion payoff needs to be visible).

Affected surface:
- `org/dl-denote.el` or new `org/dl-denote-promote.el` (new `use-package
  denote-org` form → **requires `git add` + `home-manager switch`**, per
  AGENTS.md nix traps)
- `org/dl-review.el` — new/extended query functions
- `core/dl-notes-paths.el` — likely a `dl-notes-protocol-file` defconst
- `core/dl-keymap.el` — bindings under `C-c n` (promote) and `C-c n v` (views)
- Tests: ert, following `org/dl-denote-journal-test.el` conventions

## Non-Goals

- Inbox consolidation (intake/ vs inbox.org vs protocol.org merge) — deferred,
  backlog candidate.
- Note-class collapse (six classes + work mirror) — deferred.
- Backlinks surfacing / denote-explore orphan audit — premature until links
  exist.
- Work-compartment mirror of the promote command beyond what falls out free —
  parity can follow usage.

## Summary

Two fixes to revive a write-only note system: make journal→durable promotion
one keystroke, and fill the three review-view gaps so captured content
resurfaces. Extends existing `dl-review.el` rather than building a parallel
review module.

Risks / assumptions:
- `denote-org` availability via emacs-overlay MELPA parse — assumed fine
  (denote + denote-explore already installed this way); verify at
  `home-manager switch` time.
- `denote-org-extract-org-subtree` behaviour (link left behind, front-matter
  inheritance) assumed from denote-org docs; verify against installed version
  before wrapping.
- org-ql "Next" query shape depends on how journal Next items are marked
  (TODO keyword vs plain heading) — inspect journal corpus during design.

Verification / closure intent:
- ert coverage for promote wrapper (tmp-dir denote corpus fixture) and for
  new review queries (VT).
- Manual: promote a real journal subtree end-to-end; each new view surfaces
  known-planted items (VH).
- `just check` green; zero byte-compile warnings.

## Follow-Ups

- Backlog: inbox consolidation (one triage surface + weekly drain ritual).
- Backlog: class collapse decision once dirs have content.
- Later slice: backlinks binding + orphan audit once link density justifies it.
