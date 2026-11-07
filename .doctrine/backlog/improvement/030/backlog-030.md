# IMP-030: umbriel buffer visual design: highlight focused/active, align columns, colour

<!-- Backlog item body — context, detail, links. The structured, queried fields
     live in the sister `backlog-NNN.toml`; this prose is free-form and is never
     structurally parsed (the storage rule). -->

From SL-016 PHASE-05 VH-1 (user, 2026-11-04): the `*umbriel*` buffer works but
its look needs work, out of SL-016's scope. Highlight the focused and active
windows (and workspaces) with faces rather than only the text marks; align the
row columns vertically; use colour. Code: `apps/dl-umbriel-buffer.el` render,
display strings in `apps/dl-umbriel-model.el`.

## Progress

- 2026-11-07, window rows: `active` (seat-global keyboard holder) shows
  `dl-umbriel-buffer-active-window` (inherits `isearch`); otherwise `focused`
  (each workspace's remembered focus, so several rows can have it) shows
  `dl-umbriel-buffer-focused-window` (inherits `highlight`). They are priority-1
  overlays, because magit's point highlight is an overlay and hides a text
  property.
- 2026-11-07, workspaces: an `active` workspace's rows and heading are shaded
  20% and 40% darker than `default`, derived in `core/dl-faces.el` and declared
  in the `user` theme so client frames keep them. The shades are text
  properties, below magit's point highlight and the row overlays.
- 2026-11-07, columns: the model returns named cells
  (`dl-umbriel-model-window-cells`, `-workspace-cells`) and labels are built from
  them. The buffer aligns with one-space `:align-to (N . width)` gaps; a bare
  number counts the frame's font, which is narrower than this buffer's. App,
  placement and flags have faces, and an active workspace's id is bold white.
- Open: fit the title to the window width instead of a fixed cap of 40.
