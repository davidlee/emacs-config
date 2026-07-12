# ISS-008: dl-denote-journal/personal-daily-nav red: hardcoded ~/notes vs jail /workspace/notes

<!-- Backlog item body — context, detail, links. The structured, queried fields
     live in the sister `backlog-NNN.toml`; this prose is free-form and is never
     structurally parsed (the storage rule). -->

## What

`dl-denote-journal-test.el` test `dl-denote-journal/personal-daily-nav` fails
in the jail: it hardcodes `~/notes/` while the corpus is at `/workspace/notes`
(`dl-notes-root` resolves per-environment). Pure test-fixture path assumption,
not a product bug.

## Provenance

Surfaced during SL-013 PHASE-02 and confirmed still-red at the SL-013 audit
(RV-013). Pre-existing, unrelated to SL-013's changes — left untouched by that
slice deliberately. Related gate-blindness: [[ISS-007]] (the org suites are off
`dl-test-suite-dirs`, so this red never reaches `just check` anyway).

## Fix direction

Parameterise the test's expected path off `dl-notes-root` / a temp fixture
rather than a hardcoded `~/notes/`, matching the batch-runnable fixture-macro
convention the other journal tests use.
