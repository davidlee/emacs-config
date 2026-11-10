# CHR-014: Tidy repo root and docs: retired dirs, tools/bin split, stale links

<!-- Backlog item body — context, detail, links. The structured, queried fields
     live in the sister `backlog-NNN.toml`; this prose is free-form and is never
     structurally parsed (the storage rule). -->

## Why

The repo root and `docs/` still hold leftovers from retired work and from the
SATAN extraction (SL-012). They make the layout harder to read and give agents
dead links to follow.

## Items

| item | action |
|---|---|
| `.spec-driver/` (171 files) | delete; `bin/elisp-lint:14` already calls it an "archived spike". Also drop its exclusion there and the two `.pi/extensions/spec-driver-*.ts` files if unused |
| `compost/denote-roam.el` | delete; "retired code, not loaded" (`bin/elisp-lint:14`) |
| `agents/general.md`, `agents/lean.md` | confirm they are unused, then delete |
| `tools/elisp-locate-paren-error.el` + `bin/elisp-locate-paren-error` | one tool split across two directories; put the `.el` beside its wrapper or under `dev/` |
| `AGENTS.md` → `docs/satan/INDEX.md`, `docs/satan/refactor/extraction-policy.md` | both dead since SL-012; point at POL-001 or the satan repo. Absorbs CHR-005 |
| `docs/` | 8 upper-case files at the top, 6 under `docs/emacs/`; pick one layout. `REVIEW.md` is historical (cites `lisp/` paths): archive or delete |
| `Justfile` `supabase` recipes | `supabase/` was deleted; remove the recipes if they are now dead |

Keep: `emacs.nix` is a symlink to `~/flakes/emacs/emacs.nix`, not a copy.

## Done when

`just check` green; `rg` finds no reference to a removed path.

Raised in a file-structure review (2026-11-10). Sequence: after CHR-010.

## Resolution (2026-11-11)

Done from this card, no slice. User confirmed: delete `agents/`; move
`docs/memory.brief.md` to the satan repo (`docs/memory/brief.md`, left
uncommitted there); docs layout below.

- Deleted `.spec-driver/`, `compost/`, `agents/`, `.pi/extensions/spec-driver-*.ts`,
  `docs/REVIEW.md`; dropped their lint exclusions and `.gitignore` lines.
- `tools/elisp-locate-paren-error.el` → `bin/` beside its wrapper.
- `docs/emacs/` is the one home for tracked config docs (kept because closed
  slices SL-015..017 cite it); top-level docs moved in with lower-case names.
- `AGENTS.md` dead links → POL-001 and the satan repo (CHR-005).
- `Justfile` supabase recipes were already gone.

Gate: lint clean; tests 591/594, one failure tolerated by the user:
`dl-gptel-mcp/org-tools-reach-gptel-and-writes-confirm` (see new issue).
