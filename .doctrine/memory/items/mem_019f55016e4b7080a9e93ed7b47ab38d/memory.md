# Emacs package wiring: manual list, two emacsen, devshell lags

No use-package parsing exists anywhere in the nix wiring (old AGENTS.md text
claiming emacsWithPackagesFromUsePackage was wrong; corrected 2026-07-12,
SL-013 PHASE-01).

## The one list

`~/flakes/pub/emacs.nix` — plain `emacsWithPackages` with a manual package
list. Adding a package = add one line there.

## Two consumers, one list

1. **Home profile emacs** (`~/.nix-profile/bin/emacs`): via
   `~/flakes/modules/home/emacs.nix` (imports `../../pub/emacs.nix`).
   Refresh: `home-manager switch --flake ~/flakes#david`.
2. **Devshell emacs** (what `just check` / batch ert use; direnv puts it on
   PATH in `~/.emacs.d`): via the `pub` path-flake input in
   `~/.emacs.d/flake.nix`, **lock-pinned**. Refresh: `nix flake update pub`
   in `~/.emacs.d` + `direnv reload` (new shells pick it up; the current
   shell keeps its old env).

Symptom of forgetting step 2: package loads in home emacs, `(require …)`
file-missing in tests.

## Lazy wiring for not-yet-installed packages

`(use-package NAME :commands (fn))` + `declare-function`: byte-compiles clean
under `byte-compile-error-on-warn` (emits an info message, not a warning),
loads fine, autoload binds when the package appears. Precedent:
`org/dl-denote-promote.el`.
