# DEC-013: umbriel model: raw parsed alists, defaulting accessors, join on workspace id

<!-- Knowledge record body — context, detail, links. The structured, queried
     fields live in the sister `record-NNN.toml`; this prose is free-form and is
     never structurally parsed (the storage rule). -->


## Amendment (SL-016 reconcile, RV-020 F-2, 2026-11-04)

The workspace label's count is the number of windows the join placed under the
workspace, not the wire's `window_count`, which is never read
(`dl-umbriel-model-workspace-label WORKSPACE &optional COUNT`). This was decided
in SL-016's design (§ Display strings) and plan PHASE-03 EX-3, so the label
always agrees with the rows beneath it. The choice text above predates it.
