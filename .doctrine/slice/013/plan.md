# Implementation Plan SL-013: Note-system revival: subtree promotion + review views

Prose companion to `plan.toml`. Narrative only — no queried data lives here
(the storage rule); the phase list, criteria, verification, and links are
authored in the TOML. Use this for the plan's rationale and sequencing.
<!-- Cite entities by padded id (SL-020, REQ-059); phases as PHASE-01,
     criteria as EN-1/EX-1/VT-1/VA-1/VH-1. See .doctrine/glossary.md § reference forms. -->

## Overview

Three phases. The split follows the one hard dependency in the design: the
`denote-org` package does not exist at runtime until the new module is
git-added and `home-manager switch` has run (AGENTS.md nix traps). Everything
that needs the installed package sits behind that gate; everything that
doesn't runs before or beside it.

## Sequencing & Rationale

**PHASE-01 — Wiring + pure scaffolding.** Front-loads the whole nix risk
(design R1): new file, `use-package denote-org :commands …`, `git add`,
`home-manager switch`. TDD is limited to the pure parts (stub-string helper,
curated targets alist) precisely so the phase is green regardless of switch
outcome — if `denote-org` fails to install, the failure surfaces here as
EX-3/VH-1, before any wrapper code exists to be stranded.

**PHASE-02 — Promote command.** Gated on PHASE-01 EX-3. First red test pins
the actual `denote-org-extract-org-subtree` behaviour (design OQ-1: what it
returns, which buffer is current after) so the wrapper is written against
observed behaviour, not docs. The quit-path test (EX-2/VT-2) covers design
R4 (origin-buffer integrity).

**PHASE-03 — Review gap-fill.** Depends only on PHASE-01 (for the
new-test-file pattern), not PHASE-02 — deliberately parallelisable with it
if dispatched; the two phases touch disjoint files except `dl-keymap.el`
(one binding each, different maps — trivially mergeable, but serial
execution avoids even that). Pure extension of `dl-review.el` plus the
`dl-notes-protocol-file` de-duplication (design D5, RN-3).

## Notes

- `home-manager switch` (PHASE-01 EX-3) rebuilds the emacs env; it is the
  slowest step in the slice and is carried as VH-1 in case the human prefers
  to run it themselves.
- Journal/weekly *test* files must not pollute the real corpus: all VT
  fixtures use temp dirs with let-bound path vars (defconsts are `special`,
  let-binding works), per `dl-denote-journal-test.el` precedent.
- CHANGELOG.md entry lands at close, per AGENTS.md.
