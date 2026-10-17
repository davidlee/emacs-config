# CHR-006: Drop the hi-lock require in dl-magit.el once magit loads hi-lock itself

<!-- Backlog item body — context, detail, links. The structured, queried fields
     live in the sister `backlog-NNN.toml`; this prose is free-form and is never
     structurally parsed (the storage rule). -->

magit 20261001's `magit-refresh-buffer` (`magit-mode.el:1127`) reads
`hi-lock-mode` without requiring hi-lock. `apps/dl-magit.el`'s `:config`
works around it (commit 33a83a7). On the next magit bump, check whether
`magit-mode.el` requires hi-lock or guards the read; if so, delete the
workaround and confirm `just check` (the dl-agent-review tests) stays green.
