# Notes for DE-005

## 2026-05-31 P01

- 23/23 ert pass in batch mode via `emacs --batch -L ./core -L ./satan -L ./satan/test ...`
- Files created: `satan/dl-satan-tools-content.el`, `satan/test/dl-satan-tools-content-test.el`
- Files edited: `satan/dl-satan.el` (+ `(require 'dl-satan-tools-content)`)
- Description file: `/workspace/notes/satan/tools/content_read.md`
- `just check` unavailable in this environment (needs running emacs server)

### Discoveries

- **`dl-satan-jsonl-read-file` arity bug**: byte-compiled arity is (3 . 3) because `defun` uses `&key` — P01 always uses the lenient reader to avoid this. The existing `dl-satan-tools-activity` has the same latent issue.
- **rg --json path nesting**: `call-process` works correctly with `(setq default-directory ...)` inside `with-temp-buffer`. rg `--json` output wraps `path` in `{:text "..."}` — must extract `(plist-get (plist-get data :path) :text)`.
- **`nreverse` for newest-first**: `(last all N)` returns file order (oldest→newest). Reversed to newest-first with `nreverse`.
- **search scope now uses condition-case for rg errors** (soft-fail), `call-process` with `t` destination (insert in current buffer), arg-vector (no shell).

## New Agent Instructions (2026-05-31)

### Task
Execute **Phase P02**: content-backlog sensor (O2) with DEC-5 watermark.
Active phase sheet: `.spec-driver/deltas/DE-005-satan_content_percept_content_read_tool/phases/phase-02.md`

### Required reading
- `DE-005.md` (§3 O2, risk R5 DEC-5)
- `DR-005.md` (§4.2 sensor contract, DEC-5 watermark)
- `IP-005.md` (§4 P02 row)
- `phase-02.md` (phase sheet — will need creating)
- `satan/dl-satan-sensor-curiosity.el` — clone target
- `satan/dl-satan-tools-content.el` — reuses `--read-jsonl-lenient`, `--clamp-limit`

### Key files
| Path | Change |
|------|--------|
| `satan/dl-satan-sensor-content.el` | **NEW** — sensor probe + watermark + disable switch |
| `satan/test/dl-satan-sensor-content-test.el` | **NEW** — ert suite |
| `satan/dl-satan.el` | EDIT — `(require 'dl-satan-sensor-content)` |
| (tick call site) | EDIT — add sensor probe alongside curiosity probe |

### Relevant memories
- `mem.pattern.satan.jsonl-arity-trap` — avoid `dl-satan-jsonl-read-file`; use lenient reader
- `mem.pattern.satan.rg-json-path` — rg `--json` path field is `{:text "..."}`
- `mem.signpost.satan.orientation` — SATAN architecture overview

### DEC-5 watermark (critical)
The content sensor's watermark stores the **max `captured_at` string seen verbatim** (UTC-millis-`Z`),
NOT a formatted `now()`. This is the ONE place the content sensor must NOT copy curiosity verbatim —
curiosity stores a local-offset timestamp (`+10:00`), and comparing `Z` vs `+` lexically is meaningless.
The broker passes `(plist-get prepare :time_now)` as `ts` — broker-generated, not a panopticon `captured_at`.

### Pending
- Phase-02.md needs creation (`spec-driver create phase IP-005 --phase 2`)
- Confirm exact tick/probe call site (mirror curiosity's registration) — implementation-time task
- `custom-vars.el` and `flake.nix` have uncommitted changes (compile-angel side effects); review before P04 switch
