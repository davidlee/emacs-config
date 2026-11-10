# ISS-019: Lint gate depends on dl-path's load-time side effects

<!-- Backlog item body — context, detail, links. The structured, queried fields
     live in the sister `backlog-NNN.toml`; this prose is free-form and is never
     structurally parsed (the storage rule). -->

## Observed (2026-11-11, during CHR-010)

`dev/dl-lint.el` requires `dl-path` only for `dl-path-config-load-path`. When
CHR-010 moved that function to the side-effect-free `core/dl-dirs.el` and
dropped the `dl-path` require, `just lint` reported six findings it does not
report with `dl-path` loaded:

```
early-init.el:19: warning: assignment to free variable 'use-package-verbose'
early-init.el:20: warning: assignment to free variable 'use-package-compute-statistics'
org/dl-org.el:72: warning: reference to free variable 'org-bullets-mode'
org/dl-org.el:114: error: Invalid face: org-heading
test/dl-faces-test.el:7: error: Invalid face: org-heading
test/dl-org-test.el:6: error: Invalid face: org-heading
```

Restoring `(require 'dl-path)` clears them; it is kept, with a comment.

## Inference (not verified)

`dl-path` at load time requires `use-package-ensure-system-package` (pulls in
`use-package`), runs `envrc-global-mode`, and rewrites `PATH`/`exec-path`.
One of these hides the findings. Flymake's live child does not load
`dl-lint`, so the gate may not match Flymake as `dev/dl-lint.el` claims.

## To do

Find which side effect matters; either load just that in the lint child
(and in `bin/elisp-compile-child` if Flymake needs it too) or fix the six
findings. Then drop the `dl-path` require from `dev/dl-lint.el`.
