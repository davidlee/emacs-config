# IMP-029: Package nostr.el and its Rust backend in emacs.nix from one pinned rev

<!-- Backlog item body — context, detail, links. The structured, queried fields
     live in the sister `backlog-NNN.toml`; this prose is free-form and is never
     structurally parsed (the storage rule). -->

## Context

`apps/dl-nostr.el` installs nostr.el with `:vc` and points
`nostr-backend-command` at `elpa/nostr/target/release/nostr-el-backend`,
built by hand with `cargo build --release`. The elisp and the backend
share a JSON protocol whose `protocol_version` nostr.el displays but never
checks, so a `package-vc-upgrade` without a rebuild can drift silently.

## Proposal

In `~/flakes/emacs/emacs.nix`, build nostr.el (`trivialBuild`) and
`nostr-el-backend` (`rustPlatform.buildRustPackage`, cargoLock from the
repo's `Cargo.lock`) from the same `fetchFromGitHub` rev (currently
`a6b24f0`, 2026-06-13). Put the backend on Emacs's PATH, drop `:vc` and
the hand-built path from `dl-nostr.el`. Upgrade = bump one rev + hash.
