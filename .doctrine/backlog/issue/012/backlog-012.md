# ISS-012: umbriel stream stores non-alist data entries unvalidated

<!-- Backlog item body — context, detail, links. The structured, queried fields
     live in the sister `backlog-NNN.toml`; this prose is free-form and is never
     structurally parsed (the storage rule). -->

Found by the SL-016 PHASE-03 pi review (findings 4, 5), VERIFIED by probe.

`dl-umbriel--stream-line` (apps/dl-umbriel.el, PHASE-02) stores a family's
`data` as parsed, without checking it is a list of alists. A wire payload such
as `{"event":"workspaces","data":[null]}` or `"data":"x"` would reach
`dl-umbriel-model-group`:

- a nil workspace entry yields a second `(nil . WINDOWS)` group, sorted first,
  which a renderer reading nil car as "Unassigned" would show twice;
- a non-list entry (string) signals `wrong-type-argument listp`.

Fix at the parse boundary, not the model: treat a `data` that is not a list of
alists as malformed (counted and skipped, per design § Stream lines). Not
observed from the live compositor; upstream always sends objects.
