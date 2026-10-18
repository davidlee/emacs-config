# CHR-008: Wire doctrine check gate to just check (no gate recipe)

<!-- Backlog item body — context, detail, links. The structured, queried fields
     live in the sister `backlog-NNN.toml`; this prose is free-form and is never
     structurally parsed (the storage rule). -->

`doctrine check gate` runs `just gate`, which this justfile does not define; the commit gate is `just check` (AGENTS.md). Either add a `gate` recipe aliasing `check`, or point doctrine's gate config at `just check`. Found in RV-017 F-7 (SL-015 audit).
