`doctrine slice list` rollup and `doctrine slice phases <id>` treat every
`phase-NN-<suffix>.md` (e.g. `phase-04-review.md`, `phase-02-context.md`) in
`.doctrine/state/slice/NNN/phases/` as tracking for a phase that is not in the
plan: the rollup shows `?N` anomalous and `slice phases` reports `orphan …
(--prune to remove)`. `--prune` deletes them.

Keep review notes, fix specs and context packs outside `phases/` — e.g.
`.doctrine/state/slice/NNN/working/` (SL-016 moved five there at close; the
rollup went from `6/11 ?5` to `6/6`). A non-`phase-` name such as a `.diff`
is not counted.
