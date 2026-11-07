# umbriel buffer scratchpad sections and pad toggle

## Context

Umbriel reports a `scratchpad` name on every window, but the Emacs client never
reads it. A hidden pad window arrives with `workspace: ""`, so
`dl-umbriel-model-group` files it under `Unassigned` with no pad name (DEC-013
chose this).

## Scope & Objectives

- One section per scratchpad holding windows, after the workspaces, headed with
  the pad's name and window count.
- A window's `scratchpad` wins over its `workspace`, so a pad window stays in its
  pad section whether shown or hidden.
- `Unassigned` keeps only windows in no pad and no known workspace.
- A buffer key toggles the pad at point, from a pad heading or a pad window row,
  through umbriel's `scratchpad-toggle` with the `scratchpad` field. Any other row
  is refused.
- Every other row action refuses a pad heading (DEC-030). Window rows in a pad keep
  their existing behaviour, except that `s` asks for a workspace (DEC-032).

Affected surface: `apps/dl-umbriel-model.el`, `apps/dl-umbriel-buffer.el`, their
tests, `docs/emacs/umbriel.md`, `CHANGELOG.md`.

## Non-Goals

- Send to a pad and remove from a pad: the follow-up below.
- Empty pads. The buffer builds sections from the window list, so a pad with no
  windows does not appear.
- `scratchpad-focus-next` and the one-at-a-time show actions.

## Summary

Risks and assumptions:

- Observed live: a pad window reports `workspace: ""` whether shown or hidden.
  Grouping on `scratchpad` first is correct either way.
- DEC-013 fixes the group shape and the trailing group, so this slice amends it.
- `(WORKSPACE . WINDOWS)` is read by the grid and the heading code, so a pad group
  must not reach workspace-only paths such as `dl-umbriel-buffer--group-cells`.
- A row action on a hidden pad window (focus, for one) is existing behaviour and
  stays unchanged here.

Verification: model and buffer ert tests, `just check`, then a live check by the
user: pads appear hidden and shown, and the key toggles them.

## Follow-Ups

- Send a window to a chosen pad, and remove it from its pad.
