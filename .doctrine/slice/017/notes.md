# Notes SL-017: umbriel buffer scratchpad sections and pad toggle

Durable per-slice scratchpad — tracked in git. The place to lift anything from a
disposable phase sheet (`.doctrine/state/.../phase-NN.md`) that must survive
`rm -rf` before the slice close-out audit harvests it.

## Harvest
<!-- single-copy: updated in place each harvest; ids only, never restated content -->
fresh-as-of: <yyyy-mm-dd> · <PHASE-NN | stage> · <head-commit>

### Produced

### Learned

### Open

## Design review pass (2026-11-07)

A further pass would probe whether pad entries reach workspace-only code in the
buffer. The user waived it: the change is two files on existing paths, and the
buffer tests and the live check cover that risk.

## Implementation (2026-11-07)

- PHASE-01 and the code of PHASE-02 are done; `just check` passes 509 of 511, 2 skipped.
- `doctrine check gate` fails: this Justfile has no `gate` recipe. `just check` is the
  project's commit gate, so that was used.
- Live probe, 16:16: a window in pad `main` reported `visible: true` with
  `workspace: ""`. So at least this shown pad reports no workspace, which differs from
  the scope's assumption and from design section Model's last bullet. Grouping is
  unaffected. Row keys that need a workspace (`s`, `L`) refuse such a row with "Window
  has no workspace". VH-1 should confirm this across a toggle.
- PHASE-02 stays in progress until VH-1, the user's live check.
