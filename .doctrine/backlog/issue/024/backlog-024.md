# ISS-024: org-bullets hook lambda reads org-bullets-mode instead of calling it

<!-- Backlog item body — context, detail, links. The structured, queried fields
     live in the sister `backlog-NNN.toml`; this prose is free-form and is never
     structurally parsed (the storage rule). -->

## Observed (2026-11-11, during ISS-019)

`org/dl-org.el:72`:

```elisp
(use-package org-bullets
  :hook (org-mode .(lambda  () org-bullets-mode 1))
```

The lambda evaluates the variable `org-bullets-mode` and the constant 1,
discarding both, so the hook never turns `org-bullets-mode` on. The
byte compiler does not flag it, because `org-bullets` is installed and
defines the variable.

## Decide

Either `:hook (org-mode . org-bullets-mode)`, which turns bullets on in
every org buffer (a visible change), or delete the stanza if bullets are
not wanted. Line 109 holds a commented-out hook for the same thing.
