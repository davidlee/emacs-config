# Emacs daemon lifetime is tied to the Wayland session

Verified 2026-11-10 (journal, Emacs source `pgtk_delete_terminal`, `startup.el`).

- **PGTK Emacs cannot survive losing its compositor.** GTK 3 exits the process
  ("Lost connection to Wayland compositor." → status 1); Emacs prints a
  warning saying so at every daemon start. So the daemon is home-manager
  `services.emacs` with `startWithUserSession = "graphical"` + `Requisite=`
  (flakes: `features/editor/emacs.nix`). Socket env (`WAYLAND_DISPLAY`,
  `UMBRIEL_SOCKET`) comes from the user manager at unit start; a daemon
  started earlier has none and `my/umbriel` shows `no-path`.
- **EWM** (Emacs as compositor; flakes feature `compositor.ewm`): DRM-only,
  **no nested mode** — run `ewm-session` from a VT or pick it at the greeter.
  Launched under umbriel it waits forever for seat activation and imports its
  env into systemd anyway.
- **One user manager, shared by every session.** EWM imports
  `XDG_CURRENT_DESKTOP=ewm`, `WAYLAND_DISPLAY=wayland-ewm-vt2`, `DISPLAY=:2`
  and leaves them (DISPLAY always; the rest unless `ewm-session` exits
  cleanly). The emacs unit's `ConditionEnvironment=!XDG_CURRENT_DESKTOP=ewm`
  then skips it in umbriel. Fix: `systemctl --user set-environment
  XDG_CURRENT_DESKTOP=umbriel WAYLAND_DISPLAY=wayland-0 DISPLAY=:0`, then start
  `emacs`.
- **One server name.** A daemon claims `server` *after* running its `--eval`
  args. If another Emacs holds it, the EWM daemon has already drawn its frame,
  then `(kill-emacs 1)` → EWM stops → `Restart=on-failure` loop. The "Unable
  to start the daemon" message goes to the frame's echo area, not the
  journal. Stop the other daemon first.
