# IMP-017: Fill Meow normal-state gaps: redo, indent, expand selection, jump back

## Why

A gap review of `meow-setup` (`core/dl-keymap.el`) against a Helix/Vim
working set found four high-frequency operations with no normal-state key:
redo, indent/dedent, syntax-aware selection growth, and jump back/forward.
All four fit on free keys without displacing existing bindings.

## Bindings

| Key | Command | Rationale |
|---|---|---|
| `C-r` | `undo-redo` | User's choice. Built-in; pairs with `meow-undo`, which runs plain `undo`. `undo-fu-only-redo` was rejected: it is coupled to undo-fu's own undo chain. `U` (`meow-undo-in-selection`) unchanged. |
| `>` / `<` | `my/meow-indent-right` / `my/meow-indent-left` | Shift every line the selection touches (or the current line) by `standard-indent` × prefix. Selection stays active so presses repeat. A selection ending at a line start (linewise) excludes that line. |
| `x` / `X` | `expreg-expand` / `expreg-contract` | expreg was installed but only on `C-=`/`C--`. |
| `C-o` / `C-S-o` | `xref-go-back` / `xref-go-forward` | Helix `C-o`/`C-i`; `C-i` is TAB in Emacs, so forward uses `C-S-o`. |

## Known limitations

- ~~The xref jump list only records definition and reference jumps.~~
  Superseded by dogears; see the follow-up below.
- In normal state, `C-r` shadows `isearch-backward`. Insert state and the
  global map are unchanged.

## Follow-up: dogears jump list (2026-10-02)

`C-o` / `C-S-o` now run `dogears-back` / `dogears-forward`, replacing xref
(configured in `editing/dl-motion.el`).
- dogears records only where a jump lands (`dogears-functions` :after advice)
  and places idled on. A Helix-style jump list also needs the place jumped
  from, so `dl-motion--dogear-jump` wraps each command in
  `dl-motion-jump-commands` with :around advice that records both ends.
  It does nothing while `dogears-mode` is off.
- Advising `push-mark` was rejected: `meow--select` pushes mark on every
  new selection, which would flood the list.
- `C-c j l` runs `dogears-go` (pick a place by completion); `C-c j L` runs
  `dogears-sidebar`.
- Tests are in `lisp/test/dl-motion-test.el`: back after a wrapped jump
  returns to the origin; nothing is recorded while the mode is off.
- Not persisted across sessions, and the idle default (5s) is kept. Both can
  be revisited after daily use.

## Follow-up: remaining gaps (2026-10-07)

| Key | Command |
|---|---|
| `=` | `my/meow-reindent-lines` |
| `#` | `my/meow-comment-lines` |
| `~` / `` ` `` | `my/meow-upcase` / `my/meow-downcase` |
| `P` | `consult-yank-pop` |
| `T` | `meow-till-expand` |
| `^` / `$` | `back-to-indentation` / `move-end-of-line` |
| `m s` / `m d` / `m r` | `my/meow-surround`, `-delete`, `-replace` (`my-surround-map`) |

- `my/meow--line-range` and `my/meow--edit-lines` now back `>` `<` `=` `#`:
  they find the lines the selection touches (excluding the next line for a
  linewise selection) and keep the selection active afterwards.
  `meow-indent` and `meow-comment` were rejected. Without a selection,
  `meow-indent` reindents from point to a possibly stale mark.
  `meow-comment` runs `comment-dwim`, which adds an end-of-line comment
  instead of toggling the line.
- Surround needs no package. `m s` inserts the closer first, then the
  opener with `insert-before-markers`, so the selection stays on the
  content. `m r` swaps the delimiters in place (`subst-char-in-region`),
  so the selection's markers don't move. `m d` / `m r` refuse unless the
  characters on each side of the selection form a pair, so a `.` (bounds)
  selection fails loudly instead of deleting the wrong characters.
  puni's sexp-based commands were not used: the selection-first approach
  works for every delimiter meow can select inside.
- `m s` / `m r` also accept meow's thing letters (`r` round, `s` square,
  `c` curly, `g` string, `a` angle), read from `meow-char-thing-table`
  so they always match `,` / `.`. `my/meow-surround-things` maps each
  thing to its delimiters. `m d`'s flank check stays literal, so `r…r`
  is a symmetric pair, not `(…)`.
- `my/meow-command-label` in the cheatsheet no longer labels every prefix
  keymap "C-c". `my/meow-cheatsheet-keymap-labels` names each one.
- Case changes first used `upcase-dwim` / `downcase-dwim`. Mid-word with no
  selection, those change only the word's tail. They also dropped the
  selection. `my/meow--change-case` uses the whole word under point (point
  stays put) or the selection, and keeps the selection afterwards.

## Closing state

- ~~Repurpose `s`.~~ Unbound on 2026-10-07; nothing was lost (`d` cuts a
  selection, `D d` cuts to the line end). It's free for a future binding.
  A programmatic check found every stock qwerty `meow-setup` command bound
  except `meow-delete` (`d`'s no-selection fallback) and
  `meow-backward-delete` (dropped in IMP-016; Backspace covers it).
- ~~Scroll on `C-d` / `C-u`.~~ Won't do. The user keeps the global `C-v` /
  `M-v` (they work in every meow state). The remaining unbound keys are
  accepted.

Resolved 2026-10-07.

## Implementation notes (2026-10-02)

- Tests in `lisp/test/dl-meow-keymap-test.el`. They cover the bindings, redo
  after `meow-undo`, and linewise, partial and no-selection indent. The redo
  test passed while still red because `undo-redo` is built in; it guards the
  `meow-undo` pairing.
- The fixture sets `standard-indent` to 2 because `emacs -Q` defaults it to 4.
- The cheatsheet labels `x`/`X` and lists `> < C-r C-o` under Extras.
  `docs/KEYS.md` has a new section for these bindings.
- To try it live: `M-x eval-buffer` in `dl-keymap.el`, then `(meow-setup)`,
  or restart Emacs.
