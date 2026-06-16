
# Stale bough binary lacks 'read' subcommand — bough tests fail / just check red

## Symptom

`just check` is RED: three tests fail —
`dl-satan-bough/{active-scope-shape, day-not-found-becomes-ok-nil,
week-scope-bounds}` — each asserting `(eq 'ok (car res))` but receiving
`(error . …)` from `dl-satan-tool/bough-read`.

## Root cause

The installed binary `~/.cargo/bin/bough` (v0.1.0) does **not** implement the
`read` subcommand the elisp invokes:

```
$ bough read --scope active --database-url postgresql:///satan_bough_test
error: unrecognized subcommand 'read'
  tip: a similar subcommand exists: 'rename'
```

The binary is stale relative to its Rust source / the elisp caller's
expectations. Postgres is up; the DB layer is fine — the subcommand is simply
missing from the installed build.

## Scope / provenance

- NOT a DE-007 regression. `satan/dl-satan-tools-bough.el` and its tests were
  last touched at DE-006 (`956af18`), well before DE-007; DE-007 does not touch
  bough.
- Surfaced during the DE-007 Phase-4 adversarial review (AUD-008 F-006).

## Fix

Rebuild/reinstall the `bough` binary from its Rust source (the subcommand
exists upstream; the installed artefact lags). e.g. `cargo install --path
<bough-crate>`. Then confirm `just check` is green.

## Why it matters

`just check` is the repo commit gate (AGENTS.md). While red, no delta can
legitimately close on the gate, even when the delta's own work is green.

