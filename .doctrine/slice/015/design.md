<!-- doctrine:section sec-1 -->
# SL-015 design: Emacs in-process LLM clients via the LLM gateway

gptel and minuet stop resolving provider keys from 1Password. Each one
reads its own key for the local LLM gateway (flakes:SL-011, a LiteLLM
proxy at `http://127.0.0.1:4000/v1`) from
`~/.config/llm-gateway/keys/<client>`. Every key has its own budget and its
own row in the gateway's spend ledger. eca's unjailed mode is deleted.

Decisions: DEC-001 to DEC-010. Evidence:
`.doctrine/slice/015/research/research.md`.

<!-- doctrine:section sec-10 -->
## Risks

- **The gateway's model names drift** from gptel's static lists (DEC-003).
  A renamed model fails with the gateway's 403 `gptel: model '<name>' not
  allowed`, which names the key and the model but not what is served.
  G2 compares every list with `gateway.nix` once.
- **The PHASE-05 timing is outside this slice.** [B] waits on it. [A] is
  useful on its own (DeepSeek, minuet, eca) and leaves no half-moved
  backend: `openrouter` and `fireworks` stay direct until [B].
- **DeepSeek effort granularity** (research finding 7). Effort on
  `deepseek-flash` is only thinking on or off. This is accepted, and the
  presets document it.
- **gptel internals.** The shaper hooks `gptel--request-data`, which is
  internal to gptel. The existing presets tests catch a change in it.
  gptel-deepseek with a non-default host is supported: `:host`,
  `:protocol` and `:endpoint` are constructor arguments
  (`gptel-openai-extras.el:336-387`).
- **Key exposure through gptel's copy-curl action (kill-ring and system
  clipboard) and debug logging.** It is documented and accepted (sec-3).

<!-- doctrine:section sec-11 -->
## Out of scope / follow-ups

- Retire the `env.zsh` LLM exports, and the env-file sourcing of them,
  once satan:SL-022 and `~/flakes/agents/jailed-agents.nix` stop reading
  them. This needs a backlog item in this repo or in flakes, depending on
  who owns `env.zsh` (flakes `features/terminal/zsh.nix` sources it).
- Update flakes:SL-013's non-goal about gptel, and the flakes README line
  "unjailed eca is unchanged" (`README.md:917-919`). Both are in the
  flakes repo, so they are raised there, not edited from here.
- flakes:IMP-035 (OpenAI behind the gateway) does not affect `openai-sub`.
- AGENTS.md:97 links to `docs/satan/refactor/extraction-policy.md`, which
  doesn't exist. Unrelated; noted for the backlog.

<!-- doctrine:section sec-2 -->
## Current vs target

```
current                                      target
───────                                      ──────
env.zsh  *_API_KEY=op://…                    ~/.config/llm-gateway/keys/{gptel,minuet}
   │  (sourced into Emacs by dl-secret)         │  read per request
   ▼                                            ▼
my/op-key / my/op-read-env ──> op CLI        dl-llm-gateway-key CLIENT
   │                                            │
gptel  deepseek   ──> api.deepseek.com       gptel deepseek   ┐
gptel  fireworks  ──> api.fireworks.ai       gptel fireworks  ├─> 127.0.0.1:4000 ──> providers
gptel  openrouter ──> openrouter.ai          gptel openrouter ┘    (gateway)
minuet ──> openrouter.ai (deepseek via BYOK) minuet ─────────────>  deepseek-flash
eca unjailed: op run eca (already broken)    (deleted; jailed eca unchanged)
gptel openai-sub (OAuth)                     gptel openai-sub (OAuth), unchanged
```

DeepSeek is reached only through the gateway's native `deepseek-flash`,
never through OpenRouter (DEC-006). OpenRouter forwarded those requests to
DeepSeek on the user's own key, with one extra hop that took 2–4× longer to
the first token (research R4).

<!-- doctrine:section sec-3 -->
## Gateway access module: `lisp/dl-llm-gateway.el` (DEC-001)

The module has one concern (STD-001): where the gateway is, and what a
named client's key is. It sits in `lisp/` next to `dl-secret.el`, the shared
helpers that belong to no single package. It does not depend on
`dl-secret`.

```elisp
(defgroup dl-llm-gateway nil "Local LLM gateway access." :group 'tools)

(defcustom dl-llm-gateway-url "http://127.0.0.1:4000/v1"
  "Base URL of the local LLM gateway (OpenAI-compatible)." :type 'string)

(defcustom dl-llm-gateway-key-directory "~/.config/llm-gateway/keys"
  "Directory holding one key file per gateway client." :type 'directory)

(defun dl-llm-gateway-key (client)
  "Return gateway CLIENT's key, read from its key file now.
Signal `user-error' naming CLIENT and the issue command if the file is
missing, unreadable or empty.")
```

- **Read on every call, no cache.** Reading a 47-byte file costs
  nothing next to an HTTP request. A rotated key file (flakes
  `README.md:994-1002`) takes effect on the next request.
- **Trimmed.** The file is `sk-…\n` (`llm-gateway:250`). gptel trims the
  key; minuet does not. The reader trims, so callers don't depend on that.
- **Error (R5).** The message reads: `No LLM gateway key for gptel at
  ~/.config/llm-gateway/keys/gptel; issue one: llm-gateway issue gptel
  --models … --budget … --out ~/.config/llm-gateway/keys/gptel`. The
  message carries no model or budget: those are the issuer's choice, and
  the commands this slice uses are in sec-9. It follows
  the precedent in `~/.nix-profile/bin/jailed-eca:2-5`. There is no
  1Password fallback.
- **No `setenv`, no argv.** Clients pass `(lambda () (dl-llm-gateway-key
  "<client>"))` as their key function. gptel and minuet (through plz) both
  send headers in the curl config on stdin (`gptel-request.el:2888-2890`,
  `plz.el:430`). Two paths do expose the key, and both need a deliberate
  act by the user: gptel's *Copy Curl command* puts it on the kill-ring,
  which `select-enable-clipboard` also copies to the system clipboard
  (and so to any clipboard manager), and `gptel-log-level 'debug` writes
  the request config, with the `Authorization` header, to the
  `*gptel-log*` buffer. Both are accepted, documented in `secrets.md`,
  and not suppressed: redacting them would mean hooking more gptel
  internals. The key is loopback-only and capped by its budget.
- **Whether a key exists is not checked at load time.** A missing key
  shows up as a `user-error` on the first request, so Emacs starts cleanly
  before keys are issued.

The module provides no gptel-specific helper. URL parsing for gptel's
`:host` and `:protocol` stays in `dl-gptel.el`, so the module does not
depend on any one client.

<!-- doctrine:section sec-4 -->
## gptel

### Backends (DEC-002)

There are three gateway backends, all with the `gptel` key. They are built
by one small local helper, `dl-gptel--gateway`, which derives `:protocol`
and `:host` from `dl-llm-gateway-url` using `url-generic-parse-url`. It
returns the shared keyword arguments, and is kept only if it makes the
three constructor calls clearer (Codex review, point 6).

| backend | constructor | models (gateway names, DEC-003) |
|---|---|---|
| `deepseek` | `gptel-make-deepseek` | `deepseek-flash`, with the properties copied from gptel's own entry: capabilities `(media tool-use reasoning url)`, its mime-types and context window (`gptel-openai-extras.el:344-349`) |
| `openrouter` | `gptel-make-openai` | `openrouter/openrouter/auto`, `openrouter/openrouter/free`, `openrouter/openrouter/pareto-code`, `openrouter/qwen/qwen3.8-flash` (id corrected from `qwen-3.8-flash`), `openrouter/z-ai/glm-5.3-flash`, `openrouter/~z-ai/glm-flash-latest`, `openrouter/~z-ai/glm-latest`, `openrouter/google/gemini-3.8-flash`, `openrouter/google/gemini-3-flash-preview`, `openrouter/xiaomi/mimo-v2.6-pro`, `openrouter/xiaomi/mimo-v2.6-flash` |
| `fireworks` | `gptel-make-openai` | `fireworks/nemotron-lightning-3p5-30b-a3b` |

The openrouter and fireworks models are bare names with no
`:capabilities`, so gptel sends them no images (IMP-028).

- Gateway names are `openrouter/<OpenRouter id>` (`~/flakes/agents/gateway.nix:22-30`),
  so OpenRouter's own routers carry a double prefix:
  `openrouter/openrouter/auto`. Every name is checked against
  `gateway.nix:62-83` while implementing. There are no
  `openrouter/deepseek/*` entries (DEC-006).
- A gateway host is not `api.openai.com`, so gptel uses the
  chat-completions dialect at `/v1/chat/completions`
  (`gptel-openai.el:820-830`). The endpoint path comes from
  `dl-llm-gateway-url`'s path plus `/chat/completions`.
- `gptel-make-deepseek` keeps gptel's DeepSeek behaviour: it merges
  consecutive messages with the same role, and it sends
  `reasoning_content` back with tool results. pi's gateway client for
  `deepseek-flash` (flakes:SL-013, `thinkingFormat "deepseek"`) does the
  same.
- `openai-sub` (OAuth) and the default `gptel-model` are unchanged.

### gptel-openrouter removed (DEC-004)

Removed: the `use-package gptel-openrouter` block (`apps/dl-gptel.el:99-142`),
its `package-vc` entry (`custom-vars.el:38-39`), the stale cache comment,
and the variable `dl-gptel-openrouter`, which is written but never read
(`:59-60,112`). The `(require 'macher)` inside that block already runs from
gptel's own `:config` (`:55-57`), so nothing is lost.

### Request shaping (DEC-005)

`dl-gptel-request-shapers` becomes:

```elisp
'(("deepseek" . dl-gptel-deepseek-thinking)
  ("openrouter" . dl-gptel-flat-reasoning-effort)
  ("fireworks" . dl-gptel-flat-reasoning-effort))
```

All three gateway backends send flat `reasoning_effort`, the gateway's one
reasoning control (flakes:SPEC-001 FR-006, flakes:DEC-074). `openrouter`
moved off the nested `reasoning` object in PHASE-05 by user direction
(2026-10-18); DEC-011 supersedes DEC-005.

On `deepseek-flash`, LiteLLM turns `reasoning_effort` into DeepSeek's
`thinking` switch: `"none"` becomes disabled and every other value
becomes enabled (`litellm/llms/deepseek/chat/transformation.py:21-61`).
Flattening alone would leave `@quick` (`"low"`) thinking on, the same as
`@think`. So `deepseek` gets its own shaper, a pure function beside
`dl-gptel-flat-reasoning-effort`:

```elisp
(defun dl-gptel-deepseek-thinking (data)
  "Return request DATA flattened, with effort \"low\" sent as \"none\".
DeepSeek's thinking is on or off; LiteLLM disables it only for \"none\"."
  (let ((flat (dl-gptel-flat-reasoning-effort data)))
    (if (equal (plist-get flat :reasoning_effort) "low")
        (plist-put flat :reasoning_effort "none")
      flat)))
```

| preset on `@deep` | sent | DeepSeek |
|---|---|---|
| none | no `reasoning_effort` | its default |
| `@quick` | `"none"` | thinking off |
| `@think` | `"high"` | thinking on |

The preset commentary says effort on `@deep` is only on or off.

### Presets (DEC-006)

| preset | backend | model |
|---|---|---|
| `gpt` | `openai-sub` | `gpt-5.6-terra` (unchanged) |
| `deep` | `deepseek` | `deepseek-flash` |
| `glm` | `openrouter` | `openrouter/~z-ai/glm-latest` |
| `gem` | `openrouter` | `openrouter/google/gemini-3.8-flash` |
| `nemo` | `fireworks` | `fireworks/nemotron-lightning-3p5-30b-a3b` |

Descriptions change from "OpenRouter" to "via gateway" where it applies.
`quick` and `think` are unchanged.

### Tests: `lisp/test/dl-gptel-presets-test.el`

- The backend stand-ins (`:19-22`) gain `("deepseek" . <gateway host>)`,
  and the gateway backends use the gateway host. The stand-in for
  `deepseek` is built with `gptel-make-deepseek`, so the shaper sees the
  real class.
- New tests: `deep` with `think`, in either order, sends
  `:reasoning_effort "high"` and no `:reasoning`; `deep` with `quick`, in
  either order, sends `:reasoning_effort "none"` and no `:reasoning`.
  The `quick` test is the negative control: plain flattening sends
  `"low"` and must fail it.
- The fireworks-flat test now covers openrouter too: both send flat
  `reasoning_effort` in either preset order (PHASE-05 VT-3). Model names
  follow the new presets.
- `@deep` → backend `"deepseek"` (`:101` was `"openrouter"`).

<!-- doctrine:section sec-5 -->
## minuet (DEC-007)

`apps/dl-minuet.el`:

```elisp
(require 'dl-llm-gateway)
...
(plist-put minuet-openai-compatible-options :end-point
           (concat dl-llm-gateway-url "/chat/completions"))
(plist-put minuet-openai-compatible-options :api-key
           (lambda () (dl-llm-gateway-key "minuet")))
(plist-put minuet-openai-compatible-options :model "deepseek-flash")
;; thinking off: LiteLLM maps "none" to DeepSeek's thinking: disabled
(minuet-set-optional-options minuet-openai-compatible-options :reasoning_effort "none")
(minuet-set-optional-options minuet-openai-compatible-options :max_tokens 56)
(minuet-set-optional-options minuet-openai-compatible-options :top_p 0.9)
```

- The OpenRouter-only `:provider (:sort "throughput")` field is removed.
- The file gains an explicit `require`; today it relies on `init.el:96`
  loading `dl-secret` first.
- The key function runs twice per completion
  (`minuet.el:653-659,1230-1231`). Two small file reads cost nothing.
- Latency: through the gateway, time to first token was 0.30–0.45 s and
  the total 0.66–1.22 s, against the 2.5 s `minuet-request-timeout`
  (research R4). The timeout stays as it is.

<!-- doctrine:section sec-6 -->
## eca: unjailed mode deleted (DEC-008)

Removed from `apps/dl-eca.el`: `dl-eca--launch-settings`, the
`dl-eca-jailed` defcustom, `dl-eca-toggle-jail`, and the comments about
unjailed eca and `op run`. The jailed settings become plain `:custom`
values on the `eca` `use-package`:

```elisp
(eca-custom-command '("jailed-eca" "server"))
(eca-process-wrapper-function #'dl-eca--run-in-first-root)
(eca-send-process-id nil)
```

The commentary is corrected: jailed eca gets its key from the gateway key
file, not from `op run`. `lisp/test/dl-eca-test.el` loses
`toggle-switches-launch-settings` (`:32-48`); the wrapper tests stay.
Emacs needs no `eca` key.

<!-- doctrine:section sec-7 -->
## Removals and docs (DEC-009)

**Removed from `lisp/dl-secret.el`** (after the gate, see Sequencing):
`my/op-key-vault` (`:102`), `my/op-key` (`:110`), `my/op-read-env` (`:92`).
None of them has a test. Also removed: `apps/dl-gptel.el`'s
`dl-gptel-openai-key` (`:62-66`), which has no callers, and its
`(require 'dl-secret)` once no `my/op-key` call remains. `my/op-read`,
`my/op-forget`, `my/op-session-p`, `my/scrub-op-refs-env` and the
env-file sourcing all stay. satan and `org-gcal` use them.
`my/satan-credential` was removed by satan:SL-022 (cf9d419, its DEC-042).

**Kept as they are:** the `env.zsh` LLM exports. satan (satan:SL-022) and
`~/flakes/agents/jailed-agents.nix` still read them. Follow-up below.

**Docs:**
- `docs/emacs/secrets.md`:
  - a new "LLM gateway keys" section: the reader, the per-client files,
    the `llm-gateway issue` / `budget` / `models` commands, and a link to
    the flakes rotation procedure;
  - the gptel example is rewritten to use the gateway;
  - the API table drops `my/op-read-env` and adds the gateway reader;
  - the env-var flow is kept, described as serving satan and org-gcal;
  - the exposure is noted: *Copy Curl command* puts the key on the
    kill-ring and so the system clipboard, and debug logging writes it to
    `*gptel-log*`.
- `AGENTS.md:112`: the one-liner mentions gateway keys.
- `apps/dl-gptel.el:3-10` commentary: three gateway backends plus OAuth.
  The `curl --config -` and no-`:curl-args` warning stays.
- `apps/dl-agent-shell.el:30`: the commented example no longer names
  `my/op-key`.
- `CHANGELOG.md`: name the `@deep`, `@glm`, `@gem` and `@nemo` presets,
  the gptel backends, minuet, and the removal of `dl-eca-toggle-jail`.

<!-- doctrine:section sec-8 -->
## Code impact

| path | change |
|---|---|
| `lisp/dl-llm-gateway.el` | new: URL, key directory, `dl-llm-gateway-key` |
| `lisp/test/dl-llm-gateway-test.el` | new |
| `init.el` | `(require 'dl-llm-gateway)` beside `dl-secret` (`:96`) |
| `apps/dl-gptel.el` | gateway backends; gptel-openrouter and dead code removed |
| `apps/dl-gptel-shape.el` | `dl-gptel-deepseek-thinking` and its `deepseek` entry |
| `apps/dl-gptel-presets.el` | preset backends, models and descriptions |
| `lisp/test/dl-gptel-presets-test.el` | stand-ins and the deepseek `@quick` / `@think` tests |
| `apps/dl-minuet.el` | gateway endpoint, key and model |
| `apps/dl-eca.el`, `lisp/test/dl-eca-test.el` | unjailed mode removed |
| `lisp/dl-secret.el` | `my/op-key`, `my/op-key-vault`, `my/op-read-env` removed |
| `lisp/test/dl-secret-test.el` | `my/op-read` tests (its coverage went with cf9d419) |
| `custom-vars.el` | gptel-openrouter `package-vc` entry removed |
| `apps/dl-agent-shell.el` | comment |
| `docs/emacs/secrets.md`, `AGENTS.md`, `CHANGELOG.md` | docs |

The new `.el` files must be `git add`ed before `home-manager switch`, because
flake builds only see tracked files (AGENTS.md). No package is added. One
package goes: gptel-openrouter is a `package-vc` install in `elpa/`, not in
`emacs.nix`.

<!-- doctrine:section sec-9 -->
## Sequencing and verification (inq-11)

```
flakes:SL-014  PH-03 guard ─ PH-04 models verb ─ PH-05 live (OpenRouter, Fireworks)
                                                        │
SL-015  [A] now ─────────── gate G1 ──────────── [B] after PH-05 ─── gate G2 ── close
        module, minuet,     live DeepSeek via     openrouter + fireworks
        gptel deepseek,     the gptel and minuet  backends, presets, op-key
        shaper, @deep,      keys                  removal, docs
        eca deletion
```

**[A] now.** This works against today's gateway, which serves
`deepseek-flash` only. In [A], the `openrouter` and `fireworks` backends
and their presets keep `my/op-key` and their direct hosts. The `@deep`
preset moves, and so does the shaper entry for `deepseek`, which must
exist before `@deep` + `@think` reaches native DeepSeek.

**Keys (DEC-010), issued by the user before G1** (needs sudo):

```sh
llm-gateway issue gptel  --models deepseek-flash --budget 20 \
  --out ~/.config/llm-gateway/keys/gptel
llm-gateway issue minuet --models deepseek-flash --budget 5 \
  --out ~/.config/llm-gateway/keys/minuet
```

Budgets are lifetime USD per key; `llm-gateway budget` tops one up.

**G1 (VH: checked by the user).** With both keys issued:
- a gptel `@deep` chat completes plain, with `@quick` and with `@think`;
  the `@quick` reply carries no reasoning and the `@think` reply does
  (plain `@deep` gets DeepSeek's default, either way);
- a minuet completion appears in a buffer;
- the gateway ledger (`llm-gateway list`) shows spend on the `gptel` and
  `minuet` aliases.

**[B] after flakes:SL-014 PHASE-05.** Widen the `gptel` key.
`llm-gateway models` replaces the key's whole allowed list, so the command
names `deepseek-flash` as well as every `openrouter/` and `fireworks/` name
in sec-4's backend table, as one comma-separated argument. It refuses a
name missing from the model list baked into the CLI at build time:

```sh
llm-gateway models gptel deepseek-flash,openrouter/openrouter/auto,openrouter/openrouter/free,openrouter/openrouter/pareto-code,openrouter/qwen/qwen3.8-flash,openrouter/z-ai/glm-5.3-flash,openrouter/~z-ai/glm-flash-latest,openrouter/~z-ai/glm-latest,openrouter/google/gemini-3.8-flash,openrouter/google/gemini-3-flash-preview,openrouter/xiaomi/mimo-v2.6-pro,openrouter/xiaomi/mimo-v2.6-flash,fireworks/nemotron-lightning-3p5-30b-a3b
``` Move those backends and
presets to the gateway, delete `my/op-key`, `my/op-key-vault` and
`my/op-read-env`, and update the docs.

**G2 (VH).** For each preset (`@glm`, `@gem`, `@nemo`), one chat completes
through the gateway. Every model in gptel's lists is checked against
both sides:
- the key: `llm-gateway list` shows the `gptel` key allowing each name;
- the running service: its `/v1/models` lists each name. The key goes in
  a header read from a file descriptor, never in argv:

  ```sh
  curl -sf -H @<(printf 'Authorization: Bearer %s' "$(< ~/.config/llm-gateway/keys/gptel)") \
    http://127.0.0.1:4000/v1/models | jq -r '.data[].id' | sort
  ```

A miss at runtime shows only as a 403 `gptel: model '<name>' not
allowed`, which does not list the alternatives.

**VT (checked by ert, under `just check`):**
- `dl-llm-gateway-key` returns the trimmed contents of
  `<dir>/<client>`;
- it signals a `user-error` naming the client and `llm-gateway issue` when
  the file is missing, unreadable (mode 000) or empty;
- a stub `op` on `PATH` that records any call is never called;
- the request body for `@deep` + `@think` has `:reasoning_effort "high"`,
  and for `@deep` + `@quick` `:reasoning_effort "none"`, neither with
  `:reasoning`; the fireworks and openrouter tests still pass;
- `@deep` selects backend `deepseek`, model `deepseek-flash`;
- the eca wrapper tests pass, and the toggle test is gone.

**VA (checked by the agent), at close:**
- removed code is gone: `rg -g '*.el' -g '!elpa/**'
  'my/op-key|my/op-read-env|dl-eca--launch-settings|dl-eca-jailed|dl-eca-toggle-jail|"op" "run"|op run'`
  matches nothing (the last two catch both the list form at
  `apps/dl-eca.el:41` and the commentary);
- the search is live (positive control): the same `rg` run before the
  removals matches `lisp/dl-secret.el` and `apps/dl-eca.el`;
- retained consumers still work: `my/op-read` (with its own tests) and
  the env-file sourcing are still defined in `lisp/dl-secret.el`, and
  `org/dl-org-gcal.el` loads in a full-init batch smoke (`just check`
  does not load it).


