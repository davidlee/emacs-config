# Extract umbriel client to standalone Elisp package

## Context

The umbriel client is the Emacs side of the umbriel compositor's IPC socket
(env `UMBRIEL_SOCKET`). It lives in `desktop/dl-umbriel{,-model,-columns,-focus,-buffer}.el`
(1,927 lines) with five ERT suites in `test/dl-umbriel*-test.el` (4,959
lines). It is the largest self-contained module family left in the config.

IDE-006 proposed extracting it. On 2026-11-11 the user settled IDE-006's
open question: the client is meant for use outside this config, and gets
its **own repo** (not the compositor's repo, not staying here).

POL-001's test ("does it use the editor as an editor?") is about process
boundaries (elisp vs daemon). This slice moves a repo boundary only: the
code stays elisp and runs in Emacs. So POL-001 does not govern it.

SL-012 (SATAN extraction) is the worked example for this pattern.

## Scope & Objectives

### In scope

1. **New repo** for the package (path and name are decided in design;
   working name `~/dev/umbriel.el`). It holds the five modules, their tests,
   a test runner, and package headers (`Package-Requires` lists
   `magit-section`).
2. **Namespace.** `dl-umbriel-*` → `umbriel-*` (functions, variables, faces,
   features, files). Interactive `my/umbriel-*` (buffer.el:640-1082, entry
   `my/umbriel`) → `umbriel-*`. Design settles collisions and whether to
   keep obsolete aliases.
3. **Self-location**, if any package-owned paths exist. The probe found no
   `user-emacs-directory` / `dl-dirs` use in the umbriel files. Design
   confirms this.
4. **Config couplings become package surface.** The config consumes the
   package only through its public commands, faces and defcustoms:
   - `init.el:32-33` requires → `use-package umbriel …` in a single
     `desktop/` integration file (as `ai/dl-satan.el` does for SATAN).
   - `keys/dl-keymap.el:198-201` declare-functions, `:256` `my-umbriel-map`,
     `:275` `C-c u`, `:627`; `keys/dl-meow-map.el:279` `"u"`. The keymap stays
     in the config and binds the renamed commands.
   - Faces: `ui/dl-faces.el:344-380` (`my/shade-umbriel-*`),
     `custom-vars.el:81-84` (`dl-umbriel-buffer-*` saved faces),
     `test/dl-faces-test.el:8,81-113` — renamed to the package's face names.
5. **Load path wiring.** Follow the current SATAN mechanism: add the checkout
   to `dl-dirs-checkouts` (`core/dl-dirs.el:35`) and load with
   `use-package … :ensure nil`. (Evidence: SATAN is wired this way, not by a
   Nix input — `~/flakes/emacs/emacs.nix` has no satan entry. The IDE-006
   handover said otherwise.) Whether umbriel also needs the stale-`.elc`
   compile shim (`ai/dl-satan.el:9-17`) is a design question. Prefer one
   shared helper over a copy (DRY).
6. **Tests.** The moved suites pass in the new repo. `just check` here
   stays green with the umbriel tests gone and `dl-faces-test` updated.
7. **Docs.** `docs/emacs/umbriel.md` moves to the new repo or is cut to a
   pointer. Update AGENTS.md / CHANGELOG / the five open umbriel backlog
   cards.
8. **Backlog disposition.** Decide per item whether IMP-030, ISS-012,
   ISS-015, ISS-018, IDE-003 move to the new repo's tracker or stay here.
   IDE-006 resolves when this slice closes.

### Out of scope

- Behaviour changes. This is a mechanical move plus rename. No API redesign,
  no module split or merge.
- Fixing the open umbriel issues (ISS-012/015/018) or finishing IMP-030.
- Publishing to MELPA or another archive.
- The compositor itself.
- The user's uncommitted `ui/dl-faces.el` edits: they are theirs. The
  face renames in that file must land after, or on top of, those edits.

## Affected surface

- `desktop/dl-umbriel*.el` (removed from here)
- `test/dl-umbriel*-test.el` (removed from here)
- `init.el`, `core/dl-dirs.el`, `keys/dl-keymap.el`, `keys/dl-meow-map.el`
- `ui/dl-faces.el`, `custom-vars.el`, `test/dl-faces-test.el`
- new `desktop/` integration file (name decided in design)
- `docs/emacs/umbriel.md`, `AGENTS.md`, `CHANGELOG.md`
- new repo (outside this checkout)

## Risks, assumptions, open questions

- **Assumption:** The coupling probe was bounded, not exhaustive. Design
  repeats it with `rg 'umbriel'` across the whole tree.
- **Risk:** `custom-vars.el` holds saved faces under the old names. A
  rename without migrating them silently drops the user's face settings.
- **Risk:** the daemon loads the config at start. A half-done rename breaks
  `C-c u` and the meow `u` binding until the user restarts the daemon.
- **Open:** repo name and path, and whether it gets a GitHub remote
  (outward-facing: confirm with the user before pushing).
- **Open:** keep `dl-umbriel-*` obsolete aliases for one release, or cut
  over in one step? (SL-012 cut over in one step.)
- **Open:** do the decisions that bind the code shape (DEC-013, -014, -017,
  -027, -028, -030, -031) move with the code or stay here as history?

## Verification / closure

- New repo: its ERT suites pass in batch.
- Here: `just check` green; lint clean; no `dl-umbriel` symbols left
  (`rg dl-umbriel` finds only history: CHANGELOG, closed records).
- Live: after a daemon restart, `C-c u` and meow `u` open `*umbriel*`, and
  the faces keep their saved look.

## Non-Goals

- Rewriting umbriel in another language.
- Merging the client into the compositor's repo (rejected 2026-11-11).

## Summary

Move the umbriel IPC client (5 modules, 5 suites) into its own Elisp package
repo with the `umbriel-*` namespace, wired here like SATAN (checkout on
`dl-dirs-checkouts` plus `use-package`). The config keeps the keymap and
face shading and consumes only the package's public surface.

## Follow-Ups

- Fix the open umbriel issues in their new home.
