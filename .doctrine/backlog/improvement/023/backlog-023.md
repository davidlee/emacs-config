# IMP-023: Global Nix tooling for diagnostics: linters for nix-mode buffers

<!-- Backlog item body — context, detail, links. The structured, queried fields
     live in the sister `backlog-NNN.toml`; this prose is free-form and is never
     structurally parsed (the storage rule). -->

## Problem

Language tooling normally comes per project (devenv / nix-direnv), but
Nix files (`~/flakes`, each repo's `flake.nix`) are edited outside any
project shell, so they need global tooling. The diagnostics setup
(`dev/dl-diagnostics.el`, 2026-10-13) runs flycheck's checkers through
Flymake: a checker only runs if its executable is on `PATH`.

State on Sleipnir (2026-10-13): on PATH — `nixd` (eglot's server for
`nix-mode`), `nil`, `nixfmt`, `alejandra`. Missing — `statix` (lints),
`deadnix` (unused bindings). flycheck's `nix` checker
(`nix-instantiate --parse`) already runs in `nix-mode` buffers.

## Want

- Decide the global Nix toolset and add it to the home profile in
  `~/flakes` (not the emacs package list).
- Confirm in a `nix-mode` buffer which flycheck checkers become usable
  (`flycheck-nix-statix`? check names with `flycheck-describe-checker`)
  and that they don't duplicate nixd's diagnostics; disable twins via
  `flycheck-disabled-checkers` as done for elisp/shellcheck.
- Formatter: nixd formats via eglot on save (`my/eglot-on-save-setup`);
  confirm which formatter it uses (`nixfmt` vs `alejandra`).
