# IMP-019: Policy lint: warn on global C-c bindings in major-mode keyspace

## Problem

Emacs key conventions (elisp manual, "Key Binding Conventions") split `C-c`:

```
C-c <letter>              users          ← our my-*-map families live here
C-c <punct> / C-c C-<key> major modes    ← modes shadow anything global here
C-c <digit>, { } < > : ;  minor modes
```

`core/dl-policy-lint.el` checks only single-letter `C-c` bindings. Globals
bound in the major-mode range pass silently. They work in some buffers and
are shadowed in others, so the shadowing goes unnoticed.

This matters more once Meow `o` acts as `C-c` and looks the next keys up
in every active keymap (fix in flight, 2026-10-08). Today `o` binds the
global `mode-specific-map` object, so mode-local `C-c` keys (`o @`, `o '`)
are unreachable. After the fix, `o X` ≡ `C-c X`, so every global binding
in the major-mode range turns mode-dependent.

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
   binding whose first key after `C-c` is punctuation or a control
   character, i.e. the major-mode range. Same report surface as the
   letter rule: `*Policy Lint*` buffer and a silent startup scan that logs
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
