# IMP-019: Policy lint: warn on global C-c bindings in major-mode keyspace

## Problem

Emacs key conventions (elisp manual, "Key Binding Conventions") split `C-c`:

```
C-c <letter>                       users        ← our my-*-map families live here
C-c C-<key>, <digit>, { } < > : ;  major modes
C-c <other punctuation>            minor modes  ← e.g. outline's C-c @
```

(Corrected 2026-10-08 against the Emacs 31 manual; the first draft had
the major/minor rows swapped.) Org ignores the split: its `C-c '`,
`C-c .`, `C-c /`, `C-c ?`, `C-c [`, `C-c ]` all sit in the minor-mode
range. So in practice every non-letter `C-c` key is mode-owned.

`core/dl-policy-lint.el` checks only single-letter `C-c` bindings. Globals
bound in the mode-owned (non-letter) ranges pass silently. They work in
some buffers and are shadowed in others, so the shadowing goes unnoticed.

This matters more now that Meow `o` acts as `C-c` (landed 2026-10-08).

## Findings: Meow `o` / `@` (2026-10-08)

- **Root cause.** `o` was bound to the `mode-specific-map` object. A
  keymap bound as a key's value is consulted alone: lookups after `o` saw
  only global `C-c` keys. Mode-local `C-c` maps live in each mode's own
  keymap, so `o @` (outline) and `o '` (org `org-edit-special`) were dead.
- **Fix.** `o` runs `my/meow-ctrl-c`, which pushes `C-c` onto
  `unread-command-events` (`my/meow--replay`). The command loop then reads
  `C-c` plus the following keys through the normal lookup: every active
  map, which-key included. Same in motion state.
- **`@`.** Normal-state `@` now replays `C-c @` (`my/meow-outline-prefix`),
  the `outline-minor-mode` prefix. `C-c @` sits in the minor-mode range
  of the convention table above.
- **Consequence for this item.** `o X` ≡ `C-c X` in every buffer, so each
  global binding in the mode-owned ranges is now mode-dependent under `o`
  as well as `C-c` (the table below). `SPC X` is unaffected: the leader
  map is global.
- **Pattern.** Bind a prefix key to a replay command, not to a keymap
  object, whenever mode-local bindings under it must stay reachable. A
  future static lint rule could flag keymap-object values whose prefix
  modes also bind (e.g. `C-c`, `C-x`).

## Evidence (live scan, 2026-10-08)

The scan compared every global `C-c` sequence with `key-binding` in each
open buffer's mode, plus fresh org and markdown buffers:

| Key | Global | Shadowed in | By |
|---|---|---|---|
| `C-c '` | `claude-code-ide-menu` | org, markdown | `org-edit-special`, `markdown-edit-code-block` |
| `C-c .` | smudge map | org | `org-timestamp` |
| `C-c /` | `meow-keypad-describe-key` | org | `org-sparse-tree` |
| `C-c ?` | Gallium cheatsheet | org | `org-table-field-info` |
| `C-c [` / `]` | prev/next user buffer | org | `org-agenda-file-to-front` / `org-remove-file` |
| `C-c C-d` | `helpful-at-point` | org, markdown, ghostel | `org-deadline`, `markdown-do`, `ghostel-send-C-d` |
| `C-c t r` | `read-only-mode` | ghostel | `ghostel-readonly-enter` (a mode breaking the user range) |

Modes not covered: magit, dired, language modes.
`eros` remaps `eval-last-sexp` / `eval-defun`; that is a remap, not a
collision. The lint must ignore it.

## Proposed scope

1. **Static rule (cheap, deterministic):** report every global `C-c`
   binding whose first key after `C-c` is not a letter: the major- and
   minor-mode ranges together (see the corrected table). Same report
   surface as the letter rule: `*Policy Lint*` buffer and a silent startup scan that logs
   to *Messages*. Allow-list deliberate keepers, like the reserved
   singletons.
2. **Optional live probe (M-x only, never on startup):** for each live
   buffer's major mode, walk every global `C-c` sequence and report where
   `key-binding` differs. Catches modes that break the user range too
   (ghostel `C-c t`). Normalise `my/bind`'s `(LABEL . CMD)` entries and
   skip command remaps.

Decide per offender afterwards: move it to a letter family, or keep it via
the allow-list (most already have `SPC` twins: `SPC [`, `SPC ]`, `SPC ?`,
`SPC /`).

## Links

- `core/dl-policy-lint.el`: the current letter-only lint.
- `docs/KEYS.md` § Policy.
- `core/dl-keymap.el`: `meow-setup`, the `o` binding.
