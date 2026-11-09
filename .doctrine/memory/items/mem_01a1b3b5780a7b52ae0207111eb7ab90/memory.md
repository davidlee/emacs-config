- `window-width` counts the frame's font. In a buffer with a `default` remap it overstates: `*umbriel*` showed 128 for 102 real columns. Use `window-max-chars-per-line`, which is correct from an unselected window too.
- `(face-font FACE FRAME CHAR)` names the font FACE uses for CHAR, and returns nil when none has it, which draws a hex box. Without CHAR it only names the face's ASCII font.
- `fontset-font` does not report what `set-fontset-font` set: it returned nil right after a set, even in a clean batch run. Test the rule installed, or use `face-font` on a live frame.
- `(fontp (char-displayable-p CHAR))` is true only when a real font has CHAR. Without `fontp` it misleads: it returned `unicode` for an unassigned codepoint. It tests the default face, not a given face.
- `(find-font (font-spec :family NAME))` tells whether a family resolves. An unresolved `:family` falls back silently.
- `defface` does not redefine a live face on `load`. To reload one, `(put FACE 'face-defface-spec nil)` first.
- `select-window` plus `(redisplay t)` from `emacsclient --eval` did not draw the active mode or header line, so `x-export-frames` cannot show the selected state that way.

- From `emacsclient --eval`, `(car (visible-frame-list))` can be the daemon's terminal frame: faces report `unspecified-fg` and `x-export-frames` refuses it. Use `(seq-find #'display-graphic-p (frame-list))`.
- To learn which font a mode line really draws each character in, render it and ask per character: bind `lambda-line--selected-window` to the window, take `(format-mode-line mode-line-format nil WINDOW)`, then `(font-at I WINDOW STRING)`. This showed unfaced segment text drawing in the `default` face's font while `face-font` of `mode-line` named the right one; a 3x screenshot could not tell the two monospace fonts apart.
