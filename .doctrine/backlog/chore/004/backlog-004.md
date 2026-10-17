# CHR-004: Retire env.zsh LLM *_API_KEY exports and their Emacs env-file sourcing once satan:SL-022 lands

<!-- Backlog item body — context, detail, links. The structured, queried fields
     live in the sister `backlog-NNN.toml`; this prose is free-form and is never
     structurally parsed (the storage rule). -->

SL-015 DEC-009 deferred this. `~/.config/zsh/env.zsh:39-45` exports seven
`*_API_KEY=op://…` refs, and `lisp/dl-secret.el:185-221` sources them into
Emacs' `process-environment`. After SL-015, no gptel or minuet code reads
them. Remaining readers: satan (broker, pi adapter, `spawn-confined.sh`;
moving under satan:SL-022) and `~/flakes/agents/jailed-agents.nix`. Mistral,
Voyage, Gemini and Anthropic refs are to be deleted outright (user,
2026-10-17). `env.zsh` is sourced by flakes `features/terminal/zsh.nix`.
