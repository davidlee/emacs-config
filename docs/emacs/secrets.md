---
name: emacs-secrets
description: 1Password env-var flow + `dl-secret.el` API for resolving op:// refs in Emacs
metadata:
  type: reference
  topic: emacs
  status: canon
  updated_at: pending
  verified_at: pending
---

# Secrets and env vars (1Password)

API keys are not stored on disk in plaintext. They live in 1Password and are
referenced by `op://vault/item/field` strings.

## The flow

- `~/.config/zsh/env.zsh` exports each key with its **ref**:
  ```
  export OPENROUTER_API_KEY="op://API_KEYS/OPENROUTER_API_KEY/credential"
  ```
- Terminal sessions: `op` plugin / `op run` wraps the shell so the ref is
  resolved by 1Password (biometric/desktop unlock) before any tool sees it.
- Sway/desktop launchers: zsh init never runs, so Emacs starts with **no**
  env. `lisp/dl-secret.el` parses `~/.config/zsh/env.zsh` at load and
  `setenv`s each declared var **only if unset**. Terminal-launched Emacs
  (already resolved values) wins over launcher-started Emacs (op:// refs).

## `dl-secret.el` API

| Function | Use |
| --- | --- |
| `(my/op-read REF &optional REFRESH)` | Resolve `op://...` to plaintext. Cached per session. |
| `(my/op-read-env "VAR")` | Read env var; if value starts with `op://`, resolve. Else return as-is. |
| `(my/op-forget)` | Clear the session cache (after rotation). |
| `(my/auth-source-secret &rest SPEC)` | Generic `auth-source-search` wrapper that returns the secret string, handling lambda secrets and utf-8 encoding. |

## Wiring a package

Prefer `:key` (or equivalent) as a **lambda** so the secret is re-resolved
per request — never the resolved string:

```elisp
(gptel-make-openai "OpenRouter"
  :host "openrouter.ai"
  :endpoint "/api/v1/chat/completions"
  :key (lambda () (my/op-read-env "OPENROUTER_API_KEY"))
  :stream t)
```

## Pitfalls

- `op read` needs the 1Password desktop app running + unlocked. Headless
  Emacs (batch) errors with `authorization timeout` — expected.
- Negative auth-source results cache for the Emacs session. After
  changing a keyring entry, `M-x auth-source-forget-all-cached`.
- Do **not** `setenv` `OPENROUTER_API_KEY` etc. in elisp directly — the
  env file is the single source of truth.
- Older path used gnome-keyring via `auth-source`/`secrets-create-item`.
  Still works (`my/auth-source-secret` is the helper) but the 1Password
  path is preferred for new keys.
