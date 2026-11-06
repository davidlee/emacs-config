# ISS-014: diff-hl-flydiff-mode void at apps/dl-magit.el:30 in batch runs (just check logs a use-package :config error)

<!-- Backlog item body — context, detail, links. The structured, queried fields
     live in the sister `backlog-NNN.toml`; this prose is free-form and is never
     structurally parsed (the storage rule). -->

## What

`just check` logs `Error (use-package): diff-hl/:config: Symbol's function
definition is void: diff-hl-flydiff-mode`, from `apps/dl-magit.el:30`, on the
host and in the jail. No test fails on it. Cause not investigated; it may be
specific to `--batch -Q`, or a missing `require` of `diff-hl-flydiff`.

## Provenance

Seen while fixing the jail test failures, 2026-11-06.
