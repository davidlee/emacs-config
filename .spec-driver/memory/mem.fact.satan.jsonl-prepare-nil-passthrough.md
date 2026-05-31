---
id: mem.fact.satan.jsonl-prepare-nil-passthrough
name: dl-satan-jsonl-prepare nil-passthrough vs legacy --prep-value
kind: memory
status: active
memory_type: fact
created: '2026-05-31'
updated: '2026-05-31'
verified: '2026-05-31'
confidence: medium
tags:
- satan
- jsonl
- dry
- sharp-edge
summary: dl-satan-jsonl-prepare passes nil through unchanged; old --prep-value clones
  converted nil to :null. json-serialize handles both correctly under defaults. This
  is a deliberate canonicalisation, not a bug.
---

# dl-satan-jsonl-prepare nil-passthrough vs legacy --prep-value

## Summary

`dl-satan-jsonl-prepare` passes nil through unchanged. The old private
`--prep-value` clones in memory-store, patch-store, and attribute converted
nil to `:null`. This is a deliberate canonicalisation — `json-serialize`
with default settings maps nil to JSON null, so the wire output is identical.

## What to do

- When updating old tests that expected `:null` from `--prep-value`, expect
  `nil` from `dl-satan-jsonl-prepare`.
- Do NOT add a nil→`:null` wrapper — the passthrough is correct.
- `:null`, `:false`, and `t` also pass through unchanged.

## Context

DE-003 unified all JSON serialisation through `dl-satan-jsonl-prepare`.
Test expectations updated in `dl-satan-patch-store-test.el` and
`dl-satan-attribute-test.el` (commit 46942d4).

## Related

- [[DE-003]]
- `satan/dl-satan-jsonl.el` — canonical implementation
