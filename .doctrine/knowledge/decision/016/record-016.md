# DEC-016: umbriel row actions: address by id/selector, focus first where the action only takes the focused window

<!-- Knowledge record body — context, detail, links. The structured, queried
     fields live in the sister `record-NNN.toml`; this prose is free-form and is
     never structurally parsed (the storage rule). -->


## Amendment (SL-016 reconcile, RV-020 F-1, 2026-11-04)

Besides DEC-025 (restore previous focus, silent move) and DEC-026 (no
layout-scroll row actions): the `active-workspace` plan (`L`,
workspace-set-layout) omits `workspace-switch` when the target is already the
held `focused` workspace. With umbriel's `back_and_forth`, a switch to the
active workspace returns to the previous one (`actions.cpp:1597`,
`workspace.cpp:3568`), so "switches to it first" sent the layout to the wrong
workspace. Agent-proposed fix (commit 23973e7) for a PHASE-05 VH-1 fault;
passed by the user in the VH-1 re-check. `workspace` (`s`) still always
switches, by user ruling.
