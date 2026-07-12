# Review RV-012 — reconciliation of SL-012

Adversarial-review ledger (ADR-007). Structured findings live in the sister
ledger toml; this prose companion carries the reviewer's framing.

## Brief

**Subject.** SL-012 — extract SATAN from `.emacs.d` into a standalone Elisp
package (`~/dev/satan`), renaming `dl-satan-*`/`my/satan-*` → `satan-*`. A
**3-repo** slice: config `~/.emacs.d`, package `~/dev/satan`, flakes `~/flakes`.
Source deltas captured textually in `notes.md` (record-delta is single-repo).

**Surface reviewed.** Inline execution (no dispatch); the candidate surface is
the committed working tree across all three repos + the slice's authored
canon (`design.md`, `plan.toml`, `notes.md`). Reviewed from the parent tree of
`/workspace/.emacs.d` (= host filesystem; verified: `satan/` gone, host commits
present).

**Lines of attack / invariants held:**
1. **Deletion + gate** — `satan/` and `docs/satan/` gone; `rg 'dl-satan-'` zero
   outside the literal exemption (`.doctrine/`, `.spec-driver/`, `CHANGELOG.md`).
2. **Green** — VA-1 `just check` passes against the *external* package via `-L`;
   VA-2/VA-3 (nix flake eval + build) evaluate.
3. **Canon truth** — does `design.md`/`plan.toml` describe what actually shipped,
   or did mid-flight revisions (D10 self-location, decouple surface) escape write-back?
4. **Coupling severed** — both config-root axes (notes-root D4 + self-location
   D10) decoupled; no residual `user-emacs-directory`/`~/.emacs.d` assumption in
   the shipped package.
5. **Knowledge/wiring debt** — stale memory, untracked memory, `path:` vs
   `github:` flake input, history hygiene.

**Evidence run (audit, sandbox):**
- EX-5 rg gate: **zero** hits outside exemption. `satan/` + `docs/satan/` **gone**.
- VA-1: re-ran the `check` suite against `/workspace/satan/satan` (sandbox path
  for the host's `~/dev/satan/satan`) → **PASS 10/10** (doctor suite resolves the
  renamed interface via external `-L`). Independently confirmed, not trusted.
- VA-2/VA-3 (nix): host-verified per `notes.md:245-249` (`nix build …satan-jailed-gptel-harness`
  → store path; config flake package-set = 7 non-satan jails, both satan entries
  gone). Not sandbox-reproducible (no `nix` binary) — provenance = host, recorded.
- Canon check: `design.md` **already carries** D10 (Axis-2 self-location +
  `satan--root`, §326-373) and the D1 linter copy (§256-257) — the two largest
  mid-flight revisions are reconciled. `denote-journal`: **zero** occurrences in
  `design.md` → decouple inventory gap confirmed (F-1).

## Synthesis

**Closure story.** SL-012 landed the whole SATAN codebase (~18.7k lines, 64
modules, 61 test files) out of `.emacs.d` into a standalone package at
`~/dev/satan`, renamed `dl-satan-*`/`my/satan-*` → `satan-*`, and rewired three
repos. The audit finds the **implementation correct and the primary canon
truthful**: the deletion is complete, the EX-5 namespace gate is literally zero,
VA-1 passes against the extracted package (independently re-run, 10/10), and the
nix build/eval gates were host-verified. Critically, the two *design-tier*
mid-flight revisions — D10 package self-location (`satan--root`) and the D1
linter self-containment — were **already written back into `design.md`** during
execution, so canon does not lie about the shipped shape on those axes.

**Two config-root axes, both severed.** The slice's hardest technical problem was
that the package assumed it lived under the config root on *two* independent axes:
the notes corpus (`dl-notes-root`, D4) and its own code/data location
(`user-emacs-directory`, D10). PHASE-01 proved Axis-2 breaks the *shipped*
package, not just tests; the response was a proper `satan--root` self-location
convention in a zero-dependency leaf (`satan-custom.el`) rather than a spot-fix.
That is the right call and it is reflected in canon.

**What escaped write-back (the findings).** Six findings, no blockers:
- **F-1 (major, verified)** — the decouple inventory in `design.md`/`plan.toml`
  under-counted the coupling surface: it names only `dl-notes-paths`, but a
  *third* config-root coupling (`dl-denote-journal`, in `context.el` +
  `tools-org.el`) had to be severed at PHASE-03, which in turn exposed a latent
  missing `(require 'calendar)`. Code is correct; the prose is incomplete. →
  reconcile.
- **F-3 (major, verified)** — `mem.signpost.satan.orientation` still describes the
  pre-extraction world (`~/.emacs.d/satan`, `dl-satan-*`, 56 files). Reconciled
  memory must tell the truth or it misdirects every future agent. → reconcile.
- **F-2 (major, follow-up)** — the `~/flakes` satan input is `path:` (host-local),
  correct only until the satan repo is pushed; then it must flip to
  `github:davidlee/satan`. Owned wiring work gated on `git push`. → backlog.
- **F-4 (minor, verified)** — `mem.fact.satan.package-self-location-coupling`
  (cited by locked D10) is untracked. → reconcile git-add.
- **F-5 (minor, aligned)** — a live post-cutover regression: two consumers fed the
  raw `~`-prefixed `satan-notes-root` to `call-process` (no `~` expansion); blast
  radius correctly scoped to exactly those two, fixed with regression tests
  (satan `0452f9c`, `14963de`). Resolved in-flight, no debt.
- **F-6 (nit, tolerated)** — duplicate delete commits + an interleaved SL-013 in
  the config PHASE-04 window; cosmetic, history already shared.

**Standing risks accepted.** (a) VA-2/VA-3 provenance is host-only — no nix in the
audit sandbox — so those gates rest on the operator's recorded runs, not an
independent re-run. (b) The `path:` flake input (F-2) means the flakes repo does
not yet build SATAN reproducibly from origin; benign on the author's host,
blocking for anyone else, until the push + flip. (c) Cross-repo deltas live as
prose in `notes.md`, not in a queryable record-delta ledger — a permanent trait
of a 3-repo slice, not a defect.

**Verdict.** The work conforms to design and governance. Every gap is
consciously dispositioned; nothing gates close. Hand off to `/reconcile` to write
back F-1/F-3/F-4 and mint the F-2 backlog item.

## Reconciliation Brief

Every non-aligned, non-tolerated finding that touches canon or owned work, grouped
by write surface.

### Per-slice (direct edit)
- **design.md § D4 (decouple table) + plan.toml decouple file-list** — F-1: add
  `dl-denote-journal` as the third config-root coupling axis (severed in
  `context.el` + `tools-org.el`; today→`satan-journal-today` injection,
  weekly→`declare-function` soft-dep), and note the transitive
  `(require 'calendar)` self-containment fix in `satan-memory-evidence.el`. The
  decouple inventory currently enumerates only `dl-notes-paths`.

### Knowledge (memory)
- **mem.signpost.satan.orientation** — F-3: rewrite to reconciled truth — code
  home `~/dev/satan`, `satan-*` namespace, current layer/file map, `satan--root`
  self-location convention. Drop the pre-extraction `~/.emacs.d/satan` / `dl-satan-*`
  / "56 files" description. Do via `/record-memory`.
- **mem.fact.satan.package-self-location-coupling** — F-4: `git add` it (cited by
  locked design.md D10; currently untracked).

### Owned work (backlog)
- **F-2** — mint a backlog item (risk/chore): flip `~/flakes` satan input from
  `path:` → `github:davidlee/satan` once the satan repo is pushed to origin.
  Until then the flakes repo does not build SATAN reproducibly from a clean clone.

### No-action (recorded, not carried)
- **F-5** (aligned) — regression fixed + tested in-flight; no write-back.
- **F-6** (tolerated) — history cosmetic; no rewrite.
