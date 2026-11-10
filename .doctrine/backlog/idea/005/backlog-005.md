# IDE-005: foxmacs: control Firefox from Emacs under EWM

<!-- Backlog item body — context, detail, links. The structured, queried fields
     live in the sister `backlog-NNN.toml`; this prose is free-form and is never
     structurally parsed (the storage rule). -->

## Context

github.com/adisbladis/foxmacs — Emacs package + Firefox extension over native
messaging (hints, page search, reader buffer, edit fields, org capture). Needs
EWM: it ties a buffer to a Firefox window via `ewm-surface-title` +
`ewm-update-title-hook`; 9 of its 11 commands refuse outside an EWM surface
buffer ("Not a Firefox buffer"). EWM installed 2026-11-10 (flakes `bfca9a78`).

Its flake ships `lib.emacsOverlay` (elisp), `foxmacs-extension`, `foxmacs-host`
(native messaging host, needs socat). Also `tabs-to-windows` extension (each
tab its own window — EWM's one-buffer-per-window model).

## Blocker: unsigned extension

Host Firefox is release `pkgs.firefox` (flakes `features/web.nix`), which
enforces signing. Options:
- Firefox Developer Edition (honours `xpinstall.signatures.required=false`).
- Firefox built with signing off (no binary cache; hours of build).
- Self-sign as an unlisted AMO add-on (account; uploads the extension).

## Progress (2026-11-10)

Decided (user): Firefox Developer Edition via home-manager, not the
NixOS-level `programs.firefox`; tabs-to-windows and its window prefs on in
every session; keys as a prefix in `ewm-mode-map`. EWM's leftover systemd
env stays unfixed for now (manual workaround in
mem.fact.emacs.daemon-session-lifetime).

Wired, uncommitted, built (`just home-build` green; system dry-run evaluates):
- flakes `foxmacs` input (root + `flakes/emacs`, root `follows`, one pin).
- `flakes/emacs/emacs.nix`: `(foxmacs.lib.emacsOverlay epkgs epkgs).foxmacs`.
- `features/web.nix`: `firefox-devedition.override { extraPrefs }`
  (`xpinstall.signatures.required=false`, open-in-window prefs);
  `nativeMessagingHosts = [foxmacs-host]`; `globalExtensions` foxmacs +
  tabs-to-windows (force-installed by policy; `passthru.addonId` added).
- `features/desktop/core/gui.nix`: `firefox-devedition` in 1Password's
  allowed browsers (the binary is no longer named `firefox`).
- `apps/dl-foxmacs.el`: `:after ewm`, `foxmacs-mode`, `s-b` o/h/s/j/r/e/c/u
  in `ewm-mode-map` (s-b is free in EWM's defaults).

Not done: `home-manager switch` + `nixos-rebuild switch`; check in an EWM
session; profile choice (below).

Profile: Dev Edition starts its own `dev-edition-default` profile, not
`ez06zp0k.default` (the main one, which malebolge reads bookmarks from).

## Open

- Which Firefox route.
- Wiring: elisp into flakes/emacs package list; host manifest via
  `programs.firefox.nativeMessagingHosts.packages`.
- `apps/dl-foxmacs.el`, loaded only in an EWM session.
