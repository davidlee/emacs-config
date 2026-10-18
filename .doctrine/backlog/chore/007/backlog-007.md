# CHR-007: flakes: remove unjailed eca from features/agents.nix and its dl-eca-toggle-jail comment

<!-- Backlog item body — context, detail, links. The structured, queried fields
     live in the sister `backlog-NNN.toml`; this prose is free-form and is never
     structurally parsed (the storage rule). -->

Work lives in ~/flakes, not this repo; tracked here until raised there.
SL-015 PHASE-03 (fc56d8f) removed unjailed eca from this config, including
`dl-eca-toggle-jail`. `~/flakes/features/agents.nix:38` still installs unjailed
`eca` and its comment names the removed toggle. Belongs with SL-015 design
sec-11's flakes-side follow-ups; raise it in ~/flakes and close this as promoted.
