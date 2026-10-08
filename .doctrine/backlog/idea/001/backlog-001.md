# IDE-001: LSP coverage audit: servers per language/devshell; nixd resolving flake inputs

<!-- Backlog item body — context, detail, links. The structured, queried fields
     live in the sister `backlog-NNN.toml`; this prose is free-form and is never
     structurally parsed (the storage rule). -->

## Idea

Code-reading leans on xref / eglot. Make sure decent language servers
exist for the languages actually edited, mostly via per-project
devshells, and that `dev/dl-eglot.el`'s `eglot-server-programs`
covers them.

1. Survey: languages in `~/dev/*` and `~/flakes`, which devshells ship a
   server, which `eglot` attaches.
2. Nix: `nixd` and `nil` are on PATH. Jump-to-definition works within a
   flake but does not resolve into flake inputs' sources. Possibly
   because inputs are remote URLs; `nixd` can evaluate a flake's inputs
   (store paths) given `nixpkgs` / `options` settings via
   `eglot-workspace-configuration`. Unverified.
