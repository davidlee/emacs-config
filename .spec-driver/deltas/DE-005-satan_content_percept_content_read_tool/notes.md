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
