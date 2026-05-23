# 03-SIZE.md — Size/shape census

## Files > 400 LOC

| LOC | File | Notes |
|---|---|---|
| 859 | `dl-satan-observer.el` | Largest file; 33 defuns; perceptual-layer Phase 5 |
| 797 | `dl-satan-broker.el` | 35 defuns; orchestration hub |
| 626 | `dl-satan-motive.el` | 22 defuns; motive file reader/renderer |
| 570 | `dl-satan-memory-canon.el` | 14 defuns; canonicalizer + rules |
| 560 | `dl-satan-memory-evidence.el` | 25 defuns; evidence-window assembly |
| 554 | `dl-satan-tank.el` | 28 defuns; observation tank |
| 526 | `dl-satan-context.el` | 25 defuns; bundle assembly |
| 496 | `dl-satan-memory-migrate.el` | 22 defuns; migration runner |

**8 files** above the 400-LOC threshold. 2 files (`observer.el`, `broker.el`) exceed 700 LOC.

## Functions > 50 LOC

| LOC | File:line | Function |
|---|---|---|
| 296 | `dl-satan-memory-canon.el:190` | `dl-satan-memory-canon-normalize-hints` |
| 238 | `dl-satan-patch-store.el:157` | `dl-satan-patch-store--parse-row` |
| 175 | `dl-satan-memory-store.el:196` | `dl-satan-memory-store--build-mark-payload` |
| 158 | `dl-satan-broker.el:638` | `dl-satan-broker--spawn` |
| 91 | `dl-satan-mode.el:57` | `dl-satan-mode-names` |
| 90 | `dl-satan-sensor-alerts.el:307` | `dl-satan-sensor-alerts--entry` |
| 83 | `dl-satan-tools-patch.el:243` | `dl-satan-patch-prepare` |
| 82 | `dl-satan-patch-adapter-pi.el:231` | `dl-satan-patch-adapter-pi--resolved-env` |
| 72 | `dl-satan-memory-evidence.el:487` | `dl-satan-memory-evidence-assemble-with-bounds` |
| 70 | `dl-satan-patch-worktree.el:81` | `dl-satan-patch-worktree-create` |
| 70 | `dl-satan-observer.el:721` | `dl-satan-observer-process` |
| 68 | `dl-satan-patch-inbox.el:12` | `dl-satan-patch-inbox--render-body` |
| 67 | `dl-satan-tools-atsatan.el:324` | `dl-satan-tool/notes-at-satan-done` |
| 66 | `dl-satan-tools-patch.el:87` | `dl-satan-tool/patch-job-create` |
| 66 | `dl-satan-motive.el:522` | `dl-satan-motive--rewrite-section-footer` |
| 66 | `dl-satan-motive.el:344` | `dl-satan-motive-render-block` |
| 63 | `dl-satan-patch-adapter-pi.el:168` | `dl-satan-patch-adapter-pi--sentinel` |
| 62 | `dl-satan-tools-org.el:101` | `dl-satan-tool/proposal-stage` |
| 62 | `dl-satan-tools-hippocampus.el:34` | `dl-satan-tools-hippocampus--cross-ref` |
| 62 | `dl-satan-motive.el:174` | `dl-satan-motive--parse-motive` |
| 59 | `dl-satan-patch-runner.el:178` | `dl-satan-patch-runner--finish-success-path` |
| 58 | `dl-satan-tools-memory.el:252` | `dl-satan-tool/memory-show-trace` |
| 58 | `dl-satan-sensor-alerts.el:78` | `dl-satan-sensor-render-block` |
| 57 | `dl-satan-tools-activity.el:90` | `dl-satan-tool/activity-read` |
| 55 | `dl-satan-memory-store.el:117` | `dl-satan-memory-store--format-pg-array` |
| 54 | `dl-satan-tank.el:237` | `dl-satan-tank--render-last-run` |
| 54 | `dl-satan-patch-prompt.el:88` | `dl-satan-patch-prompt-build-directive` |
| 54 | `dl-satan-memory-evidence.el:409` | `dl-satan-memory-evidence--truncate` |
| 53 | `dl-satan-tools-memory.el:135` | `dl-satan-tools-memory--mark-impl` |
| 53 | `dl-satan-tank.el:402` | `dl-satan-tank--last-run-state` |
| 52 | `dl-satan-observer.el:614` | `dl-satan-observer--persist-positive` |
| 52 | `dl-satan-context.el:406` | `dl-satan-context-tick` |
| 51 | `dl-satan-tools-docs.el:198` | `dl-satan-tool/docs-read` |
| 51 | `dl-satan-tools-atsatan.el:226` | `dl-satan-tools-atsatan--rewrite-line` |
| 51 | `dl-satan-observer.el:474` | `dl-satan-observer-classify` |

**36 functions** exceed 50 LOC. The largest is `normalize-hints` at 296 LOC.

## Functions > 6 args

**None found.** All function signatures stay within reasonable parameter counts.

## Nesting depth > 4

Not checked by automated scan (missing a reliable static-analysis tool for nesting depth in elisp in this environment). Recommend manual spot-check on the largest functions listed above, particularly:
- `dl-satan-memory-canon-normalize-hints` (296 LOC)
- `dl-satan-patch-store--parse-row` (238 LOC)
- `dl-satan-memory-store--build-mark-payload` (175 LOC)
- `dl-satan-broker--spawn` (158 LOC)

## Files with > 20 top-level definitions

| Count | File |
|---|---|
| 35 | `dl-satan-broker.el` |
| 33 | `dl-satan-observer.el` |
| 28 | `dl-satan-tank.el` |
| 25 | `dl-satan-memory-evidence.el` |
| 25 | `dl-satan-context.el` |
| 22 | `dl-satan-motive.el` |
| 22 | `dl-satan-memory-migrate.el` |
| 20 | `dl-satan-sensor-alerts.el` |

## Macros / metaprogramming hotspots

Not checked. Use `rg 'defmacro\|defsubst\|define-' satan/dl-satan*.el` to verify.
