# Emacs package wiring: manual list, two emacsen

No use-package parsing exists anywhere in the nix wiring (old AGENTS.md text
claiming emacsWithPackagesFromUsePackage was wrong; corrected 2026-07-12,
SL-013 PHASE-01).

## The one list

`~/flakes/emacs/emacs.nix` — plain `emacsWithPackages` with a manual package
list. Adding a package = add one line there. `~/flakes/emacs/flake.nix`
exports it as `packages.default` with its own nixpkgs/emacs-overlay pins
(split out of `pub` 2026-09-23 so pub carries no emacs-overlay).

## Two consumers, one list

1. **Home profile emacs** (`~/.nix-profile/bin/emacs`): via
   `~/flakes/modules/home/shared/emacs.nix` (imports `../../../emacs/emacs.nix`
   with the host's pkgs — a separate build from the devshell's).
   Refresh: `just home-switch`.
2. **Devshell emacs** (what `just check` / batch ert use; direnv puts it on
   PATH in `~/.emacs.d`): the `emacs` flake input. `.envrc` runs
   `use flake_local pub emacs`, which overrides the input with
   `path:~/flakes/emacs` and watches its files — so an edit there lands on the
   next `direnv reload`, no lock bump. Plain `nix develop` / CI read
   `flake.lock`: `nix flake update emacs`. satan's devshell shares the same
   derivation (no `follows` on the input, by design).

Symptom of a stale devshell: package loads in home emacs, `(require …)`
file-missing in tests — `direnv reload` (the current shell keeps its old env).

## Lazy wiring for not-yet-installed packages

`(use-package NAME :commands (fn))` + `declare-function`: byte-compiles clean
under `byte-compile-error-on-warn` (emits an info message, not a warning),
loads fine, autoload binds when the package appears. Precedent:
`org/dl-denote-promote.el`.
