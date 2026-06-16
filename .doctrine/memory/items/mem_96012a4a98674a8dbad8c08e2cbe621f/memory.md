# DE-011 enum sources

# DE-011 enum sources hardcoded

## Decision

For DE-011 enum introspection (schema show enums.\*), `spec.kind` and
`requirement.kind` will be hardcoded:

- `spec.kind`: `[
  "prod",
  "tech",
]`
- `requirement.kind`: `[
  "FR",
  "NF",
]`

Rationale: there are no lifecycle constants for these values today.

## Context

This resolves the Phase 2 open question in the DE-011 phase sheet.
