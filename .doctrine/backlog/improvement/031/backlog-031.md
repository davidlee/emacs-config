# IMP-031: umbriel buffer: send a window to a chosen scratchpad, remove it from its pad

<!-- Backlog item body — context, detail, links. The structured, queried fields
     live in the sister `backlog-NNN.toml`; this prose is free-form and is never
     structurally parsed (the storage rule). -->

- `m` already takes a window out of its pad and sends it to a chosen workspace
  (umbriel `window-move-to-workspace-silent`), so remove-from-pad may need only a key
  for `window-restore-from-scratchpad`, which returns it to its saved workspace.
- `L` refuses a pad window with "Window has no workspace". It could use the active
  workspace on the window's `output`.
