# Extract SATAN to standalone Elisp package

## Context

SATAN is ~18,761 lines of elisp across 64 files in `satan/`, plus 989 ert tests
across 61 test files. It is loaded inline from `init.el` via `(require 'dl-satan)`
and treated as part of the config directory by Nix's `emacsWithPackagesFromUsePackage`.

POL-001's "earns the seat" policy has already identified individual modules that
should eventually leave elisp for Rust daemons (IMP-006..009), but those are
*selective* extractions of modules that don't use the editor as an editor. The
immediate need is coarser: move the entire SATAN codebase into a proper
standalone Elisp package as a prerequisite to future selective extractions.

## Scope & Objectives

### In scope

1. **Move all of `satan/`** into a standalone Elisp package at `~/dev/satan-el/`
   (or equivalent — determined in design).

2. **Rename the `dl-` and `my/` prefixes** throughout. SATAN as a standalone
   package owns its namespace:
   - `dl-satan-*` → `satan-*`
   - `dl-satan-db-*` → `satan-db-*` (already shared; renames with the rest)
   - Interactive `my/satan-*` commands → `satan-*` (or keep `my/` per naming
     convention — design-time decision)
   - `my/op-read-env` and `my/scrub-op-refs-env` usage (from `dl-secret`) →
     becomes a soft dependency with `declare-function` + `fboundp` guard (already
     soft, just rename)

3. **Resolve `dl-notes-paths` hard coupling.** SATAN's 6 files require
   `dl-notes-paths` for `dl-notes-root` and path constants. Replace with a
   `satan-notes-root` defcustom, set by the consuming config.

4. **Add proper ELPA package boilerplate:**
   - `satan.el` entry point (renamed from `dl-satan.el`)
   - Package headers (`;;; satan.el --- ...`), `Package-Version`, `Package-Requires`
   - `satan-pkg.el` (if needed for ELPA compatibility)
   - `(provide 'satan)` at the bottom

5. **Move all tests** (`satan/test/`) with the code. The test infrastructure
   (`dev/dl-test.el`) stays; it already discovers suites by directory.

6. **Wire into the config** without Nix magic:
   - Add the package repo or symlink to `load-path`
   - Add `(use-package satan …)` in `init.el` (or equivalent file)
   - Remove the old `(require 'dl-satan)` and all satan-related config dirs
   - Update `dl-sleipnir-doctor.el` references (soft `declare-function`, rename)

7. **Update `just check`** so the full test suite (including moved satan tests)
   still passes.

8. **Update docs** — `docs/satan/INDEX.md`, `governance.md`, `architecture.md`,
   and any references to the `satan/` directory structure in memory/CHANGELOG.

### Out of scope

- **Selective module extraction per POL-001** (IMP-006..009). This is the
  packaging prerequisite, not the daemon extraction itself. Those backlog items
  should become *easier* after the package boundary exists.
- **Rust/Go rewrites.** The code stays Elisp.
- **Architectural refactoring.** Renaming for namespace ownership is a mechanical
  transformation, not a redesign. No restructuring of modules, split/merge, or
  API changes except where the `dl-notes-paths` coupling demands a new defcustom.
- **Model-facing content** (`~/notes/satan/`). Already separated; not moving.
- **Updating `emacs.nix`** for the new package. User indicated Nix is unnecessary
  here; use `load-path` + `use-package`.

## Non-Goals

- Publishing to MELPA or any public package archive
- Changing SATAN's behaviour, invariants, or test expectations
- Consolidating defcustoms (130 scattered → single `satan-custom.el`) — deferred

## Summary

Extract SATAN into `~/dev/satan-el/` as a standalone Elisp package with its own
namespace (`satan-*`), its own tests, and a `satan-notes-root` defcustom
replacing the `dl-notes-paths` hard coupling. Wire it as a `use-package` with a
`load-path` entry. The config's existing `(require 'dl-satan)` and Nix config-dir
reference are removed. `just check` remains green.

## Follow-Ups

- IMP-006..009 (selective daemon extractions) — easier now that SATAN is a package
- Deferred: defcustom consolidation (`satan-custom.el`)
- Deferred: rename `my/` interactive commands inside SATAN (may be design-time decision)
