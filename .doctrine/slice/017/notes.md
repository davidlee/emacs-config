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
