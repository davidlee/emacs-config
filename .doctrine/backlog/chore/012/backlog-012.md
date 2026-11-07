# CHR-012: Run the config on Guix System

<!-- Backlog item body — context, detail, links. The structured, queried fields
     live in the sister `backlog-NNN.toml`; this prose is free-form and is never
     structurally parsed (the storage rule). -->

Run this config on a Guix System VM without changing behaviour on Nix hosts.

- `core/dl-guix.el` holds the Guix-only package handling. `:ensure` is off there,
  because it can't see Guix packages.
- `just guix-packages` fetches what Guix lacks into `elpa/`. Fetching is an explicit
  step, so startup stays offline and `package-archives` stays nil at runtime.
- `hunk-notes` and the `org-timeblock` fork are `:vc` entries in that module, not
  `use-package` stanzas, which would also clone on Nix.
- `core/dl-faces.el` loads `hl-line` itself; init aborted on Guix without it.

Governance: the user waived a slice for this change on 2026-11-08 and chose a backlog
item with direct commits.
