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

Send-to-pad done 2026-11-07: `P` (`my/umbriel-send-to-pad`), `pointer-window` addressing.
The prompt offers held pads and takes free text; reading umbriel's config would couple
this code to its TOML layout. From umbriel source, not run live:

- `window-move-to-scratchpad` acts on the active workspace's remembered focus on the
  pointer's output (`FocusSource::Workspace`), not on the keyboard focus. A pad row or a
  row on another output would send a different window, so `P` refuses them. A workspace
  row is refused too, rather than sending whatever is focused.
- It does not move a window between pads: `admit` rejects an interactive move of a
  member. Use `m`, then `P`.
- The focus restore holds: `focused_window` is a workspace window, never a pad member.

`L` on a pad window stays refused, by the user's choice 2026-11-07: a pad window has no
layout, so the refusal now points to `C-c u l`. Remove-from-pad dropped by the user 2026-11-07: `m` and the
compositor's workspace move binds are enough.
Checked live by the user 2026-11-07: `P` works. The prompt then gained
`dl-umbriel-buffer-known-pads` (`main`), since an empty pad has no window to name it. Pads
exist only as `[[scratchpad]]` config entries, so `P` cannot create one.
