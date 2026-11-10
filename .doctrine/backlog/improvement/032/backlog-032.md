# IMP-032: Restore buffers after the daemon restarts with the session

<!-- Backlog item body — context, detail, links. The structured, queried fields
     live in the sister `backlog-NNN.toml`; this prose is free-form and is never
     structurally parsed (the storage rule). -->

## Context

The daemon (home-manager `services.emacs`) is bound to
`graphical-session.target` (flakes: `features/editor/emacs.nix`). PGTK Emacs
exits when its Wayland connection drops — GTK 3 limitation, stated in the
daemon's own startup warning — so every compositor restart, crash or logout
ends the daemon, and the session target starts a fresh one. Observed
2026-11-10: exits at 09:24 ("Error reading events from display: Broken pipe")
and 11:13 ("Lost connection to Wayland compositor.").

Nothing restores state: no `desktop-save-mode` in the config. Terminal
sessions already survive via zmx.

## Open questions

- `desktop-save-mode` (built-in) vs a lighter restore (recentf + savehist).
- What to restore: file buffers only, or window layout / frames too
  (frames are tied to the dead display; restoring them may be undesirable).
- Lazy restore (`desktop-restore-eager`) to keep daemon start fast.
- Save cadence: on a timer (`desktop-auto-save-timeout`), since a crash gives
  no `kill-emacs-hook`.

## Outcome (2026-11-10)

`editing/dl-session.el`: `desktop-save-mode`, file buffers only
(`desktop-restore-frames` nil), 5 eager then lazy, saved after 30 s idle.
`desktop-load-locked-desktop` is `check-pid`, so a crashed daemon's stale
lock doesn't block the restore. Verified by SIGKILLing a throwaway daemon
and restoring in a second one.

A frameless daemon skips `desktop-save`. Its conflict question ("Desktop
file is more recent than the one loaded…") goes to the initial terminal,
whose stdin is `/dev/null`, and hung the live daemon until restart.
Tests: `lisp/test/dl-session-test.el`.
