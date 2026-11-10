# ISS-020: just lint fails intermittently: Invalid face errors from org/dl-org.el

<!-- Backlog item body — context, detail, links. The structured, queried fields
     live in the sister `backlog-NNN.toml`; this prose is free-form and is never
     structurally parsed (the storage rule). -->

## Observed (2026-11-11, during CHR-010)

`just lint` sometimes fails, with no code change between runs:

```
org/dl-org.el:72: warning: reference to free variable 'org-bullets-mode'
org/dl-org.el:114: error: Invalid face: org-heading      (or: Invalid face attribute name: weight)
test/dl-faces-test.el:7: error: (same)
test/dl-org-test.el:6: error: (same)
```

Line 114 is `(require 'org-pretty-table)` (from `elpa/org-pretty-table`).
It failed in about half of the runs this session, in both the main tree and a clean worktree of
the CHR-010 commit; the next run often passes.

## Inference (not verified)

Something outside the run changes state: perhaps the live daemon
(compile-angel) rewriting `.elc` files under `load-prefer-newer`, or
`core/dl-faces.el` being edited at the same time. `dl-faces` is loaded by both
failing tests and by `dl-org`.

## Closed (2026-11-11)

The user reports the failures came from their own cleanup running at the
same time (leftovers from an earlier agent, in `core/dl-faces.el`). Not a
defect in the gate.
