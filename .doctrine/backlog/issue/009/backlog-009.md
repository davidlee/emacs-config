# ISS-009: embark never loads: circular :after with embark-consult, stray forms in :after

<!-- Backlog item body — context, detail, links. The structured, queried fields
     live in the sister `backlog-NNN.toml`; this prose is free-form and is never
     structurally parsed (the storage rule). -->

## What

`embark` never loads, so `embark-act` has no key anywhere (`C-,` is
unbound globally; in org buffers it falls through to
`org-cycle-agenda-files`). Confirmed live: `(featurep 'embark)` → nil.

Two faults in `completion/dl-embark.el`:

1. Circular deferral: `embark` is `:after (avy embark-consult)`, and
   `embark-consult` is `:after (embark consult)`. Neither can load first.
2. `(vertico-multiform-mode)` and the `add-to-list` form sit directly
   after `:after`, so use-package reads them as extra `:after` conditions
   instead of `:config` code.

`:bind` waits for the `:after` conditions, so the keys are never
installed either. The avy `.` → embark dispatch (set in `:init`) is
registered but calls an unloaded `embark-act` (autoload may save it).

## Fix direction

Drop `embark-consult` (and probably `avy`) from embark's `:after`; move
the two stray forms into `:config` (or into the vertico module, which
owns multiform). Add a test that `embark-act` is reachable after init.
Decide whether `C-,` should also win in org buffers (org binds it).
