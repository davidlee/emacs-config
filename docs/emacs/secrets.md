---
name: emacs-secrets
description: LLM gateway key files (`dl-llm-gateway-key`) + 1Password env-var flow and `dl-secret.el` API for op:// refs in Emacs
metadata:
  type: reference
  topic: emacs
  status: canon
  updated_at: 03398479
  verified_at: 03398479
---

# Secrets: LLM gateway keys and 1Password refs

API keys are not stored on disk in plaintext in this repo. Two mechanisms
serve two populations:

- In-process LLM clients (gptel, minuet) use per-client keys for the local
  LLM gateway, read from key files.
- Everything else that still needs a provider secret (satan, org-gcal)
  uses 1Password `op://vault/item/field` refs.

## LLM gateway keys

`lisp/dl-llm-gateway.el` owns where the gateway is and what a client's key is.

- `dl-llm-gateway-url` (default `http://127.0.0.1:4000/v1`): the
  OpenAI-compatible base URL.
- `(dl-llm-gateway-key CLIENT)`: returns the trimmed contents of
  `~/.config/llm-gateway/keys/<CLIENT>` (`dl-llm-gateway-key-directory`).
  The file is read on every call: no cache, no `setenv`, no 1Password
  fallback. A missing, unreadable or empty file signals a `user-error`
  naming the client and the `llm-gateway issue` command. Nothing is checked
  at load time, so Emacs starts cleanly before keys are issued.
- One key file (mode 0600) per consumer: `gptel`, `minuet`. (`eca` has its
  own key, read by `jailed-eca`, not by Emacs.) Each key has its own budget,
  model list and ledger row.

Manage keys with the `llm-gateway` CLI:

```
llm-gateway issue <client> --models M,... --budget USD \
  --out ~/.config/llm-gateway/keys/<client>
llm-gateway budget ALIAS USD     # lifetime USD cap
llm-gateway models ALIAS M,...   # REPLACES the whole list; refuses names the gateway does not serve
llm-gateway list
```

Client keys are never re-keyed in place. For rotation, see
`~/flakes/README.md` § LLM gateway, **Rotation.**

Accepted exposure, not suppressed: gptel's *Copy Curl command* puts the
key on the kill-ring, and through `select-enable-clipboard` onto the system
clipboard and any clipboard manager. `gptel-log-level 'debug` writes the
`Authorization` header to `*gptel-log*`. Both need a deliberate act; the key
is loopback-only and capped by its budget. gptel and minuet (via plz) send
headers through `curl --config -` on stdin, so the key never reaches argv.

## The 1Password flow

This serves satan and org-gcal (and the jailed agents' shell exports), not
the in-process LLM clients.

- `~/.config/zsh/env.zsh` exports each key with its **ref**:
  ```
  export SOME_API_KEY="op://VAULT/ITEM/credential"
  ```
- Terminal sessions: `op` plugin / `op run` wraps the shell so the ref is
  resolved by 1Password (biometric/desktop unlock) before any tool sees it.
- Sway/desktop launchers: zsh init never runs, so Emacs starts with **no**
  env. `lisp/dl-secret.el` parses `~/.config/zsh/env.zsh` at load and
  `setenv`s each declared var **only if unset**. Terminal-launched Emacs
  (already resolved values) wins over launcher-started Emacs (op:// refs).

## API

| Function | Use |
| --- | --- |
| `(dl-llm-gateway-key CLIENT)` | Gateway key for CLIENT, read from its key file on every call. |
| `(my/op-read REF &optional REFRESH)` | Resolve `op://...` to plaintext. Cached per session. |
| `(my/op-forget)` | Clear the session cache (after rotation). |
| `(my/op-session-p)` | Is a 1Password session live? Never prompts. |
| `(my/auth-source-secret &rest SPEC)` | Generic `auth-source-search` wrapper that returns the secret string, handling lambda secrets and utf-8 encoding. |

## Wiring a package

Pass the key as a **function** so it is re-resolved per request — never the
resolved string. gptel (`apps/dl-gptel.el`):

```elisp
(defun dl-gptel--key ()
  (dl-llm-gateway-key "gptel"))

;; gptel's :host must carry the port, so `dl-gptel--gateway' splits
;; `dl-llm-gateway-url' into :protocol, :host and :endpoint.
(apply #'gptel-make-openai "openrouter"
       :key #'dl-gptel--key
       :stream t
       :models '(...)
       (dl-gptel--gateway))
```

minuet (`apps/dl-minuet.el`):

```elisp
(plist-put minuet-openai-compatible-options :api-key
           (lambda () (dl-llm-gateway-key "minuet")))
```

Do not pass the key through `:curl-args` as a `-H` header: that puts it in
argv.

## Pitfalls

- `op read` needs the 1Password desktop app running + unlocked. Headless
  Emacs (batch) errors with `authorization timeout` — expected.
- Negative auth-source results cache for the Emacs session. After
  changing a keyring entry, `M-x auth-source-forget-all-cached`.
- Never `setenv` a secret in elisp; the env file is the source of truth
  for op:// refs.
- A 403 `model '<name>' not allowed` from the gateway means the key's model
  list lacks that name; fix it with `llm-gateway models`.
- Older path used gnome-keyring via `auth-source`/`secrets-create-item`.
  Still works (`my/auth-source-secret` is the helper) but the 1Password
  path is preferred for new keys.
