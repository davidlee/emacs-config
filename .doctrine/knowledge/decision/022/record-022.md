# DEC-022: umbriel buffer: magit-section tree, idle-coalesced repaint while displayed, magit's point restoration

<!-- Knowledge record body — context, detail, links. The structured, queried
     fields live in the sister `record-NNN.toml`; this prose is free-form and is
     never structurally parsed (the storage rule). -->


## Amendment (SL-016 reconcile, RV-020 F-6, 2026-11-04)

Qualification of the rationale: ids keep point on the same window while it
stays in its workspace. A window moved to another workspace gets a new section
ident (type and value along the parent chain), so point falls to a sibling via
`magit-section-goto-successor`. Accepted in SL-016's design § Repaint.
