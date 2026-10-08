# Hand-editing design.md during a managed design run locks the run out

`doctrine design start --from-design` adopts design.md and stores a
watermark (content hash) in `.doctrine/state/slice/NNN/design.toml`.

If design.md is then hand-edited:

- `design apply` refuses: "design.md has been edited outside this run".
- `adopt_authored` with the new fingerprint refuses when the file has no
  `<!-- doctrine:section sec-N -->` markers ("text before its first
  section marker"). An unmaterialised adoption leaves no markers.
- `design materialise` refuses for the same watermark reason.

Recovery (observed SL-014, 2026-10-08): the run state is gitignored
runtime state. `rm .doctrine/state/slice/NNN/design.toml`, then
`doctrine design start SL-NNN --from-design` re-adopts the current file.

Avoid it: finish prose edits before `design start`, or materialise first
so markers exist before any hand edit.

Other gates seen walking exploring → locked:
- `explore.research` needs `doctrine slice research NNN` (mints
  `research/` + baseline); put research evidence in `research/*.md`.
- `draft.selectors` needs `doctrine slice selector add NNN --intent
  design-target …`.
- Lock needs `section-reviewed` attestations: `declare` subjects
  `att-N` with `attests: sec-N`, `reviewer: human` (no `summary` key).
