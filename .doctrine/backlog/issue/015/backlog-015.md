# ISS-015: umbriel stream drops with connection broken by remote peer

<!-- Backlog item body — context, detail, links. The structured, queried fields
     live in the sister `backlog-NNN.toml`; this prose is free-form and is never
     structurally parsed (the storage rule). -->

The `*umbriel*` status line shows `umbriel: closed — connection broken by remote
peer (retry; g in *umbriel* reconnects)`.

Cause unknown. It may be a real fault in the stream, or a side effect of reloading
umbriel code into the live Emacs during IMP-030.

## Evidence

- 2026-11-07: seen at least three times across two IMP-030 sessions. In the second
  session the message was already showing at 11:40, before any code was reloaded
  in that session, and again at 11:46 after reloads.

Add each further sighting here, with the time and what was happening.
