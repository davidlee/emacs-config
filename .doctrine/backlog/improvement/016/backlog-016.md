# IMP-016: Align Meow deletion keys with Helix selection workflow

## Why

The current normal-state map in `core/dl-keymap.el` binds `d` to
`meow-delete` (one character forward), `D` to `meow-backward-delete`, and
`s` to `meow-kill` (cut selection, or kill to end of line without one). This
breaks the user's well-established Helix `d` habit despite both editors using
a selection-first grammar. The user wants a better daily-driver mapping,
without requiring a global redesign first.

## Reference behavior

- `~/helix.md`: normal `d` deletes the selection; `x` selects the current
  line; backward/forward character deletion is on Backspace/Delete in insert
  mode, with no dedicated normal-mode backward-character-delete binding.
- `~/.config/helix/config.toml:85-124`: custom normal `D` runs
  `ensure_selections_forward` then `extend_to_line_end`. It selects through
  the end of the line for inspection; a subsequent `d` deletes it.
- Meow's installed `meow-selection-command-fallback` defaults a bare
  `meow-kill` to `meow-C-k` (kill to end of line). Changing that fallback
  globally would also change the existing `s` binding, so use a local
  wrapper for `d` unless `s` is deliberately redesigned.
- Confirmed via `C-h k` in the user's running Emacs: Backspace invokes
  `puni-backward-delete-char`; physical NAV Delete invokes
  `delete-forward-char`. The current `D` consumes left and NAV Delete
  consumes right. The user is comfortable dropping `D`, which was not a
  remembered habit; explicit paren deletion remains available.

## Working proposal

1. Bind normal `d` to a small wrapper: call `meow-kill` with an active
   selection, otherwise call `meow-delete`. The selected path saves text to
   the kill ring/clipboard; the one-character fallback does not. Keep the
   global `meow-kill` fallback unchanged so `s` retains its current behavior.
2. Bind normal `D` to extend the selection's right edge through the end of
   the logical line, leaving text intact. Then `D d` cuts it. A trial using
   `meow-end-of-thing ?l` exposed a direction issue: with a forward
   selection it discarded the already-selected text. The user chose to
   preserve and extend the full selection, matching the Helix binding.
   The implementation uses Meow's selection helpers so the selection stays
   in its history; this is a minor coupling to Meow internals.
3. Replace the current `D` binding. Leave Backspace and physical NAV Delete
   untouched; the user accepts losing the old `D` backward-delete alias.
4. Leave `s` as an alias for `meow-kill` initially; that avoids an unrelated
   redesign. Revisit it with the rest of the selection grammar later.
5. Update the Gallium cheatsheet and stale `docs/KEYS.md` normal-mode guidance
   to match the chosen bindings. In particular, the docs still claim `h` is
   the command gateway; the live map uses `o` and gives `h` backward word.

## Verification / workshop cases

- No selection: `d` deletes exactly one forward character; `D` selects to
  end of line without deleting, and `D d` cuts that text.
- Existing forward selection: `d` cuts precisely that selection; `D` extends
  to line end in a predictable way.
- Existing backward selection: `D` preserves it and extends its right edge
  to the logical line end, as the user chose after comparing both behaviors.
- A whole line is still selected with `l`, then cut with `d`; linewise kill
  includes the newline as Meow intends.
- Backspace still invokes `puni-backward-delete-char` in Elisp and physical
  NAV Delete still invokes `delete-forward-char` as confirmed with `C-h k`.
- Check `.el` parentheses with `bin/elisp-locate-paren-error` before running
  byte compilation and `just check`.

## Boundaries

This item covers deletion and the directly displaced command. It does not
remap every Helix key, add multi-selection support for Helix's `s`, or change
the durable `C-c` command families. Further keymap friction can be reviewed
after the core deletion pair has been tried in daily use.

## Implementation notes (2026-10-02)

- `core/dl-keymap.el` implements the `d` wrapper and `D` preserve-and-extend
  selection command. `s`, Backspace, and NAV Delete are unchanged.
- The initial `meow-end-of-thing ?l` trial discarded the earlier part of a
  forward selection. The final command computes the selection's left and
  right edges, extends the right edge to its logical line end, and uses
  Meow's selection helpers to keep selection history. Recheck this coupling
  if Meow's internal selection API changes.
- Batch checks confirmed `D d` cuts the same text with no prior selection,
  a forward selection, or a backward selection; bare `d` deletes one forward
  character. Both edited Elisp files passed `bin/elisp-locate-paren-error`.
  `just check` passed 75/75 tests outside the sandbox; the first sandbox run
  could not create a local server socket required by an unrelated test.
- The code has not been loaded into the running Emacs; use `M-x eval-buffer`
  for the edited Elisp buffers or restart Emacs to try the bindings.
