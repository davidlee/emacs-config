# IMP-024: org-ql keys: C-c n q searches notes corpus; bind org-ql-search and org-ql-view

<!-- Backlog item body — context, detail, links. The structured, queried fields
     live in the sister `backlog-NNN.toml`; this prose is free-form and is never
     structurally parsed (the storage rule). -->

## Problem

Checked live, 2026-10-14.

1. `C-c n q` (`org-ql-find`) is documented as corpus-scoped (`docs/KEYS.md`,
   `my/org-ql-find-here` docstring), but `org-ql-find`'s interactive form
   searches only the current Org buffer and errors outside Org. It duplicates
   `C-c o q`. Its which-key label still says "(Phase 5)".
2. `C-c n W q` (`my/work-org-ql-find`) let-binds `org-agenda-files`, which
   `org-ql-find` never reads, so it is also current-buffer-only.
3. `org-ql-search` and `org-ql-view` (7 preset views in `org-ql-views`)
   have no key.
4. `org-ql-select` silently drops directory entries. In `dl-review.el`,
   `my/review--notes-files` / `my/review--work-notes-files` mix files and
   dirs, so `my/review-stale` and `my/review-weekly` (and the work variants)
   search only the inbox/protocol files. Live: `(todo)` over
   slips+areas dirs → 0 hits; over the expanded file list → 6.

## Want

One shared "Org files in a scope" helper, used by the find, search and review
commands. `dl-gptel-mcp-org-files` (all notes outside `archive/`) and
`my/review--org-files-in` already compute overlapping sets; reuse them, don't
add a third. Corpus-wide query cost: 219 files, 1.9s the first time (buffers
opened), then ms.

Name the keys in `CHANGELOG.md` and `docs/KEYS.md` when done.

## Done (2026-10-14)

- `dl-notes-org-files` (`core/dl-notes-paths.el`): Org files below a dir,
  recursive, archive/ and excluded dirs pruned. Used by `dl-org-ql.el`,
  `dl-review.el` (`my/review--org-files-in`) and `dl-gptel-mcp-org-files`.
- Keys: `C-c n q` personal find, `C-c n Q` personal search, `C-c n V`
  `org-ql-view`, `C-c n W q` work find (renamed `my/org-ql-find-work-notes`).
- Review reports now pass files, not dirs.
- Tests: `lisp/test/dl-org-ql-test.el`, `dl-review-test.el` VT-5; shared
  fixture `lisp/test/dl-test-notes.el` (`dl-test-with-notes`), adopted by
  the gptel-mcp suite.
- Not done: no work-scoped `org-ql-search` key (`C-c n W Q`); add if wanted.
