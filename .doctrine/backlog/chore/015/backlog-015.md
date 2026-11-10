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
