The codex MCP server is often down; the CLI works. Shape:

    codex exec -m gpt-6-sol -s read-only --ephemeral -C <repo> \
      --add-dir ~/flakes -o <out.md> - < <prompt.md>

- Prompt from a file on stdin; final message lands in `-o`. Run in background for full reviews (minutes); verify rounds fit a foreground call with a timeout.
- `-s read-only` forbids local sockets: Codex cannot probe the live LLM gateway (127.0.0.1:4000). Claims needing a live service stay runtime checks (VH), not review verdicts.
- Codex is the RV raiser: record its verdicts on the ledger as raiser (contest / verify / raise), dispose as responder, and send revisions back for a verify round. Adjudicate each claim on the artefact first (/feedback) — it gets severity and rule provenance wrong (e.g. treated a rule from our own prompt as project policy).


See also [[mem.pattern.doctrine.codex-external-review]] — the MCP route, where Codex has write access and records its own verdicts.
