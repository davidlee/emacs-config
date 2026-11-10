# ISS-018: umbriel controller misbehaves inside a scratchpad frame: q and row-action focus

<!-- Backlog item body — context, detail, links. The structured, queried fields
     live in the sister `backlog-NNN.toml`; this prose is free-form and is never
     structurally parsed (the storage rule). -->

The umbriel config now shows `*umbriel*` in a floating scratchpad: a frame named
`umbriel-controller`, in pad `umbriel`, opened by `spawn_when_empty` and toggled by
`Ctrl+Alt+Shift+U` (`~/.config/umbriel/apps.toml`). Two controller behaviours assume
a workspace frame and go wrong in that pad.

## 1. `q` replaces the buffer in the pad frame

`q` is `quit-window`. In the pad frame it shows another buffer, and the next toggle
shows that buffer instead of `*umbriel*`. Toggling the pad closed works meanwhile.

Evidence: 2026-11-07, `quit-window` in the live frame left a different buffer in it,
with the frame alive and the pad still visible.

Proposed: in a frame whose window is a pad member, `q` toggles that pad; elsewhere it
stays `quit-window`. The pad name comes from the held window
(`umbriel-window-id`, `umbriel-model-window-scratchpad`), so Emacs hard-codes
neither the pad nor the frame name.

## 2. Row actions move keyboard focus out of the pad

A `focused` plan ends by restoring `focused_window` of the focused workspace
(`umbriel-buffer--focus-act-restore`, DEC-025). With a pad window focused, that
field still names the workspace window behind the pad. So `c`, `e`, `<` and the like
leave the pad visible with the keyboard on the workspace window.

Evidence: 2026-11-07, with the controller (`8443e899`) active, the workspace reported
`focused_window` `17148c26`, and `umbriel-buffer--previous-focus` returned that id.
Inferred from this and the code: no row action was run from the pad. `window-focus` on
another window does leave the pad visible (tested).

Proposed: restore the window that held focus, taken from the held windows' `active`
flag, when that is a pad member.

- 2026-11-11 (SL-018): the client moved to the umbriel package, `~/dev/umbriel.el`. Paths and names above were rewritten to it (`dl-umbriel-*`, `my/umbriel-*` became `umbriel-*`; `my/umbriel-refresh` became `umbriel-buffer-refresh`).
