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
   the gateway with the `gptel` key, one backend per provider (DEC-002),
   with hand-picked gateway model names (DEC-003). DeepSeek is reached only
   natively, never via OpenRouter (DEC-006). `gptel-openrouter` is dropped
   (DEC-004). OpenAI models stay on the `openai-sub` OAuth backend; the
   unused `dl-gptel-openai-key` is deleted.
3. **minuet**: completion requests go to the gateway's `deepseek-flash`
   with the `minuet` key (DEC-007). Its budget is set separately.
4. **Unjailed eca is deleted** (DEC-008): it was already broken, and
   jailed eca reaches the gateway on its own key.
5. **Remove the provider-key paths** (DEC-009): `my/op-key`,
   `my/op-key-vault`, `my/op-read-env`. `my/op-read` stays for `org-gcal`
   and `my/satan-credential`.
6. ~~Retire the shell exports~~: deferred to a follow-up (DEC-009). satan
   (satan:SL-022) and `~/flakes/agents/jailed-agents.nix` still read them.
7. **Docs**: `docs/emacs/secrets.md`, the commentary in `dl-gptel.el` and
   `dl-eca.el`, and `CHANGELOG.md` (name the backends and commands that
   changed).
8. **Issue keys** (DEC-010): the user issues `gptel` and `minuet`; gptel's
   model list widens after flakes:SL-014 PHASE-05.

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
| `apps/dl-gptel-shape.el` | a `deepseek` shaper: flatten reasoning, effort `low` sent as `none` (DEC-005) |
| `apps/dl-gptel-presets.el` | presets use gateway names (DEC-006) |
| `custom-vars.el` | drop the `gptel-openrouter` package-vc entry (DEC-004) |
| `apps/dl-minuet.el` | endpoint, key and model |
| `apps/dl-eca.el` | unjailed mode deleted |
| `lisp/dl-secret.el`, `lisp/test/dl-secret-test.el` | `my/op-key` removed if unused |
| `lisp/test/dl-gptel-presets-test.el`, `lisp/test/dl-eca-test.el` | follow backend, shaping and eca-launch changes |
| `apps/dl-agent-shell.el` | comment only |
| `docs/emacs/secrets.md`, `CHANGELOG.md` | docs |
| `~/.config/eca/config.json` | outside this repo; already points at the gateway for jailed eca |
| `~/.config/zsh/env.zsh` | outside this repo; deferred (DEC-009) |

## Risks & assumptions

- **A1**: flakes:IMP-029 (delivered by flakes:SL-014) lands OpenRouter and
  Fireworks on the gateway, covering every model in gptel's hand-picked
  lists and the Fireworks Nemotron model. OpenAI is deferred to
  flakes:IMP-035 (flakes:DEC-072); gptel keeps OpenAI on `openai-sub`. One
  id is corrected here: `qwen/qwen-3.8-flash` → `qwen/qwen3.8-flash`.
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

All resolved in design (2026-10-18):

- **OQ-1** (module location): `lisp/dl-llm-gateway.el` (DEC-001).
- **OQ-2** (LiteLLM passthrough): yes, both fields reach OpenRouter
  (research); minuet uses native `deepseek-flash` anyway (DEC-007).
- **OQ-3** (unjailed eca): deleted (DEC-008).
- **OQ-4** (backends): one per provider (DEC-002).
- **OQ-5** (`env.zsh`): deferred to a follow-up (DEC-009).

## Verification / closure intent

- ert: the gateway key reader resolves a client's file, errors on a
  missing or unreadable file, and never calls 1Password. `@deep` with
  `@quick` sends thinking off (`"none"`) and with `@think` thinking on.
- The removed key functions match nothing in the repo's `.el` files, with
  a positive control and checks on the retained consumers (design sec-9).
- Manual (VH): a gptel request on each backend and a minuet completion
  succeed, and `llm-gateway list` shows spend on the `gptel` and `minuet`
  keys.
- `just check` green.

## Summary

Point gptel and minuet at the LLM gateway, each with its own key file,
and delete unjailed eca. Remove their 1Password provider-key paths. Sequenced after
flakes:IMP-029.

## Follow-Ups

- Remove the `env.zsh` exports once satan (flakes:IMP-030, satan:SL-022) stops reading them, if
  OQ-5 defers it.
- Update flakes:IMP-030 and flakes:SL-013's non-goal on gptel: gptel is now in
  scope here (user, 2026-10-17).
