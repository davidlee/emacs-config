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

## Open

- Which Firefox route.
- Wiring: elisp into flakes/emacs package list; host manifest via
  `programs.firefox.nativeMessagingHosts.packages`.
- `apps/dl-foxmacs.el`, loaded only in an EWM session.
