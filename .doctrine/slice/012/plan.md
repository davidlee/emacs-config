# Implementation Plan SL-012: Extract SATAN to standalone Elisp package

Prose companion to `plan.toml`. Narrative only — no queried data lives here
(the storage rule); the phase list, criteria, verification, and links are
authored in the TOML. Use this for the plan's rationale and sequencing.
<!-- Cite entities by padded id (SL-020, REQ-059); phases as PHASE-01,
     criteria as EN-1/EX-1/VT-1/VA-1/VH-1. See .doctrine/glossary.md § reference forms. -->

## Overview

Four phases: bring the tree up in its new repo under old names, rename,
decouple, cut the config over. Every phase ends with both repos green.

## Sequencing & Rationale

**Copy-then-cutover, not move.** The design says "move"; the plan implements
it as copy (PHASE-01) followed by delete-at-cutover (PHASE-04). Rationale: a
true move breaks `.emacs.d` (init.el requires `dl-satan` from the config tree)
until the consumer is rewired, which would leave three phases ending red in
one repo — against the end-green rule. The dual-presence window carries a
divergence risk, owned by PHASE-01 EX-5 (no-edits rule recorded in notes) and
PHASE-04 EN-2 (window audited closed at cutover). End state is identical to a
move.

**One risk isolated per phase boundary:**

- PHASE-01 isolates the design's top risk — *test regressions across the repo
  boundary* — by running the full suite in the new repo before anything else
  changes. Old names, zero semantic delta: any failure here is environmental
  (load-path, DB isolation, runner), not a rename or decouple bug.
- PHASE-02 is the pure-mechanical sweep (D3). Glob-driven, count-independent;
  its gates are the `rg`-empty invariants, so it absorbs whatever SL-011
  landed (D9). Docs and bin scripts rename here too — same mechanical class.
- PHASE-03 is the only behavioural change (D4). Kept out of the sweep so its
  diff is small and reviewable: a semantic bug in path derivation must not
  hide inside a thousand-line rename diff. New ERT coverage (VT-1) lands here
  — the path surface is the one genuinely new code in the slice.
- PHASE-04 is the only phase that touches consumers: config repo, `~/flakes`,
  host machine state (hook symlink, home-manager switch). Everything with a
  human-verifiable runtime consequence concentrates here (VH-1..3), so the
  human check happens once, at the end, against the finished package.

**Order of 02 before 03**: rename first means the decouple phase edits final
symbol names; done the other way, the sweep would rewrite the just-written
defcustom call sites. Mechanical before semantic keeps each diff attributable.

**SL-011 gate (D9)** lives in PHASE-01 EN-1: closed, or an explicit `/consult`
waiver — not silently reordered.

## Notes

- Verification is largely VA (agent-run gates: `just check`, `rg`-empty, flake
  eval) because the decisive checks are cross-repo shell invariants rather
  than in-repo test files; VT would report UNCHECKABLE without a mandate file.
  The single VT (PHASE-03 VT-1) anchors the only new test file.
- Host-side steps (satan.nix, hook re-link, home-manager switch) cannot run in
  the jail; PHASE-04 VH-2 carries them explicitly rather than pretending
  automation.
- OQ-1 (jail mount mechanism) is decided inside PHASE-04 (EX-4 requires the
  chosen mechanism recorded); OQ-3 (patterns.eld keys) inside PHASE-02 EX-5.
