# IMP-026: ERT coverage for gptel backend construction in apps/dl-gptel.el

<!-- Backlog item body — context, detail, links. The structured, queried fields
     live in the sister `backlog-NNN.toml`; this prose is free-form and is never
     structurally parsed (the storage rule). -->

No ERT test loads `apps/dl-gptel.el`, so backend construction (the gateway
`:host`/`:endpoint` split in `dl-gptel--gateway`, model lists) is checked only
by a full-init batch smoke and live use. SL-015 PHASE-02 hit the risk directly:
`url-host` drops the port (mem.fact.gptel.host-needs-port), and only the smoke
run would have caught a wrong `:host`. Option: move the pure URL→backend-plist
helper somewhere `lisp/test` can load, and pin `127.0.0.1:4000` + `/v1/chat/completions`.
Source: SL-015 PHASE-02 orchestrator hand-back.
