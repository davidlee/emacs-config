# CHR-002: Extract ediff config from dl-magit.el into its own module

<!-- Backlog item body — context, detail, links. The structured, queried fields
     live in the sister `backlog-NNN.toml`; this prose is free-form and is never
     structurally parsed (the storage rule). -->

## Context

The `(use-package ediff …)` block lives in `apps/dl-magit.el`, but most of
it is not magit-specific: window setup, split direction, diff options, and
the plain-session window-config save/restore hooks
(`dl-magit--ediff-save-winconf` / `dl-magit--ediff-restore-winconf`).
Magit sessions bypass the global `ediff-quit-hook` entirely (magit sets it
buffer-locally), so the restore hooks only serve non-magit ediff.

## Proposal

Move the block to its own module (e.g. `apps/dl-ediff.el`, feature
`dl-ediff`), rename the private helpers to `dl-ediff--*`, move the test
`lisp/test/dl-magit-test.el` → `dl-ediff-test.el`, and `require` it from
`init.el` next to `dl-magit`. Remember to `git add` the new file (flake
builds only see tracked files).
