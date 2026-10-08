# IMP-020: Org dynamic block: table of denote links with file-level property values

<!-- Backlog item body — context, detail, links. The structured, queried fields
     live in the sister `backlog-NNN.toml`; this prose is free-form and is never
     structurally parsed (the storage rule). -->

## Problem

No installed dynamic block can tabulate a property across many notes.
`denote-links` lists notes by filename regexp only. The `org-ql` and
`columnview` blocks read headings in one buffer and ignore file-level
property drawers.

## Want

A small generic block, e.g. `#+BEGIN: denote-properties :regexp "…"
:properties ("LEVEL" "EVIDENCE")`, that renders a table: one row per
matching denote note, a link column, then each property's file-level
value (blank when absent). Sortable by a property. Reuses
`denote-org-dblock--files` (or its public equivalent) for file
selection, so `:regexp` / `:not-regexp` / excluded dirs behave like
`denote-links`.

## Use

Any denote note set that carries status in file-level properties: the
emacs-coach skill's capability nodes (`:LEVEL:`), project status notes.
Until then, those indexes use `denote-links` per tag and `rg` for
property values.
