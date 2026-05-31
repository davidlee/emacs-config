---
id: mem.fact.satan.psql-plumbing
name: "SATAN psql plumbing: shared module planned"
memory_type: fact
status: active
confidence: high
tags: [satan, db, dry]
summary: "Four modules carry private --query clones. DE-003 will extract dl-satan-db.el. Key gotcha: memory-store lacks -q flag; shared fn adds it."
provenance:
  sources:
    - "satan/dl-satan-memory-store.el:74"
    - "satan/dl-satan-patch-store.el:70"
    - "satan/dl-satan-attribute.el:84"
    - satan/dl-satan-memory-migrate.el
    - DE-003
    - DR-003
  verified: "2026-05-31"
scope:
  paths:
    - satan/dl-satan-memory-store.el
    - satan/dl-satan-patch-store.el
    - satan/dl-satan-attribute.el
    - satan/dl-satan-memory-migrate.el
links:
  out:
    - id: DE-003
  missing:
    - raw: DR-003
    - raw: POL-001
---

# SATAN psql plumbing: shared module planned

Four modules carry private psql `--query` functions with identical shapes.
[[DE-003]] will extract a shared `dl-satan-db.el`.

## Current state (2026-05-31)

| Module | Function | `-q` flag |
|--------|----------|:---------:|
| `dl-satan-memory-store.el` | `--query(db sql vars)` | ✗ |
| `dl-satan-patch-store.el` | `--query(db sql vars)` | ✓ |
| `dl-satan-attribute.el` | `--query(db sql vars)` | ✓ |
| `dl-satan-memory-migrate.el` | `--psql(db flags sql)` (different shape) | ✓ |

All three `--query` clones assemble identical psql args (`-X -A -t -F "\t" -v ON_ERROR_STOP=1`), run via `call-process-region`, return `(ok . stdout) | (error . msg)`.

## The `-q` gotcha

`-q` suppresses psql's welcome banner (`psql (16.x)\nType "help" for help.\n`).
**`dl-satan-memory-store--query` does NOT pass `-q`.** The welcome banner could
appear in stdout before the result. `string-trim` may strip it in practice, but
this is fragile — if stdout is otherwise empty, the banner becomes the result.

The shared `dl-satan-db-query` in [[DE-003]] will **always** pass `-q`, fixing
this for all callers.

## Each module uses different defcustoms

Each module names its config differently:

- `dl-satan-memory-store-host` / `-database` / `-psql-program`
- `dl-satan-patch-store-host` / `-database` / `-psql-program`
- `dl-satan-attribute-host` / `-database` / `-psql-program`

The shared fn accepts `(db host program sql vars)` — callers pass their own
defcustom values. No global config migration needed.

## Until DE-003 lands

Do NOT add a 5th psql `--query` clone. If a new module needs psql access:
1. Read `dl-satan-memory-store--query` for the pattern
2. Strongly prefer waiting for `dl-satan-db.el` instead
3. If unavoidable, include `-q` in psql args and add a note referencing this memory

## Related

- [[DE-003]] — delta that will extract `dl-satan-db.el`
- [[DR-003]] — design decisions (DEC-001 covers the shared signature)
- [[POL-001]] — extraction policy (confirms these modules stay in broker)
