# CHR-009: Adopt zmux: retire apps/dl-zmx.el

<!-- Backlog item body — context, detail, links. The structured, queried fields
     live in the sister `backlog-NNN.toml`; this prose is free-form and is never
     structurally parsed (the storage rule). -->

`apps/dl-zmx.el` (added 2026-10-01, `33e2e9d`) is the config's own zmx plugin.
`~/dev/zmux` (first commit 2026-11-02) is the extracted successor: a wrapper that
writes `project`/`id` labels and births each session in its own systemd scope,
plus `emacs/dl-zmx.el` on top of it. The config copy is therefore **lag, not
drift** — it predates the extraction and still does work the wrapper now owns:

- launches `systemd-run --user --scope --collect --quiet` itself
  (`apps/dl-zmx.el:31`) instead of getting durability from the wrapper;
- derives and writes labels itself (`dl-zmx--label-safe`), which
  `~/dev/zmux/VOCABULARY.md` makes the wrapper's job;
- carries `dl-zmx-launcher`, `dl-zmx-command`, `dl-zmx-shell` defcustoms that
  the wrapper makes redundant or relocates.

Adoption means: install the zmux overlay in `~/flakes`, require
`~/dev/zmux/emacs/dl-zmx.el` (or code it into `emacs.nix`'s package set), delete
`apps/dl-zmx.el` and its `lisp/test/dl-zmx-test.el`, and re-point the `C-c p p`
menu registration and any keys. Verify a session survives a window-manager and
an `emacs.service` restart — the host-side manual check the zmux README names,
which is the whole point of the move.

Blocked on nothing, but not urgent: the current plugin works. Do it when zmx
sessions start needing the wrapper's labels (a picker, `state` reporting) — at
which point two implementations of the naming convention would be worse than
one.

Related: SL-016 (umbriel buffer) shares the frame/window question but not the
code; `~/dev/zmux`'s `e-umbriel` decision puts window management in this repo's
hands, so a future session-grouped buffer would consume zmx session names from
here too.
