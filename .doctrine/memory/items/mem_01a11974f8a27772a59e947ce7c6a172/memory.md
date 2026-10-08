Symptom: `doctrine slice phases <id>` prints "Phases up to date." but no
`phase-01.md` sheet exists under `.doctrine/state/slice/<id>/phases/`.

Cause (SL-014): the plan template comment `# One [[phase]] …` had the real
`[[phase]]` header folded into it (`# One [[phase]]`), so PHASE-01's
`id`/`name`/`objective`/criteria became top-level TOML keys and were ignored.
No validation error is raised.

Fix: make sure every phase starts with an uncommented `[[phase]]` line, then
re-run `doctrine slice phases <id>`. Check this first when a phase sheet is
missing.
