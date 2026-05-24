---
name: resilience-design
description: Design foundations for structured error reporting and progressive rate-limit degradation
metadata:
  type: design-note
  topic: broker/resilience
  status: draft
  updated_at: 2026-05-24
---

# Resilience — error reporting + progressive degradation

Two related problems: (1) crashes discard diagnostic context, and (2)
rate limits cause hard termination when graceful degradation would let
the run salvage value.

---

## 1. Structured error reporting before termination

### 1.1 Current state

The broker has five terminal status paths:

| Status | Trigger | Diagnostic capture |
|---|---|---|
| `done` | `satan_final` tool call | full: transcript + final.json + actions.json |
| `failed` | harness sends `error` msg | transcript up to error + stderr.log |
| `timed-out` | timeout timer fires | transcript up to kill + stderr.log |
| `invalid-protocol` | protocol validation fail | transcript with protocol-error event |
| `budget-exceeded` | daily gate denial | synthetic audit bundle (no child spawned) |

**Problem.** On `failed` and `timed-out`, the broker kills the child
process and writes whatever partial transcript exists, but does NOT
capture:

- **Harness-side state**: message count, token subtotals, tool call
  history, which turn was in flight.
- **Provider error detail**: the raw exception (rate limit 429 vs
  auth failure vs server error) is flattened to a generic string in
  `emit_error(f"provider call failed: {e}")` (runloop.py:112).
- **Broker-side context**: which observers/sensors ran, what the
  attribute snapshot was, which pre-spawn actions completed.
- **Run-ctx diagnostic snapshot**: the `dl-satan-run` struct has
  `:tool-calls-done`, `:status`, `:final` — none of this is persisted
  on crash paths.

### 1.2 Proposed: crash context event

On every non-`done` terminal path, the broker emits a
`broker/crash-context` event to the transcript before calling
`dl-satan-audit-close`. This is a structured snapshot of the run's
state at the moment of failure:

```json
{
  "ts": "<ISO8601>",
  "dir": "broker",
  "event": "crash-context",
  "payload": {
    "status": "failed|timed-out|invalid-protocol",
    "tool_calls_done": 7,
    "tool_calls_budget": 15,
    "tokens_total": 82341,
    "tokens_budget": 100000,
    "elapsed_seconds": 47.2,
    "timeout_seconds": 120,
    "last_tool_call": "hippocampus_read",
    "error_class": "rate_limit|auth|server|timeout|protocol|unknown",
    "error_detail": "<raw exception string>",
    "attributes_snapshot": {"shame": 0.5, "doubt": 0.5, ...},
    "observers_ran": ["sensor-alerts", "panopticon"],
    "pre_spawn_completed": true
  }
}
```

**Placement.** `dl-satan-broker--finalize` (broker.el:389), before
`dl-satan-audit-close`. One `dl-satan-audit-record` call with the
snapshot plist. Pure data assembly — no new I/O.

### 1.3 Proposed: harness-side error classification

runloop.py:111-112 catches all provider exceptions generically.
Classify before emitting:

```python
except Exception as e:
    error_class = classify_error(e)
    emit_error(json.dumps({
        "class": error_class,
        "detail": str(e),
        "tokens_total": state.tokens_total,
        "messages_count": len(state.messages),
        "turn": state.turn_count,
    }))
    return 1
```

Classification heuristic (provider-agnostic):

```python
def classify_error(e: Exception) -> str:
    msg = str(e).lower()
    if "rate" in msg or "429" in msg or "quota" in msg:
        return "rate_limit"
    if "auth" in msg or "401" in msg or "403" in msg:
        return "auth"
    if "500" in msg or "502" in msg or "503" in msg:
        return "server"
    if "timeout" in msg or "timed out" in msg:
        return "timeout"
    return "unknown"
```

This classification feeds both error reporting AND the progressive
degradation system (§2).

### 1.4 Tank integration

The tank's LAST RUN section already shows status + error_msg. Extend
it to parse the `crash-context` event and show a compact diagnostic
block when the last run is non-`done`:

```
LAST RUN
────────
20260524T151938-tick-agent-55f9b8
mode: tick-agent  ·  status: failed  ·  dur: 12.3s
tokens: 42000/100000  ·  tcalls: 3/15
error: rate_limit — 429 Too Many Requests
last tool: hippocampus_read
attributes: shame=0.50 doubt=0.50
```

---

## 2. Progressive rate-limit degradation

### 2.1 Current state

Rate limits cause `emit_error` → harness exit 1 → broker marks
`.FAILED` → run is dead. No retry, no backoff, no degradation. The
run's partial work (tool calls already completed, memory writes
already persisted) is abandoned — the model never gets to call
`satan_final` to summarise what it learned.

Token budget enforcement is similarly binary: soft-warn at threshold,
then force-final on next turn. No intermediate behaviour.

### 2.2 Proposed: three-tier tool degradation

When the harness detects a rate limit (or approaches token budget),
progressively restrict tool availability rather than terminating. Each
tier reduces the available tool set; the model receives a system
message explaining the restriction and is expected to wind down
gracefully.

**Tier 0 — normal.** Full tool set per mode spec. No restrictions.

**Tier 1 — conserve.** Triggered by: rate limit retry succeeded after
backoff, OR token usage crosses 70% of budget.

- Drop high-context tools: `docs_search`, `docs_read`, `docs_list`,
  `activity_read`, `notes_recent`, `hippocampus_grep`.
- Keep: all read/write tools for notes, memory, bough. All action
  tools (notify, inbox, motive, patch).
- System message: "Context budget pressure. Survey tools withdrawn.
  Focused reads and writes remain. Begin winding down."

**Tier 2 — wind-down.** Triggered by: second rate limit hit, OR token
usage crosses 85% of budget.

- Drop external reads: `org_read_context`, `bough_read`,
  `agenda_read`, `hippocampus_list`, `hippocampus_read`.
- Keep: memory writes (`memory_mark`, `hippocampus_write`,
  `hippocampus_overwrite`), `inbox_append`, `notify_send`,
  `satan_final`.
- System message: "Context nearly exhausted. External reads withdrawn.
  Save findings to memory, then call satan_final."

**Tier 3 — final-only.** Triggered by: third rate limit hit, OR token
usage crosses 95% of budget, OR 85% of timeout elapsed.

- Only tool: `satan_final`.
- System message: "Context exhausted. Call satan_final now with your
  findings."
- If model still doesn't finalise on next turn: force synthetic final
  (current behaviour, but now only as last resort after 3 chances).

### 2.3 Rate limit retry with backoff

Before degrading, the harness should retry on rate limit errors:

```python
RETRY_DELAYS = [2, 5, 15]  # seconds

for attempt, delay in enumerate(RETRY_DELAYS):
    try:
        comp = provider.complete(state.messages, tools, model)
        break
    except RateLimitError:
        if attempt == len(RETRY_DELAYS) - 1:
            degrade_tier(state)
            # retry once more at reduced tier
            comp = provider.complete(state.messages, reduced_tools, model)
            break
        emit_log({"kind": "rate_limit_retry", "attempt": attempt + 1,
                  "delay": delay})
        time.sleep(delay)
```

Each exhausted retry cycle bumps the tier. The model always gets
another chance at the reduced tool set before the next tier kicks in.

### 2.4 Implementation shape

**Harness side (runloop.py).**

- New `TierState` dataclass tracking current tier + tier-change
  timestamps.
- `degrade_tier()` function: bumps tier, rebuilds tool list by
  filtering the manifest's tools against tier allowlists, emits
  `tier_changed` log event.
- Provider call wrapped in retry-with-backoff.
- Token-budget thresholds checked after each turn (replace current
  single-threshold `warned` boolean with tier progression).

**Broker side (dl-satan-broker.el).**

- Tool-call dispatch (`dl-satan-broker--on-tool-call`) already checks
  tool allowlist per mode. No change needed — the harness controls
  which tools it offers the model, and the broker validates against
  the mode's full list (which is a superset of any tier's list).
- New `tier_changed` log event type accepted by the audit validator.
- Tank LAST RUN section shows tier transitions.

**Mode spec (dl-satan-mode.el).**

- New optional `:tier-toolsets` plist on mode specs. When absent,
  default tier definitions apply. When present, overrides per-mode
  (e.g. tick-agent's full set is already narrow — tier 1 might be
  identical to tier 0).

### 2.5 Backstop termination

Hard termination only on:

- **30 minutes elapsed** (configurable, mode-level `:max-timeout-seconds`).
  Current per-mode `:timeout-seconds` (60-120s) becomes the "expected
  duration" for budgeting, not the kill threshold.
- **1M tokens cumulative** (configurable, mode-level
  `:max-budget-tokens`). Well past any normal run; catches infinite
  loops.
- **5 consecutive rate limit cycles without progress** (no successful
  tool call between retries). Prevents burning wall-clock time
  against a hard quota.

These backstops exist only to prevent infinite runs. Normal
termination is always via `satan_final` — either model-initiated or
forced at tier 3.

### 2.6 Notification integration

- **Tier 1 entry**: no notification (routine pressure, self-corrects).
- **Tier 2 entry**: `tracing::info!` log event. Tank shows yellow
  indicator.
- **Tier 3 entry**: desktop notification via `notify_send` (from
  broker, not model). "SATAN run degraded to final-only."
- **Backstop kill**: existing `announce-failure` path (syslog +
  streak-gated notification).

### 2.7 Audit trail

Every tier transition emits a transcript event:

```json
{
  "ts": "<ISO8601>",
  "dir": "harness",
  "event": "log",
  "payload": {
    "kind": "tier_changed",
    "from_tier": 0,
    "to_tier": 1,
    "trigger": "rate_limit|budget_70|budget_85|budget_95|timeout_85",
    "tokens_total": 72000,
    "elapsed_seconds": 45.2,
    "tools_removed": ["docs_search", "docs_read", "activity_read"],
    "tools_remaining": 12
  }
}
```

---

## 3. Tool tier classification

Reference classification for the default tier toolsets. Modes with
narrow tool lists (tick-pulse, tick-agent) may skip tiers where
their full set is already within the tier's allowlist.

| Tool | Tier 0 | Tier 1 | Tier 2 | Tier 3 |
|---|---|---|---|---|
| `docs_search` | yes | - | - | - |
| `docs_read` | yes | - | - | - |
| `docs_list` | yes | - | - | - |
| `activity_read` | yes | - | - | - |
| `notes_recent` | yes | - | - | - |
| `hippocampus_grep` | yes | - | - | - |
| `org_read_context` | yes | yes | - | - |
| `bough_read` | yes | yes | - | - |
| `agenda_read` | yes | yes | - | - |
| `hippocampus_list` | yes | yes | - | - |
| `hippocampus_read` | yes | yes | - | - |
| `notes_at_satan_scan` | yes | yes | - | - |
| `hippocampus_write` | yes | yes | yes | - |
| `hippocampus_overwrite` | yes | yes | yes | - |
| `hippocampus_delete` | yes | yes | yes | - |
| `hippocampus_rename` | yes | yes | yes | - |
| `memory_mark` | yes | yes | yes | - |
| `memory_resonate` | yes | yes | - | - |
| `memory_show_trace` | yes | yes | - | - |
| `motive_read` | yes | yes | yes | - |
| `motive_replace` | yes | yes | yes | - |
| `inbox_append` | yes | yes | yes | - |
| `notify_send` | yes | yes | yes | - |
| `patch_job_create` | yes | yes | - | - |
| `patch_job_status` | yes | yes | - | - |
| `notes_at_satan_done` | yes | yes | yes | - |
| `notes_at_satan_intervention_done` | yes | yes | yes | - |
| `sway_border_set` | yes | yes | yes | - |
| `sway_border_reset` | yes | yes | yes | - |
| `org_update_owned_block` | yes | yes | yes | - |
| `proposal_stage` | yes | yes | - | - |
| `satan_final` | yes | yes | yes | yes |

**Design principle.** Tier drops go: survey → focused reads →
writes-only → final. At each step the model loses the ability to
gather new context but retains the ability to persist what it already
knows. The most valuable thing a degraded run can do is save its
partial findings to memory before terminating.

---

## 4. Implementation sequence

Suggested order (each is a standalone PR):

1. **Error classification** (harness-side). Classify provider errors
   in runloop.py. Structured error payload in `emit_error`. No broker
   changes.
2. **Crash context event** (broker-side). Emit `crash-context` on
   non-done finalize paths. Tank shows diagnostic block. Tests.
3. **Rate limit retry with backoff** (harness-side). Retry loop in
   runloop.py. `rate_limit_retry` log events. No tier system yet —
   just retry then fail.
4. **Tier degradation** (harness-side). `TierState`, tier toolset
   filtering, system message injection, `tier_changed` log events.
   Broker audit validator accepts new event kind.
5. **Backstop thresholds** (both sides). New mode-spec keys
   `:max-timeout-seconds`, `:max-budget-tokens`. Harness checks;
   broker wires defaults.
6. **Notification + tank** (broker-side). Tier-aware notification.
   Tank shows tier transitions in LAST RUN + RECENT EVENTS.

---

## 5. Open questions

1. **Tier thresholds.** 70/85/95% of budget is a guess. Should these
   be mode-configurable or global? Recommendation: global defaults,
   mode-level override via `:tier-thresholds '(0.70 0.85 0.95)`.
2. **Rate limit vs budget-triggered tiers.** Should they share the
   same tier counter? A run at 60% budget that hits a rate limit
   jumps to tier 1 — is that right, or should rate-limit tiers be
   separate? Recommendation: shared counter. A rate limit is a signal
   the run is consuming too much.
3. **Tick modes.** Tick-pulse has 4 tool calls budget and 60s timeout.
   3-tier degradation is overkill. Auto-collapse to tier 0 → tier 3
   when the mode's full tool count ≤ 6? Recommendation: yes.
4. **`memory_resonate` tier placement.** It's a read that can return
   large context, but it's also how the model connects current
   evidence to stored traces. Currently tier 1 (kept). Should it
   drop at tier 2? Depends on typical response size.
5. **Provider-specific rate limit detection.** The string-matching
   heuristic in §1.3 is fragile. Should providers expose a typed
   `RateLimitError`? The `providers.py` abstraction layer could
   catch provider-specific exceptions and re-raise a unified type.
