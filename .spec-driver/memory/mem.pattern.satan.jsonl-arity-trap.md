---
id: mem.pattern.satan.jsonl-arity-trap
name: SATAN jsonl-read-file byte-compiled arity trap
kind: memory
status: active
memory_type: pattern
created: '2026-05-31'
updated: '2026-05-31'
verified: '2026-05-31'
confidence: medium
tags:
- satan
- jsonl
- gotcha
summary: defun with &key produces byte-compiled arity (3 . 3); use lenient reader
  or pass 3 args
---

# SATAN jsonl-read-file byte-compiled arity trap

## Summary

defun with &key produces byte-compiled arity (3 . 3); use lenient reader or pass 3 args

## Context

`dl-satan-jsonl-read-file` is defined as `(defun dl-satan-jsonl-read-file (path &key null-object) ...)`.
In Emacs Lisp, regular `defun` does not support `&key` — it's treated as a positional parameter name.
When byte-compiled by the Nix-wrapped `emacs-unstable-pgtk-30.2`, the resulting function has arity `(3 . 3)`,
requiring all three arguments (`path`, `&key`, `null-object`). Calling with just `(path)` errors.

Workaround: use `dl-satan-tools-content--read-jsonl-lenient` or always pass 3 args.
The existing `dl-satan-tools-activity` has the same latent bug (its tests also fail in batch mode).
