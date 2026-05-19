## Technical Requirements Brief: Canonical Handle Memory

### Purpose

This brief accompanies the Satan seed document. It defines the minimum technical requirements for a simple memory substrate based on canonical key/value handles.

The goal is not semantic memory, embedding search, or rich knowledge modelling. The goal is to make past experience cheaply re-encounterable by forcing both stored traces and present situations to emit keys from the same constrained grammar.

Core principle:

```text
Memory is handle collision.
```

A past trace can affect the present only if it was stored with keys that the present can reproduce.

---

# 1. Design Constraint

The memory system must remain dumb.

It should not depend on:

```text
semantic search
LLM-based retrieval
free-text synonym matching
prose scanning
complex ontology construction
```

Instead, it should depend on:

```text
canonical keys
ingestion-time normalization
small closed vocabularies
inverted index lookup
overlap scoring
decay
visible match explanation
```

Free-text prose may be stored as payload, but must not be used as the primary address.

---

# 2. Core Model

Every stored memory trace consists of:

```text
trace_id
timestamp
canonical handles
payload
weight / valence
strength
raw metadata
```

A trace is findable only through its handles.

Example:

```text
trace_id: 20260519T171522-a8f3

handles:
  project:emacs.d
  surface:terminal
  surface:browser
  event:command_error
  transition:terminal->browser
  domain_kind:docs
  artifact:none

payload:
  "After a terminal error, user opened documentation and produced no artifact."

valence:
  negative

strength:
  0.42
```

---

# 3. Required Affordances

The system must provide the following minimal affordances.

## 3.1 Mark

Something happened and left a durable trace.

Requirement:

```text
Every meaningful observation or intervention outcome can create a trace.
```

## 3.2 Address

Every trace receives canonical handles.

Requirement:

```text
No trace may be stored without handles.
```

## 3.3 Cue

The current situation emits handles from the same grammar.

Requirement:

```text
Runtime context must be normalized into the same handle vocabulary used for stored traces.
```

## 3.4 Resonate

Stored traces return by handle overlap.

Requirement:

```text
Retrieval is implemented as inverted-index lookup over canonical handles.
```

## 3.5 Weight

Returned traces carry consequence.

Requirement:

```text
Traces must preserve crude valence or outcome information: helped, failed, intensified, dissolved, unknown.
```

## 3.6 Bias

Returned traces can affect present behaviour.

Requirement:

```text
Retrieved traces must be capable of biasing intervention selection, sign emission, or prompt wording.
```

## 3.7 Fade

Unused or contradicted traces weaken.

Requirement:

```text
Trace strength must decay over time or disuse.
```

## 3.8 Show

The system exposes why something matched.

Requirement:

```text
Any surfaced memory or intervention must be able to show the handles that caused the match.
```

---

# 4. Key Grammar

Keys must use a constrained grammar:

```text
namespace:value
```

Examples:

```text
surface:browser
event:command_error
transition:terminal->browser
artifact:none
project:emacs.d
intervention:ask
outcome:returned_to_editing
```

Keys are addresses, not descriptions.

Do not use keys like:

```text
avoiding work
docs spiral
research rabbit hole
feeling stuck
probably procrastinating
```

Use canonical handles instead:

```text
surface:browser
domain_kind:docs
transition:error->browser
artifact:none
phase:post_failure
```

---

# 5. Namespace Policy

Namespaces must be explicit and limited.

Initial namespaces:

```text
app
surface
project
repo
domain
domain_kind
file_kind
event
transition
artifact
phase
intervention
outcome
topic
```

Each namespace must be classified as either:

```text
closed-world
open-world
```

## 5.1 Closed-world namespaces

Closed-world namespaces have enumerated values. Unknown values are rejected or mapped by alias.

Recommended closed-world namespaces:

```text
surface
event
transition
artifact
phase
intervention
outcome
domain_kind
file_kind
```

Example:

```text
surface:
  browser
  editor
  terminal
  desktop
  chat

artifact:
  none
  file_edit
  commit
  note
  task_closed

outcome:
  unknown
  returned_to_editing
  continued_drift
  produced_artifact
  abandoned_context
```

## 5.2 Open-world namespaces

Open-world namespaces allow arbitrary normalized slugs.

Recommended open-world namespaces:

```text
app
project
repo
domain
topic
file
```

Examples:

```text
app:firefox
project:emacs.d
repo:nix-config
domain:doc.rust-lang.org
topic:rust
```

Open-world values must still be normalized.

---

# 6. Canonicalization

Raw input must never become handles directly.

Required pipeline:

```text
raw observation
→ normalize fields
→ emit canonical handles
→ collapse aliases
→ reject invalid closed-world values
→ store raw detail separately
→ index canonical handles
```

Example:

```text
raw:
  app_id = "firefox"
  url = "https://doc.rust-lang.org/std/iter/trait.Iterator.html"

canonical handles:
  app:firefox
  surface:browser
  domain:doc.rust-lang.org
  domain_kind:docs
  topic:rust
```

The normalizer is the only place where synonym handling should occur.

---

# 7. Alias Handling

Synonyms must be collapsed on write, not searched on read.

Example alias table:

```text
reference -> domain_kind:docs
manual    -> domain_kind:docs
docs      -> domain_kind:docs
tutorial  -> domain_kind:learning
guide     -> domain_kind:learning
```

Requirement:

```text
The memory store must contain only canonical handles.
```

If a new synonym appears, update the alias map or reject it. Do not allow both forms to accumulate.

---

# 8. Prose Is Payload, Not Address

Every trace may include human-readable payload text.

Payload is used for display, explanation, and later inspection.

Payload must not be the primary retrieval mechanism.

Correct:

```text
handles:
  transition:terminal->browser
  event:command_error
  artifact:none

payload:
  "After a failing command, user opened docs and made no edit."
```

Incorrect:

```text
key:
  "opened docs after being stuck"
```

---

# 9. Handle Count Constraint

Each trace should receive a small number of handles.

Requirement:

```text
Each trace should normally contain 5-12 handles.
```

Too few handles prevents useful resonance. Too many handles makes everything match everything.

A handle should only be attached if it is likely to recur.

Rule:

```text
If it will never recur, store it as metadata, not as a handle.
```

Example:

Bad recurring handle:

```text
url:https://doc.rust-lang.org/std/iter/trait.Iterator.html#method.map
```

Better handles:

```text
domain:doc.rust-lang.org
domain_kind:docs
topic:rust
surface:browser
```

---

# 10. Specificity Ladder

The system may store handles at multiple specificity levels.

Example:

```text
surface:browser              broad
app:firefox                  medium
domain_kind:docs             medium
domain:doc.rust-lang.org     specific
url_hash:abc123              exact
```

General recurrence should prefer middle-level handles.

Exact handles are useful for audit and continuity, but should not dominate similarity scoring.

---

# 11. Retrieval

Retrieval is performed by handle overlap.

Given current handles:

```text
project:emacs.d
event:command_error
transition:terminal->browser
domain_kind:docs
artifact:none
```

The system fetches candidate trace IDs from an inverted index:

```text
project:emacs.d              -> [trace1, trace7, trace9]
event:command_error          -> [trace1, trace3]
transition:terminal->browser -> [trace1, trace4]
domain_kind:docs             -> [trace1, trace2, trace8]
artifact:none                -> [trace1, trace5]
```

Candidates are scored by weighted overlap.

Minimal scoring model:

```text
score(trace) =
  sum(handle_weight for shared handles)
  * trace_strength
  * recency_decay
```

Initial handle weights:

```text
project       1
surface       1
app           1
domain_kind   2
event         2
transition    3
artifact      3
phase         2
intervention  2
outcome       3
topic         1
```

These weights should be static initially.

---

# 12. Current Context Handles

At any point, Satan should be able to emit a small current context handle set.

Example:

```text
current:
  project:emacs.d
  surface:terminal
  surface:browser
  event:command_error
  transition:terminal->browser
  domain_kind:docs
```

This current handle set is the query.

Requirement:

```text
The same canonicalizer used for traces must be used for current context.
```

---

# 13. Result Explanation

Any returned trace must be explainable by matched handles.

Example:

```text
Matched prior trace because of:
  project:emacs.d
  event:command_error
  transition:terminal->browser
  domain_kind:docs
```

This is required for the observable habitat.

Satan must be able to say:

```text
This rang because: command error, browser transition, docs surface, no artifact.
```

Not:

```text
This was semantically similar.
```

---

# 14. Mutation Boundary

The grammar may evolve, but only at the boundary.

Allowed changes:

```text
add namespace
add closed-world value
add alias
adjust handle weight
mark handle deprecated
split overbroad value
merge synonymous values
```

Disallowed behaviour:

```text
allowing arbitrary free-text keys
using generated prose as handles
silently inventing new closed-world values
retrieving by synonym scan
requiring embeddings for basic recurrence
```

---

# 15. Minimal Storage Shape

A simple implementation may use JSONL plus indexes.

Trace JSONL:

```json
{
  "id": "20260519T171522-a8f3",
  "ts": "2026-05-19T17:15:22+10:00",
  "handles": [
    "project:emacs.d",
    "surface:terminal",
    "surface:browser",
    "event:command_error",
    "transition:terminal->browser",
    "domain_kind:docs",
    "artifact:none"
  ],
  "payload": "After a terminal error, user opened documentation and produced no artifact.",
  "valence": "negative",
  "strength": 0.42,
  "metadata": {
    "app_before": "ghostty",
    "app_after": "firefox",
    "domain": "doc.rust-lang.org"
  }
}
```

Inverted index:

```json
{
  "transition:terminal->browser": [
    "20260519T171522-a8f3"
  ],
  "domain_kind:docs": [
    "20260519T171522-a8f3"
  ],
  "artifact:none": [
    "20260519T171522-a8f3"
  ]
}
```

This can later be moved to SQLite/Postgres without changing the conceptual model.

---

# 16. Acceptance Criteria

A first implementation is acceptable when it can:

```text
1. Convert raw observations into canonical handles.
2. Reject or alias non-canonical closed-world values.
3. Store traces with 5-12 handles.
4. Build an inverted index from handles to trace IDs.
5. Emit current context handles.
6. Retrieve past traces by handle overlap.
7. Score matches by weighted overlap, strength, and decay.
8. Show the exact handles responsible for a match.
9. Store prose as payload, not as address.
10. Update the grammar deliberately rather than letting keys drift.
```

---

# 17. Non-Goals

The first version should not attempt:

```text
semantic search
LLM-generated memory summaries as primary keys
embedding similarity
automatic ontology induction
complex behavioural taxonomies
full agent planning
rich psychological modelling
```

Those may be layered later. They are not the memory substrate.

---

# 18. Compact Principle

```text
No free-text keys.
Normalize on write.
Query by canonical handles.
Collapse synonyms before storage.
Reject invalid closed-world values.
Store prose as payload.
Explain matches by shared handles.
```

Or, more brutally:

```text
Marks need addresses.
Moments need addresses.
Memory is address collision.
```
