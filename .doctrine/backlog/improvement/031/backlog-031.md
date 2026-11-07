# IMP-031: umbriel buffer: send a window to a chosen scratchpad, remove it from its pad

<!-- Backlog item body — context, detail, links. The structured, queried fields
     live in the sister `backlog-NNN.toml`; this prose is free-form and is never
     structurally parsed (the storage rule). -->

- `m` already takes a window out of its pad and sends it to a chosen workspace
  (umbriel `window-move-to-workspace-silent`), so remove-from-pad may need only a key
  for `window-restore-from-scratchpad`, which returns it to its saved workspace.
- `L` refuses a pad window with "Window has no workspace". It could use the active
  workspace on the window's `output`.

Send-to-pad facts, checked 2026-11-07:

- `window-move-to-scratchpad [<scratchpad>]` acts on the focused window, so it fits
  `focused` addressing in `dl-umbriel-buffer-actions`. A name is required once named
  pads are configured.
- Its docs say "focused workspace window". Whether it moves a window between pads is
  unverified.
- The IPC has no pad listing. Held windows give only pads with members; configured
  pads live in `[[scratchpad]]` tables in umbriel's config. So a prompt either misses
  empty pads, or takes free text and lets umbriel reject an unknown name.
- `window-restore-from-scratchpad` needs the pad to be visible.
- Free in `dl-umbriel-buffer-mode-map` and `magit-section-mode-map`: `P`, `z`, `S`, `x`,
  `r`. `p` is `magit-section-backward`.
