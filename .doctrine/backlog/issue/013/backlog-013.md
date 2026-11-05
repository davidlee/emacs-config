# ISS-013: zmx: reject a new dotted identifier at the prompt

<!-- Backlog item body — context, detail, links. The structured, queried fields
     live in the sister `backlog-NNN.toml`; this prose is free-form and is never
     structurally parsed (the storage rule). -->

`my/zmx-project` with a new identifier holding a dot, such as `v0.1`, composes
`doctrine.v0.1`. The zmux wrapper refuses a name with more than one dot (exit 2),
confirmed against the wrapper. `dl-zmx--label-safe` keeps dots in an identifier on
purpose, so an existing dotted session stays reachable.

## Why the refusal is not good enough

`apps/dl-zmx.el`'s header says the refusal lands in the buffer. Inferred, not yet
observed: `ghostel-kill-buffer-on-exit` defaults to `t` and the attach exits at once,
so the buffer probably closes before the message can be read. Confirm this first.

## Fix

- Reject at the prompt with a `user-error` giving the reason, when the identifier
  holds a dot and that session is not running. Don't fold it to `_`: the identifier
  was typed, so tell the user rather than rewrite it.
- A running dotted session stays reachable through `my/zmx-project`. `my/zmx-switch`
  needs no change.
- The same failure applies to `my/zmx-new` at `/`, where the directory name is empty
  and the name is `.1`. Give it the same treatment.
- Correct the header's claim, and the matching line in zmux IMP-002.

Test first, in `lisp/test/dl-zmx-test.el`.

## Done

Confirmed first, against the real wrapper and ghostel in a scratch `ZMX_DIR`: the buffer
closes about 0.2s after the attach, and the message is lost. zmux EVD-005 has the probe.

`dl-zmx-creatable-name-p` mirrors the wrapper's rule, and `dl-zmx--check-reachable`
refuses a name that fails it unless the session is running. `my/zmx-project` and
`my/zmx-new` both call it, so `my/zmx-new-at-root` and `my/zmx-resume` inherit it. The
header and zmux IMP-002 are corrected.

The rule now lives in two places, the wrapper and this predicate. The wrapper stays the
authority; the predicate only moves the refusal to where it can be read.
