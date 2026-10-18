# IMP-028: gptel gateway models: declare per-model :capabilities so images reach vision models

<!-- Backlog item body — context, detail, links. The structured, queried fields
     live in the sister `backlog-NNN.toml`; this prose is free-form and is never
     structurally parsed (the storage rule). -->

SL-015 PHASE-05 (a007f3c) dropped `gptel-openrouter`, which supplied per-model
capability metadata. The gateway backends in `apps/dl-gptel.el` now list models
as bare symbols, so gptel treats none as vision-capable and won't send images
to `@gem` / `@glm` (tools still work). Fix: give the openrouter (and fireworks)
model lists gptel's plist form with `:capabilities` (e.g. `media`) and
`:mime-types`, as the deepseek-flash entry already does. Priority unclear — capture only.
