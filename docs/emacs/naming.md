---
name: emacs-naming
description: Naming conventions for this Emacs config — `dl-MODULE`, `my/`, `--` private
metadata:
  type: reference
  topic: emacs
  status: canon
  updated_at: 03398479
  verified_at: 03398479
---

# Naming conventions

| Bucket | Prefix | Example |
| --- | --- | --- |
| File / `provide` symbol | `dl-MODULE` | `dl-faces`, `dl-shpool` |
| Module's public internals (vars, defcustoms, defface, helpers) | `dl-MODULE-name` | `dl-shpool-command`, `dl-meow-indicator-inactive` |
| Module's private internals | `dl-MODULE--name` | `dl-shpool--attach-args` |
| Personal command (user-callable) | `my/name` | `my/apply-fonts`, `my/journal-note` |
| Helper or variable supporting a `my/` command | `my/name` | `my/font-name`, `my/auto-save-idle-timer` |

Rules of thumb:

- **Role beats file.** A `my/` command living in a `dl-MODULE` file is fine
  (`my/apply-fonts` in `dl-faces.el`).
- **`my/` propagates through the helper family.** `my/shpool--candidate-status`
  is correct even though `dl-shpool` is the file — it's plumbing for the
  `my/shpool*` commands.
- **Defcustoms are always module-owned** → `dl-MODULE-...`.
- **Private gets `--`** regardless of bucket (`dl-shpool--attach-args`,
  `my/foo--helper`).

Grandfathered exceptions:

- **`my-X-map` keymaps** (`my-window-map`, `my-file-map`, `my-term-map`, …).
  `my/bind` and the meow leader-mirror discover maps by this name — renaming
  means updating the maps *and* the dispatch code, and the names straddle
  multiple modules. Cheaper to grandfather.
- **`meow-setup` in `dl-meow.el`.** The meow docs tell users to define a
  function by this exact name; it's an external API contract.
