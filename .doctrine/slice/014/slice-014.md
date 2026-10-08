# Global keybinding ownership and collision lint

## Context

`global-map` has one slot per key. About 32 config modules write to it:
36 `use-package :bind` sites, plus direct `global-set-key` /
`keymap-global-set` calls (`core/dl-keybind.el` 36, `core/dl-keymap.el`
16, `editing/dl-crux.el` 6, a handful of single calls elsewhere). When
two modules claim one key, the module that loads last wins, and nothing
reports it. `core/dl-keybind.el` loads late (`init.el` L99, after the
package modules), so it wins every clash by accident, not by rule.

Commit 2543bdb fixed the known casualties (`C-;` avy vs iedit; `C-=` /
`C--` expreg vs text-scale). ISS-010 still lists `C-=` / `C--` as
pending; that is stale — expreg owns them now, zoom moved to `C-+` /
`C-_`.

Existing guards are narrow:

- `core/dl-policy-lint.el` checks only `C-c <letter>` against the
  family-map allow-list in `docs/KEYS.md` (startup message + `M-x
  my-policy-lint`; no ERT test).
- `my/bind` (`core/dl-keymap.el` L49) warns only when *it* overwrites a
  binding; plain `:bind` and `global-set-key` never warn.

## Scope & Objectives

1. **Ownership rule.** Decide and document in `docs/KEYS.md` where a
   global binding may be written, and which writer wins on purpose.
2. **Collision detection in `just check`.** An ERT test that fails when
   two config files claim the same global key, unless the pair is on an
   explicit allow-list.
3. **Audit.** Run the detector over the current config; resolve each
   collision or allow-list it with a reason.
4. **Honest zoom.** Bind `global-text-scale-adjust` directly (it
   dispatches on the invoking key) and delete the misleading
   `my/global-text-scale-*` wrappers.
5. **Form consistency.** Mode-map writes migrate to `:bind (:map …)` /
   `bind-keys :map`, so every personal bind shows in
   `describe-personal-keybindings`.

## Non-Goals

- Remapping keys for ergonomics beyond resolving found collisions.
- Meow normal-state motion (`h/j/k/l` stays; see home context).
- IMP-019's mode-owned `C-c` range rule and live per-mode probe — a
  separate item, though it may reuse this slice's lint plumbing.

## Resolved questions (see design.md)

- **Q1 One home vs lint only** → hybrid: `:bind` stays with its package;
  every other key moves to `core/dl-keybind.el` as `bind-keys` (R1, R2).
- **Q2 Detection** → static scan of sources in an ERT test (L2 sanctioned
  forms, L3 duplicates). The full census is a disposable scratch tool.
- **Q3 Load order** → moot under R4 (one writer per key).
- **Q4 Scope** → mode-map duplicates, remap/vector keys, the `C-c i`
  allow-list drift, and L1 as an ERT test are all in. Meow
  `*-define-key` lists are out (one place, meow's DSL).
- **Q5** → one key-policy module: `core/dl-policy-lint.el`.

## Affected surface

- `core/dl-keybind.el`, `core/dl-keymap.el`, `core/dl-policy-lint.el`
- Modules with `:bind` / global writes under `core lisp org editing
  completion apps lang dev`
- `docs/KEYS.md` (rule), `lisp/test/dl-policy-lint-test.el` (new),
  `CHANGELOG.md`, `docs/REVIEW.md`
- Deleted: `lisp/dl-global-text-scale.el`, `my/ghostel-toggle`

## Risks & assumptions

- A static scan must parse `:bind` forms faithfully (`("C-x" . cmd)`,
  `(:map foo-map …)` sections, `bind-key` strings in `kbd` syntax vs
  `keymap-*` syntax); key normalisation is the crux.
- `:bind (:map X)` on a `use-package` whose subject doesn't define X
  defers to the wrong package's load; resolve per site (design § Risks).
- Assumes `just check` stays `emacs -Q` batch (no full init).

## Verification / closure intent

- `docs/KEYS.md` states the ownership rule.
- ERT test in `just check`: red on a seeded duplicate global key, green
  on the real config.
- Audit table (key, writers, resolution) recorded in slice notes; every
  collision resolved or allow-listed.
- Collisions resolved per design (`C-:` avy, ``C-M-` `` popper,
  `C-<f1>` popterm); global zoom keys behave as labelled.
- `just check` green; elisp paren checker clean on every touched file.

## Summary

Make global key ownership explicit and make collisions fail a test,
instead of resolving silently by load order.

## Follow-Ups

- IMP-019 mode-owned `C-c` range rule, likely on the same lint module.
- Correct ISS-010's stale `C-=` / `C--` line when the slice closes.
