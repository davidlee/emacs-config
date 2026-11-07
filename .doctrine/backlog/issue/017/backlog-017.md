# ISS-017: hl-line hides org TODO label backgrounds

<!-- Backlog item body — context, detail, links. The structured, queried fields
     live in the sister `backlog-NNN.toml`; this prose is free-form and is never
     structurally parsed (the storage rule). -->

`org-modern` paints TODO labels with a `face` text property (confirmed: no overlays on
the line). The `global-hl-line-mode` overlay beats text properties whatever its
priority, so on the current line the label loses its background and keeps its dark
foreground.

## Fix

`dl-org--hl-line-range` starts the highlight after the keyword, through a buffer-local
`hl-line-range-function`. Both `global-hl-line-highlight` and
`global-hl-line-window-redisplay` read it.

## Known limits

- Stars before the keyword are not highlighted on TODO lines.
- Tags (`org-modern-tag`) are painted the same way and still lose their background.
- Agenda pills (`hl-line-mode`) not checked.
