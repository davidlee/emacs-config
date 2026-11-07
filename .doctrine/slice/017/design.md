<!-- doctrine:section sec-1 -->
## Approach

Scratchpads become a third kind of group in the existing tree, not a parallel view (DEC-028). The toggle is one more row in the existing action table (DEC-029), on key `v` (DEC-031).

```
windows ──> dl-umbriel-model-group ──> workspace groups   heading + rows
              pad > workspace > nil    pad groups         same heading path
                                       nil group          "Unassigned"
```
<!-- doctrine:section sec-2 -->
## Model (`apps/dl-umbriel-model.el`)

- `dl-umbriel-model-window-scratchpad WINDOW`: the pad name when `scratchpad` is a non-empty string, else nil.
- `dl-umbriel-model-group`: the owner of a window is its pad entry `((scratchpad . NAME))`, else its workspace, else nil. Pad entries are built once per name and sorted by name, so `dl-umbriel-model--windows-of` keeps comparing owners with `eq`. Groups come out as workspaces, pads, then the nil group. Every window still appears exactly once.
- `dl-umbriel-model-group-cells OWNER COUNT`: heading cells for either owner. A pad gives `id` `scratchpad`, `name` NAME and the window count, with `layout` and `marks` empty. A workspace gives `dl-umbriel-model-workspace-cells`.
- `dl-umbriel-model-window-workspace` is unchanged. umbriel reports `workspace: ""` for a pad window, shown or hidden, so it joins nothing there.
<!-- doctrine:section sec-3 -->
## Buffer (`apps/dl-umbriel-buffer.el`)

- `dl-umbriel-buffer--group-cells` calls `dl-umbriel-model-group-cells`. The grid and `dl-umbriel-buffer--workspace-heading` then serve pads unchanged: an empty layout gives no pill, and a pad has no `active` shade.
- `dl-umbriel-buffer--insert-group` gains a pad branch: section `umbriel-scratchpad` with value NAME, the shared heading, then `dl-umbriel-buffer--insert-windows`. Folds and point follow the section type and value.
- `dl-umbriel-buffer--target` returns `(:scratchpad NAME)` for that section.
- `dl-umbriel-buffer-actions` gains `(my/umbriel-toggle-scratchpad "scratchpad-toggle" scratchpad)`.
- `dl-umbriel-buffer--plan`: `scratchpad` addressing sends the action with a `scratchpad` field, from the heading or the row window; with neither it refuses "Not in a scratchpad". Any other addressing on a `:scratchpad` target refuses (DEC-030).
- `dl-umbriel-buffer-mode-map` binds `v`.
- `s` carries a `pad-workspace` prompt: on a pad window that joins no workspace it asks for one and sends `workspace-switch` to it (DEC-032).
<!-- doctrine:section sec-4 -->
## Code impact

- `apps/dl-umbriel-model.el`
- `apps/dl-umbriel-buffer.el`
- `lisp/test/dl-umbriel-model-test.el`
- `lisp/test/dl-umbriel-buffer-test.el`
- `docs/emacs/umbriel.md`
- `CHANGELOG.md`

`dl-umbriel.el` needs no change: `dl-umbriel-action` already builds any action with fields.
<!-- doctrine:section sec-5 -->
## Verification

- Model tests: a hidden pad window, a shown one with a real workspace, an empty and a non-string `scratchpad`, group order, and every window appearing once. `dl-umbriel-model-group/keeps-every-window` changes to match DEC-028.
- Buffer tests: section order and heading text, the toggle plan from a heading and from a row, the refusal on a non-pad row, and refusal of other actions on a pad heading.
- `just check` is green.
- VH (checked by a human), by the user: pads list while hidden and shown, `v` toggles them, and a shown pad window stays in its pad section. This also confirms what `workspace` reports for a shown pad.
