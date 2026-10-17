Never hand-edit design.md under a run. To change a section:

1. Extract the section's current body from design.md (text after its `<!-- doctrine:section sec-N -->` marker, heading included).
2. `doctrine design apply <SLICE> --input payload.json` with `{"run_uid", "known_revision", "submission_id", "declare": [{"subject": "sec-N", "body": "<full new body>"}]}` — body replaces the whole section.
3. `doctrine design materialise <SLICE>`; `git diff design.md` to confirm.

Each edit stales that section's attestation; materialise bumps the revision, so read the new `known_revision` before the next apply. Script the extract-replace (assert each old snippet occurs once) rather than retyping sections.
