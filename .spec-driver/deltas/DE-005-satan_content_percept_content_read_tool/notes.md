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

## 2026-05-31 P02

- 31/31 ert pass (23 P01 + 8 new sensor tests) in batch mode
- Files created: `satan/dl-satan-sensor-content.el`, `satan/test/dl-satan-sensor-content-test.el`
- Files edited: `satan/dl-satan-broker.el` (+ `(require 'dl-satan-sensor-content)`, + `_content-signal` probe call)
- Phase sheet: `phases/phase-02.md` (created + populated)

### DEC-5 implementation
- Sensor watermark stores max `captured_at` string verbatim (UTC-millis-Z), never formatted `now()`
- `dl-satan-sensor-content-mark-inspected` takes `high-water` directly (no default-to-now)
- `--count-uninspected` returns `(count . high-water)` — high-water is max captured_at seen
- Broker's `:ts` used ONLY in attribute payload, NOT for watermark

### Discoveries
- **Sensor depends on `dl-satan-tools-content`** for the lenient JSONL reader — cross-module dependency from sensor→tools. Acceptable per DR-005 (same in-tree family). Curiosity has no equivalent dependency because it reads a different data source (segments, not articles.jsonl).
- **`defcustom` clash in batch tests**: `let`-binding `dl-satan-attribute-updates-enabled` then `require`ing `dl-satan-attribute` inside the let caused "Defining as dynamic an already lexical var". Fixed by requiring `dl-satan-attribute` at top level and testing the disable path via `dl-satan-sensor-content-enabled` instead.
- **Call site confirmed**: `dl-satan-broker.el` line 743 (`let*` block, `condition-case` wrapped, after curiosity probe).

### Pending
- Git add new files (flake visibility — trap #1)
- `custom-vars.el` and `flake.nix` have uncommitted changes (compile-angel side effects); review before P04 switch
- P03 next: panopticon.content percept rule + evidence probe (O3)

## New Agent Instructions (2026-05-31)

### Task
Execute **Phase P03**: panopticon.content percept rule + evidence probe (O3).
Active phase sheet: `phases/phase-03.md` (needs creation).

### Required reading
- `DE-005.md` (§3 O3)
- `DR-005.md` (§4.3 percept rule, DEC-2)
- `IP-005.md` (§4 P03 row)
- `satan/dl-satan-memory-canon.el` — defrule pattern
- `satan/dl-satan-memory-evidence.el` — evidence window builder, browser-probe precedent
- `satan/dl-satan-resonance.el` — §S2 admission gate"
