Stack, top to bottom: row mark overlays (`priority` 1), magit's point highlight (overlay, priority 0), `font-lock-face` text properties (cell faces, workspace shade).

- A row or heading face that must survive point has to be an overlay; one that must yield to point is a text property.
- Add to text properties with `font-lock-append-text-property`. `put-text-property` wipes the cell faces, and `font-lock-face` values are then lists.
- `magit-insert-heading` applies `magit-section-heading` only when the heading has no `font-lock-face` at all. One styled cell on a heading drops that face from the rest of the line.
- `:align-to N` counts the frame's font; use `(N . width)`. This buffer's font is wider than the frame's.
- Colours derived from `default` go in `ui/dl-faces.el` through `custom-theme-set-faces 'user`, because `set-face-*` is wiped on new frames. A `user` spec replaces the defface spec, so it must carry `:extend` and `:inherit`.
- In batch, `color-name-to-rgb` snaps to terminal colours; test with `#ffffff`.
- `foxglove-dark` is near monochrome: of the font-lock faces, only string, comment and `shadow` differ from `default`.
