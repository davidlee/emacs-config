# Review RV-022 — reconciliation of SL-017

Adversarial-review ledger. Structured findings live in the sister
ledger toml; this prose companion carries the reviewer's framing.

## Brief

<!-- Pre-reading + lines of attack: what this review is probing, the invariants
     it must hold the subject to, and where the bodies are likely buried. Seeded
     at `review new`; the reviewer fills it before raising findings. -->

## Synthesis

SL-017 delivers what the user asked for. Pads have sections, `v` toggles them, and `s`
prompts on a pad window. `just check` passes 512 of 514 with 2 skipped, every VT mandate
passes, and all six source selectors are conformant. The user passed VH-1 live.

The one real miss was a premise: the design assumed a shown pad window reports a
workspace, and it does not. Grouping on `scratchpad` first made the code correct anyway;
only `s` and `L` were affected. `s` is fixed by DEC-032. `L` still refuses and is in
IMP-031. A pad window's hidden or shown state is visible only through the row flag.

Standing risk: `dl-umbriel-buffer-mode-map` is a `defvar-keymap`, so reloading a file
does not pick up a new key; a restart does.

## Reconciliation Brief

### Per-slice (direct edit)

- design.md Model (F-1): replace the last bullet. umbriel reports `workspace: ""` for a
  pad window, shown or hidden, so `dl-umbriel-model-window-workspace` joins nothing there.
- design.md Buffer (F-2): add the `pad-workspace` prompt on `s` (DEC-032).

### Governance/spec (REV)

None. DEC-032 already records the correction to DEC-028's context.

## Reconciliation Outcome

### Direct edits applied

- design.md Model: pad windows report no workspace (F-1).
- design.md Buffer: the `pad-workspace` prompt on `s` (F-2).

### REVs completed

None needed.

### Follow-up / tolerated

- F-3: IMP-031. F-6: CHR-008. F-5: tolerated, rationale on the finding.
- F-4 was fixed during audit.
