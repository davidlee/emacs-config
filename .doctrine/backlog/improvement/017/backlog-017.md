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

## Deferred (from the same review)

Surround (`m` free), comment toggle (`meow-comment`), case change, `P` paste
history, `T` → `meow-till-expand`, first-non-blank, format (`=`),
and repurposing `s` (now mostly redundant with `d`).

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
