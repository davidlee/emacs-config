# IMP-022: otpp: killing a tab's last buffer closes the tab

<!-- Backlog item body — context, detail, links. The structured, queried fields
     live in the sister `backlog-NNN.toml`; this prose is free-form and is never
     structurally parsed (the storage rule). -->

## Problem

With otpp (one tab per project), killing the last buffer in a tab
shows a buffer from some other project. `kill-buffer` replaces the
window's buffer with its previous buffer; when the window has none,
Emacs falls back to `other-buffer`, which ignores tabs and projects.
Neither otpp nor Emacs 31 has an option to close the tab instead.
Only `project-kill-buffers` (`C-c p k`) closes the tab: otpp advises
it (`otpp--project-kill-buffers-a`) to close the tab, or reset it to
the default tab when it is the last one.

## Want

Killing the tab's last buffer closes the tab, through the same
close-or-reset path as otpp's `project-kill-buffers` advice (reuse it,
don't clone it). In `editing/dl-project.el`, with an ERT test.

## Open question

What counts as "last buffer"?

- the last live buffer of the tab's **project**: buffers from other
  repos shown in the tab don't count, and a project buffer open in
  another tab keeps this one alive; or
- the last buffer in the window's **tab-line**
  (`tab-line-tabs-fixed-window-buffers`): whatever that window has
  shown, whichever project it belongs to.

## Rejected alternative

`switch-to-prev-buffer-skip` with a predicate that skips buffers from
other projects: never closes the tab, and Emacs ignores it when no
buffer qualifies, so the stray buffer can still appear.
