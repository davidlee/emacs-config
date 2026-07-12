# denote scans the whole denote-directory tree uncached per id-resolution; exclude bulk non-note dirs

denote (4.2.3) resolves a `denote:` id → path via `denote-get-path-by-id` →
`denote-directory-files` → `denote--directory-all-files-recursively`, which runs
`directory-files-recursively` over the **entire `denote-directory` tree, uncached,
with `:follow-symlinks`, on every call**. There is no built-in scan cache
(`denote-directory-get-files-function` is obsolete; upstream suggests advising
`denote-directory-files`). Only dotfiles are auto-pruned;
`denote-excluded-directories-regexp` defaults to **nil**.

**Symptom:** following a single `denote:` link stalls seconds + spins fans when
`denote-directory` (`~/notes`) contains a large non-note subtree. Here
`~/notes/satan/` holds ~10k model-facing files (prompts/hippocampus/motives — never
denote notes) → every link-follow stats all 10k. Latent until SL-013 revived
retrieval (before that, links were essentially never clicked).

**Fix:** set `denote-excluded-directories-regexp` to prune bulk non-note dirs as a
**path segment**, not a bare substring (a note named `…-satan.org` must survive):

```elisp
(denote-excluded-directories-regexp (rx (or bos "/") "satan" (or eos "/")))
```

The regexp is matched against each entry's path relative to `denote-directory`
during traversal, so matching dirs are never descended (real perf win, not a
post-filter). Add more alternatives for other large non-note dirs.

Lives in `org/dl-denote.el` `:custom`. Config-only — `eval-buffer` / restart, no
`home-manager switch`. See [[mem.signpost.satan.orientation]] (satan content lives
in `~/notes/satan/`).
