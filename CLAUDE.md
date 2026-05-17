@AGENTS.md

when searching:
- use rg | fd, not find | grep
- don't search / or ~/
- ~/flakes/ has the nixOS and home-manager configuration
- ./elpa/ has packaged installs - hidden by .gitignore so use eg fd -I

keep exploration bounded:
- before exploring: define stopping conditions, positive and negative

provide the user with choices, exposing important tradeoffs.

don't assume. ask questions to clarify. perform bounded exploration where necessary to frame the right questions.

when implementation is successful / committed, update CHANGELOG.md with concise notes.

note: CHANGELOG.md is large, sip it.
