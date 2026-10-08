Key policy (SL-014, `docs/KEYS.md` R1–R5): package keys in `use-package :bind`,
ownerless keys as `bind-keys` in `core/dl-keybind.el`; `lisp/test/dl-policy-lint-test.el`
gates forbidden forms (L2) and duplicate (map, key) writes (L3).

Sharp edges found migrating:

- `bind-keys :map M` / `:bind (:map M …)`: M must be ONE symbol. bind-key's
  `:package` wrapper expands to `(if (boundp 'M) … (eval-after-load PKG …))`,
  which breaks on a list. Two maps → two `:map` sections.
- `use-package X :bind (:map M …)` binds immediately if M is bound, else after
  feature X loads. If M is defined by a different feature, the deferred bind
  hits `void-variable`. Example: `eshell-mode-map` is defined in `esh-mode`,
  which `(require 'eshell)` does not load → use `use-package esh-mode :ensure nil`.
- Adding `:bind` to a `use-package` without `:demand` makes it deferred. Never do
  that to an eagerly needed block (e.g. `use-package meow`, `use-package org`);
  bind from another block or `with-eval-after-load` + `bind-keys :map` instead.
- `bind-keys` at top level evaluates `:map M` immediately (same timing as the
  `define-key` it replaces).
