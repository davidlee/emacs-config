# ISS-023: gptel-agent points at the deleted agents/ directory

<!-- Backlog item body — context, detail, links. The structured, queried fields
     live in the sister `backlog-NNN.toml`; this prose is free-form and is never
     structurally parsed (the storage rule). -->

## Symptom

Loading init in batch logs:

```
Error (use-package): gptel-agent/:config: Opening directory: No such file
or directory, ~/.config/emacs/agents
```

`ai/dl-gptel.el` (the `gptel-agent` stanza) prepends `agents/` under
`user-emacs-directory` to `gptel-agent-dirs`, then calls
`gptel-agent-update`. CHR-014 deleted `agents/` as unused, so the update
signals, and use-package aborts the rest of `:config`: the
`dl-gptel-emcp` tool registration that follows never runs.

## Fixed (2026-11-11)

- Drop the `agents/` entry (the definitions were judged unused).
- Or restore a directory of agent definitions, if gptel-agent should
  have local ones.

Found while verifying CHR-015 (2026-11-11).

Dropped the `agents/` entry from `gptel-agent-dirs`. Batch init now loads
without the error and `dl-gptel-emcp` is loaded.
