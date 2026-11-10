# ISS-022: dl-gptel-mcp org-tools test times out in the full suite, passes alone

<!-- Backlog item body — context, detail, links. The structured, queried fields
     live in the sister `backlog-NNN.toml`; this prose is free-form and is never
     structurally parsed (the storage rule). -->

## Symptom

`dl-gptel-mcp/org-tools-reach-gptel-and-writes-confirm` (test/dl-gptel-mcp-test.el:74)
fails under `just check`: after ~70 s, `(error "No tool matches for (\"mcp-org-mcp\"
\"org-read-outline\")")`, followed by `[jsonrpc] Sentinel for org-mcp still hasn't run`.
Run alone (`-l test/dl-gptel-mcp-test.el -f ert-run-tests-batch-and-exit`) it passes in ~4 s.
Reproduced 3/3 in the full suite on 2026-11-11, at 103/594.

## Evidence vs inference

- Evidence: order-dependent; the org-mcp server never registers tools in the full suite.
  Seen alongside a Nix system upgrade (machine under load) and the ISS-021 `dl-dirs` change.
- Inference (unverified): an earlier test leaves global state (process-environment,
  `server-name`/socket, an envrc async direnv run — "direnv continuing async" appears just
  before the failure) that breaks the stdio script's emacsclient call; or plain load.

## Next

Re-run `just check` on an idle machine; if it still fails, bisect the suite order.
Tolerated in the CHR-014 commit by the user.
