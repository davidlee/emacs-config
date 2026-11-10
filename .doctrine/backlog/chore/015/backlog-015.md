# CHR-015: Split apps/ and core/ into domain directories

<!-- Backlog item body — context, detail, links. The structured, queried fields
     live in the sister `backlog-NNN.toml`; this prose is free-form and is never
     structurally parsed (the storage rule). -->

## Why

After CHR-010, `apps/` (42 files) becomes the catch-all, and `core/` (20) mixes
three concerns: startup plumbing, appearance, and keys. Directories exist only
to help people read the code: the load path is flat and `require` uses feature
names, so moving files changes nothing at runtime.

## Proposed split

```
apps/ (42)  →  ai/       gptel*, minuet, claude, eca, agent-shell, agent-review,
                         satan, llm-gateway, bough, sediment
               desktop/  umbriel*, emskin, eaf, foxmacs, sleipnir-doctor
               term/     term, ghostel, zmx*
               comms/    gnus, erc, elfeed, elpher, nostr
               apps/     dired, dirvish, magit, ediff, blog, diagram, excali, smudge
core/ (20)  →  core/     path, compile, core, guix, backup, policy-lint, help, dwim,
                         notes-paths, secret, buffer-management, window
               ui/       theme, faces, modeline, popups, interface, prose
               keys/     keymap, keybind, keymap-shadow, meow, meow-map,
                         meow-cheatsheet
```

Borderline files (for example `dl-diagram`, `dl-dwim`, `dl-prose`) are settled
when the work starts. Aim: directories line up with the sections of `init.el`.

## Depends on

CHR-010 and its single source of truth for the directory list (`my/lisp-dirs`
in `core/dl-path.el`). With that in place, each move is `git mv` plus one list
edit. Without it, every move edits about five hand-written copies of the list.

## Done when

`just check` green; `init.el` sections match the directories; `just clean-eln`
after `home-switch`.

Raised in a file-structure review (2026-11-10).

## Done (2026-11-11)

Moves as proposed, with these settlements:

- `core/` keeps `dl-dirs`, `dl-path`, `dl-package`: `early-init.el`,
  `bin/elisp-compile-child` and `dl-dirs-root` find them by path.
- Borderline: `dl-dwim`, `dl-prose`, `dl-diagram` → `editing/` (init.el
  already loaded them as editing). Siblings follow their parent:
  `gptel-*` → `ai/`, `umbriel-*` → `desktop/`, `zmx-*` → `term/`.
- `dl-dirs-config`: core ui keys desktop editing completion org dev lang
  term ai comms apps.
- `init.el`: one section per directory. Order kept where it matters:
  ui before keys (`dl-meow` requires `dl-modeline`; no ui file names a
  `my-*-map`), `dl-keybind` still last so its chords win.
  `dl-persist`/`dl-session` moved from the old CORE block to editing/
  (they live there); `dl-secret`, `dl-buffer-management`, `dl-window`
  now load in core/. No collisions between `dl-keybind`'s keys and the
  files that now load before it.
- `dl-policy-lint` R3 exemption and its tests name `keys/dl-keymap.el`.
- Stale `.elc` of moved files deleted: `apps/` and `core/` stay on the
  load path, so an old `apps/dl-gnus.elc` would shadow `comms/dl-gnus.el`.
- `test/dl-umbriel-model-test.el` hard-coded `../apps`; it now finds the
  model with `locate-library`.
- Path mentions updated in comments, `AGENTS.md`, `docs/emacs/`.
- Gate: lint clean; 591/594 pass, 2 skipped, 1 failure:
  `dl-gptel-mcp/org-tools-…` (ISS-022, pre-existing).
- Batch init load found ISS-023 (pre-existing, from CHR-014).
- Outside this repo, stale paths remain: `~/flakes` comments
  (`emacs/emacs.nix`, `features/agents.nix`, `SATAN.md`), satan
  `docs/governance.md` (`~/.emacs.d/core/dl-path.el`, already stale).
- Still to do: restart the daemon (its `load-path` predates the new
  directories); `just clean-eln` after the next `home-switch`.
