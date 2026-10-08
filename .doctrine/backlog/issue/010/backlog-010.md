# ISS-010: Global keybindings scattered across modules; silent last-writer-wins conflicts

<!-- Backlog item body — context, detail, links. The structured, queried fields
     live in the sister `backlog-NNN.toml`; this prose is free-form and is never
     structurally parsed (the storage rule). -->

## What

Global keys are bound from ~30 modules (`:bind`, `global-set-key`,
`keymap-global-set`, `define-key global-map`) besides the two key
modules, `core/dl-keymap.el` (family maps, meow) and
`core/dl-keybind.el` (loose globals). The global map has one slot per
key, so whichever module loads last wins, silently. `dl-keybind.el`
loads late (`init.el` ~L99), so it overrides package modules.

Known casualties (found 2026-10-08):

- `C-;`: avy's `avy-goto-char-timer` (`editing/dl-motion.el`) dead under
  `iedit-mode` (`dl-keybind.el`). Fixed by deleting the avy binding.
- `C-=` / `C--`: `expreg-expand` / `expreg-contract`
  (`editing/dl-multi-edit.el`) dead under `text-scale-increase` /
  `-decrease` (`dl-keybind.el`). Pending a decision; trialled live.
- `C-0` is `text-scale-adjust`, so `C-0` is not a prefix argument.
  Intentional (2026-10-08): `M-0` / `C-u 0` cover the prefix; keep it.
- Stale comments claimed keys had moved when they hadn't (`C-'`).

Existing guard: `core/dl-policy-lint.el` checks only `C-c <letter>`
against `docs/KEYS.md`; `my/bind` warns only between personal bindings.

## Needs thinking

- **One place.** Move every global binding into the key modules, or keep
  `:bind` beside its package and only *lint* for conflicts? Tradeoff:
  cohesion of a package's config vs one readable key table. `:bind`
  also creates the autoloads that defer loading; a central table must
  keep that (`:commands`, or `autoload` + `keymap-global-set`).
- **Lint.** Detect two writers of one global key. Options: static scan
  of the source (reliable, misses computed keys), or record writers at
  load time (advise `keymap-set` / `define-key` on `global-map` during
  init, report keys written twice). An ERT test in `just check` beats a
  startup message nobody reads.
- **Load order.** Should `dl-keybind.el` load first (packages override,
  which is what `:bind` assumes) or last (explicit table wins)? Today
  it is last, implicitly.
- **Scope.** Mode maps (e.g. org's `C-,`, overridden in
  `completion/dl-embark.el`) and meow keypad translations can conflict
  too; decide whether the lint covers them.
- Naming: `my/global-text-scale-increase` on `C-M--` zooms *out*
  (`global-text-scale-adjust` flips on a `-` key); make the binding
  read honestly.

## Done when

- One documented home (or rule) for global bindings, in `docs/KEYS.md`.
- A test fails when two config files claim the same global key.
- Audit of current conflicts, each resolved or explicitly allowed.
