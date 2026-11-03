# Daemon startup: no graphical frame yet

The server is started from `init.el`, so the first frame is a **terminal**
frame. Anything resolved from the display at that point is wrong or missing:

- `(face-attribute 'default :background)` answers `unspecified-bg` (or the
  theme's tty clause), not the real colour.
- `unspecified-bg` is not a colour: `set-face-foreground` accepts it and the
  face then draws in the default foreground (a light bar between windows).
- `default-frame-alist` bg/fg stay empty, so new frames open with a flash.

## Rule

Code on `enable-theme-functions` that reads resolved face or frame state must
be **idempotent**. `my/refire-theme-hooks-on-graphical-frame` (`core/dl-faces.el`)
re-runs that hook for the enabled themes on each graphical frame, so hooks
that skipped at startup (guard with `color-defined-p` / `display-graphic-p`)
get a second go. Don't add a per-feature `after-make-frame-functions` hook.

## Related

- `set-face-*` edits are wiped when a theme recalcs faces (new frames,
  `spacious-padding`). Declare computed values in the `user` theme with
  `custom-theme-set-faces` instead (`my/apply-line-number-faces`,
  `my/blend-borders-into-background`).
- Reproduce without a restart: wipe the `user` entry from the face's
  `theme-face` property, then `(make-frame '((visibility . nil)))`.
