# IMP-033: umbriel package: font/icon fallback, theme-neutral default faces, styling docs

<!-- Backlog item body — context, detail, links. The structured, queried fields
     live in the sister `backlog-NNN.toml`; this prose is free-form and is never
     structurally parsed (the storage rule). -->

Package work in `~/dev/umbriel.el` (records stay here, DEC-037). Seen in an
`emacs -Q` run of the package after SL-018 (2026-11-11). One card for the
leftovers; split only if one grows.

1. **Icon fallback admits fonts without the glyph.** `umbriel-buffer--icon`
   (`umbriel/umbriel-buffer.el:244`) tests `char-displayable-p`, which passed
   for Nerd Font private-use icons (U+F0E73, U+F030C, U+F04FE) that then drew
   as hex boxes. Inference: fontset fallback claims the PUA range; test the
   chosen font instead (`font-has-char-p` / `internal-char-font`). Layout
   pills pass a `nil` fallback (:309), so they get no text form at all.
2. **Default faces are not theme-neutral.** Under no theme the hard-coded
   defaults read badly (saturated green highlight bars, brown/red text). The
   config's `user`-theme shading (`ui/dl-faces.el:344-380`) hides this. Make the
   defface specs inherit standard faces (`highlight`, `shadow`,
   `font-lock-*`, `magit-section-*`).
3. **Styling docs.** README: icons need a Nerd Font, how to turn them off,
   the face list and what each styles.
4. **Narrow-frame title clipping (unconfirmed).** In a ~400px frame window
   titles clipped on the left and lost alignment with headings. Needs a repro.

Related config leftover: `custom-vars.el:81-84` saves fixed colours for four
`umbriel-buffer-*` faces that `ui/dl-faces.el` also computes; they look like a
stale Customize snapshot and override the theme-tracking shades until a theme
change.

**Added 2026-11-11 (user):**

5. **Pills in the default faces.** Without the config's shading, names and
   layouts read as plain text. The defaults should give pill faces a
   background (workspace names, scratchpad names, layouts) so the pill
   shape shows under any theme.
6. **Visible-workspace icon.** A workspace heading should carry the
   `visible` flag icon (eye, U+F0208) when that workspace is on screen. The
   wire's workspace record has `active`/`focused`/`urgent` and no `visible`
   (live query, 2026-11-11); headings currently put `active` in the `active`
   column. Open: is a workspace's `active` exactly "shown on its output"? If
   so, map it to the `visible` column for headings.
