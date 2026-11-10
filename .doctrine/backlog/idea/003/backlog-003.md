# IDE-003: umbriel frame identity: creation handshake maps each Emacs frame to its window id

<!-- Backlog item body — context, detail, links. The structured, queried fields
     live in the sister `backlog-NNN.toml`; this prose is free-form and is never
     structurally parsed (the storage rule). -->

## Problem

`umbriel-focus-frame` finds a frame's compositor window by `(pid, title)`;
two frames on the same buffer share a title, so it takes the first match.
GTK3 pgtk cannot set `xdg_tag` (xdg-toplevel-tag-v1), and `emacsclient -F`
only applies to frames emacsclient creates — the wrapper's `-r -n` reuse case
(`~/.config/zsh/functions.zsh:117`) is exactly when focus is needed. Frames
also come from `C-x 5 2`, `ec`, nudge's `raise-cycle-or-spawn`, SATAN evals.

## Approach (from SL-016 design, 2026-11-04)

Emacs assigns identity to every frame itself:

```
after-make-frame-functions (pgtk frame F)
  ├─ set F's title to a unique token "emacs-frame:<pid>:<n>"
  ├─ await (SL-016 DEC-020 waiter) a windows snapshot with our pid + token
  ├─ record F → window id (ext-foreign-toplevel id: stable for the window's life)
  └─ restore F's title
delete-frame-functions / window absent from a snapshot → drop the entry
```

- Focus then looks the id up; the zsh wrapper does not change.
- Cost: one title flicker per frame. Alternative: a permanent token in
  `frame-title-format` (no state, visible in bars).
- **Roles via `-F`:** `ec -F '((dl-frame-role . "notes"))'` names a frame;
  Emacs maps role → frame → id, so scripts can ask Emacs to focus or move "the
  notes frame". Emacs-frame `k:v` tags are then ordinary frame parameters.

## Related

- Depends on SL-016 (stream, held state keyed by id, waiter).
- Tags on non-Emacs windows need either an Emacs-side map or compositor-held
  metadata; the user is raising a `k:v` window-metadata interface with umbriel's
  developers (not ours to change).
- Unblocks the SL-016 follow-ups: collect/scatter Emacs frames, tag sets,
  zmx/ghostel composition.

- 2026-11-11 (SL-018): the client moved to the umbriel package, `~/dev/umbriel.el`. Paths and names above were rewritten to it (`dl-umbriel-*`, `my/umbriel-*` became `umbriel-*`; `my/umbriel-refresh` became `umbriel-buffer-refresh`).
