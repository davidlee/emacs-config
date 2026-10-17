# Emacs in-process LLM clients via the LLM gateway

## Context

flakes:SL-011 built the LLM gateway: a LiteLLM proxy on
`http://127.0.0.1:4000/v1` that holds the provider keys. Each client holds
only its own gateway key, which has a budget and a model list. Keys are
0600 files under `~/.config/llm-gateway/keys/<client>`
(`~/flakes/features/agents/gateway/constants.nix`). The jailed eca was the
pilot. flakes:SL-013 moves the jailed pi and this repo's `flake.nix`
jails onto it.

That leaves the clients that run inside Emacs, unjailed. They still resolve
provider keys from 1Password:

```
~/.config/zsh/env.zsh:39-45   *_API_KEY=op://… (7 refs) ──inherited──> Emacs env
                                                                │
apps/dl-gptel.el     my/op-key DEEPSEEK | FIREWORKS | OPENROUTER | OPENAI_ALT
apps/dl-minuet.el    my/op-read-env OPENROUTER_API_KEY
apps/dl-eca.el:43    unjailed: ("op" "run" "--" "eca" "server")
```

Target:

```
gptel ───┐
minuet ──┼── own key file ──> 127.0.0.1:4000 (gateway) ──> providers
eca ─────┘   (one key per consumer: own budget, own ledger row)
```

The user decided (2026-10-17):

- one gateway key per consumer (`gptel`, `minuet`, `eca`);
- `ANTHROPIC_API_KEY` is dropped, not moved to the gateway;
- the Mistral, Voyage and Gemini refs are deleted with the `env.zsh`
  exports;
- this slice is sequenced after flakes:IMP-029.
- gptel's OpenAI models stay on the `openai-sub` OAuth backend, not the
  gateway. The `OPENAI_ALT` path (`dl-gptel-openai-key`, which has no
  callers) is deleted.
- minuet is set up but barely used. It moves to the gateway only if
  latency is acceptable (R4); if not, it may be dropped.

## Scope & Objectives

1. **One home for gateway access in elisp** (STD-001, one concern per
   file). A small module gives the gateway URL and a function that reads a
   named client's key file. The key is read when a request is made, never
   `setenv`'d, and never put in argv (gptel sends headers via
   `curl --config -`).
2. **gptel**: the DeepSeek, Fireworks and OpenRouter backends go through
   the gateway with the `gptel` key. Model lists come from what the
   gateway serves for that key. OpenAI models stay on the `openai-sub`
   OAuth backend; the unused `dl-gptel-openai-key` is deleted.
3. **minuet**: completion requests go to the gateway with the `minuet`
   key. Its budget is set separately, because autocomplete is the biggest
   spender.
4. **Unjailed eca**: no `op run`. It reaches the gateway with the `eca` key
   (or that mode is removed; see OQ-3).
5. **Remove the provider-key paths** that no longer have callers:
   `my/op-key`, plus any `my/op-read-env` callers that only existed for LLM
   keys. `my/op-read` stays for `org-gcal`.
6. **Retire the shell exports** in `~/.config/zsh/env.zsh:39-45` once
   nothing in Emacs or the flakes:SL-013 jails reads them. Outside this repo; see
   OQ-5.
7. **Docs**: `docs/emacs/secrets.md`, the commentary in `dl-gptel.el` and
   `dl-eca.el`, and `CHANGELOG.md` (name the backends and commands that
   changed).
8. **Issue keys**: `gptel`, `minuet` and `eca` (if needed) with
   `llm-gateway issue … --out ~/.config/llm-gateway/keys/<client>`. Model
   lists and budgets are settled in design.

## Non-Goals

- Adding gateway providers or models: flakes:IMP-029 does that, and is
  a prerequisite.
- satan (`~/dev/satan`, `~/flakes/features/satan/patcher.nix`):
  flakes:IMP-030, implemented by satan:SL-022 (owns satan's jails, harness,
  broker, patch path, `satan-credential.el` and the flakes `satan-patcher`
  module). No shared code: the jail launcher reads satan's key file, so
  satan needs no elisp key reader.
- This repo's `flake.nix` jail key forwarding: flakes:SL-013.
- OAuth sign-ins: gptel `openai-sub`, agent-shell/codex, Claude.
- `org-gcal`'s Google OAuth client credentials (`org/dl-org-gcal.el`): not
  LLM keys; they stay on `my/op-read`.
- The commented-out `my/op-key "OPENAI_ALT"` in `apps/dl-agent-shell.el`:
  update the comment only.

## Affected surface

| path | change |
|---|---|
| `lisp/dl-llm-gateway.el` (new; name set in design) | gateway URL and per-client key reader |
| `lisp/test/dl-llm-gateway-test.el` (new) | key reading and missing-key errors |
| `apps/dl-gptel.el` | backends go through the gateway |
| `apps/dl-gptel-shape.el` | per-backend request shaping, reviewed (OQ-2) |
| `apps/dl-minuet.el` | endpoint, key and model |
| `apps/dl-eca.el` | unjailed launch |
| `lisp/dl-secret.el`, `lisp/test/dl-secret-test.el` | `my/op-key` removed if unused |
| `apps/dl-agent-shell.el` | comment only |
| `docs/emacs/secrets.md`, `CHANGELOG.md` | docs |
| `~/.config/eca/config.json` | outside this repo; already points at the gateway for jailed eca |
| `~/.config/zsh/env.zsh` | outside this repo (OQ-5) |

## Risks & assumptions

- **A1**: flakes:IMP-029 lands OpenRouter, Fireworks and OpenAI on the gateway,
  covering the models gptel's hand-picked lists use, including
  `gpt-5.6-terra` and the Fireworks Nemotron model. Any model without a
  price-map entry drops out or waits (flakes:IMP-029's price-map lag).
- **R1: provider-specific request fields.** minuet sends OpenRouter's
  `provider: {sort: "throughput"}` and `reasoning_effort`, and
  `dl-gptel-shape.el` shapes bodies per backend. LiteLLM may drop or reject
  fields it doesn't know. Check in research.
- **R2: model naming.** The gateway serves its own names (e.g.
  `deepseek-flash`), not provider ids (`deepseek/deepseek-v4.1-flash`).
  The `gptel-openrouter` annotated-model helper and saved presets that
  name models may break.
- **R3: one backend vs several.** If gptel has a single "gateway" backend,
  you can't tell providers apart in its menus. If it has several, each
  needs the gateway to keep their model names distinct. Decide in design.
- **R4: minuet latency.** The gateway adds a loopback hop plus LiteLLM
  overhead, against minuet's 2.5 s timeout. Measure it.
- **R5: key file missing or unreadable** (not issued yet, or rotated). The
  error must name the client and the `llm-gateway issue` command, and must
  not fall back to 1Password.

## Open questions

- **OQ-1**: should the gateway module live in `lisp/` (beside
  `dl-secret.el`) or in `apps/`?
- **OQ-2**: does LiteLLM pass through OpenRouter's `provider` routing and
  `reasoning_effort`? If not, does minuet keep acceptable latency without
  them?
- **OQ-3**: should unjailed eca move to the gateway, or should unjailed
  mode (and `dl-eca-toggle-jail`) be deleted, since jailed is the default?
- **OQ-4**: one gptel backend or one per provider (R3)?
- **OQ-5**: should removing the `env.zsh` lines happen in this slice, or
  wait until flakes:SL-013 and flakes:IMP-030 have also removed their readers? The
  satan broker reads `OPENROUTER`, `OPENAI` and `DEEPSEEK` from the
  environment until flakes:IMP-030 (satan:SL-022) lands.

## Verification / closure intent

- ert: the gateway key reader resolves a client's file, errors on a
  missing or unreadable file, and never calls 1Password.
- `rg 'my/op-key|_API_KEY|op run' apps/ lisp/` shows only `org-gcal` and
  documented exceptions.
- Manual (VH): a gptel request on each backend and a minuet completion
  succeed, and `llm-gateway list` shows spend on the `gptel` and `minuet`
  keys. Unjailed eca starts and chats (if kept).
- `just check` green.

## Summary

Point gptel, minuet and unjailed eca at the LLM gateway, each with its own
key file. Remove their 1Password provider-key paths. Sequenced after
flakes:IMP-029.

## Follow-Ups

- Remove the `env.zsh` exports once satan (flakes:IMP-030, satan:SL-022) stops reading them, if
  OQ-5 defers it.
- Update flakes:IMP-030 and flakes:SL-013's non-goal on gptel: gptel is now in
  scope here (user, 2026-10-17).
