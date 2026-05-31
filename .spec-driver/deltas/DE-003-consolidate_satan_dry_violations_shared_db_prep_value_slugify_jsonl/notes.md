# DE-003 Implementation Notes

## 2026-05-31 — Code review + delta scoping

### Context

Comprehensive code review of SATAN broker (56 `.el` files, ~16,600 lines). Found
8 DRY violations. Scoped 6 into DE-003; 4 deferred to follow-up deltas.

### Key finding from adversarial review

During DR review, discovered `dl-satan-memory-store--query` does not pass `-q`
to psql (patch-store and attribute do). This is a latent bug: psql welcome banner
could leak into stdout. The shared `dl-satan-db-query` will always pass `-q`,
fixing this for all callers.

### Design decisions

- DEC-001: `dl-satan-db-query(db host program sql vars)` — always `-q`, explicit
  host/program params because each module has differently-named defcustoms.
- DEC-002: `dl-satan-jsonl-prepare` replaces 3 `--prep-value` clones.
- DEC-003: `dl-satan-memory-canon--slugify` is canonical slugify.
- DEC-004: `dl-satan-jsonl-read-file` gains `:null-object` kwarg.
- DEC-005: Shared `dl-satan-patch--build-review-commands(row)` with optional
  commits override.

### Risks

- R1: psql error handling breaks. Mitigation: test each module after switch.
- R2: `dl-satan-jsonl-prepare` alist conversion changes shape. Mitigation: verify
  all callers pass plists only.
- R3: circular require between memory-canon (slugify) and tools-hippocampus.
  Checked: tools-hippocampus already requires memory-canon. No cycle.
- R4: `-q` fix changes memory-store stdout. Mitigation: `string-trim` already
  strips banner; `-q` makes it deterministic.

### Deferred findings

- Mode tool-list composition (finding #7) → follow-up delta
- Broker spawn refactoring (finding #8) → follow-up delta
- Output handler factory (finding #11) → follow-up delta
- Cancellable "running" state race (finding #16) → follow-up delta

### Memories created

- `mem.signpost.satan.orientation` — agent architecture map
- `mem.fact.satan.psql-plumbing` — psql clone situation + `-q` gotcha
