# CHR-013: Elisp lint gate: config byte-compiles warning-free

<!-- Backlog item body — context, detail, links. The structured, queried fields
     live in the sister `backlog-NNN.toml`; this prose is free-form and is never
     structurally parsed (the storage rule). -->

Make every tracked config `.el` byte-compile with zero errors and zero
warnings under Flymake's elisp backend, and keep it that way.

Baseline (2026-11-10): 246 diagnostics in 65 of 180 files. Kinds: undefined
function (83), function maybe undefined at runtime (52), unused lexical
variable (39), free variable (46), other (~25: obsolete APIs, defface
without `:group`, macro defined too late, malformed function, load failures).

Approach:
- `bin/elisp-lint` reproduces `elisp-flymake--batch-compile-for-flymake`
  with the load path `lang/dl-elisp.el` hands Flymake, over every tracked
  `.el` (excluding `elpa/`, `themes/`). `just lint` runs it; `just check`
  fails on any diagnostic.
- Fix order per `lang/dl-declare.el`: `require` when the file needs the
  library anyway; `declare-function` / `defvar` only for deliberate soft
  dependencies. Test files require the module under test.
- Checkdoc notes are out of scope.

Governance: the user chose a backlog item over a slice on 2026-11-10
(sized at one session, mostly mechanical).
