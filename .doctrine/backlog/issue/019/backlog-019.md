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

## Resolution (2026-11-11)

**Bisect** (lint child without `dl-path`, adding one side effect at a
time). Only the two `early-init.el` warnings reproduced. Loading
`use-package` alone (`(require 'use-package)`) hides both. envrc and the
PATH/exec-path rewrite play no part.

**The org findings no longer reproduce.** That covers `dl-org.el:72` and
the three `Invalid face: org-heading` errors: none appeared in five runs
without `dl-path`. They were probably transient while CHR-010 was moving
directories. `org-bullets` is installed, so its variable is defined at
compile time. Line 72 does hold a real bug that lint can't see, filed as
ISS-024.

**Flymake did differ.** The Flymake child is `bin/elisp-compile-child`
running the same helper on the same load path, with no `dl-path`. The
bisect's baseline run used exactly that setup and reported the two
warnings. So live Flymake on `early-init.el` showed them and the gate hid
them. This was established by construction, not by opening the file in
the daemon.

**Fix.**
- `early-init.el`: the `use-package-verbose` and
  `use-package-compute-statistics` setqs move below
  `(require 'use-package)`. `debug-on-error` still comes first.
- `dev/dl-lint.el`: the `dl-path` require is gone. `elisp-compile-child`
  needed no change.
- `test/dl-lint-test.el`: `dl-lint/gate-sees-what-flymake-sees` runs
  `bin/elisp-lint` on a fixture that sets `use-package-verbose` and
  expects the free-variable warning. It fails with the `dl-path` require
  back in place and passes without it.

`just check`: green, 593/595 (2 skipped), zero lint findings.
