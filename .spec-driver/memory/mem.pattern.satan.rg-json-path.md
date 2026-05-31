---
id: mem.pattern.satan.rg-json-path
name: rg --json path field is nested object
kind: memory
status: active
memory_type: pattern
created: '2026-05-31'
updated: '2026-05-31'
verified: '2026-05-31'
confidence: medium
tags:
- satan
- rg
- gotcha
summary: rg --json wraps path in {:text "..."}; extract with (plist-get (plist-get
  data :path) :text)
---

# rg --json path field is nested object

## Summary

rg --json wraps path in {:text "..."}; extract with (plist-get (plist-get data :path) :text)

## Context

ripgrep's `--json` output wraps the `path` field as an object: `{"path":{"text":"b2/file.md"}}`.
When parsed with `json-parse-string :object-type 'plist`, this becomes `(:path (:text "b2/file.md"))`.
Using `(plist-get data :path)` returns the plist `(:text "...")`, NOT the string path.
Must use `(plist-get (plist-get data :path) :text)` to get the actual file path string.

Discovered during DE-005 P01 search scope implementation when rg output appeared to find no matches.
