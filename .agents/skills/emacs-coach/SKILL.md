---
name: emacs-coach
description: Use when the user wants to get more fluent in Emacs — asks "how do I…", what to learn or try next, what they know, or wants to log something they learned or found awkward. Reads and updates their private learning notes in ~/notes; suggests a few things tied to their current work.
---

# Emacs coach

Help the user get fluent in Emacs from their real work, across many
sessions and agents. This is not a course: no practice for its own
sake, no unprompted quizzes.

## Public procedure, private state

This skill lives in `~/.emacs.d`, a **public** repo. It holds only the
procedure. Everything about the user — profile, levels, logs, drills,
anything they learned or found hard — lives in `~/notes` (private).
Never write learner state into `~/.emacs.d`, and never copy it into
commits, changelogs or backlog items there.

State is a small graph of denote notes. Denote renames files when the
title or tags change, so find a note by its identifier
(`fd <ID> ~/notes`). Three fixed notes:

| ID                | Note               | Holds                                        |
|-------------------|--------------------|----------------------------------------------|
| `20261008T094800` | emacs-fluency      | profile, priorities, try-next queue          |
| `20261008T094801` | emacs-skill-map    | generated index of the nodes; their format   |
| `20261008T094802` | emacs-learning-log | dated append-only log                        |

Every capability, workflow and concept is its own slip in
`~/notes/slips`, tagged `emacs` plus a kind (`capability` / `workflow`
/ `concept`) and an area. A capability's level is its `:LEVEL:`
property; read levels with `rg ':LEVEL:' ~/notes/slips`. The skill
map's preamble defines the tags, properties and levels. It is the
format's single source; read it before writing a node.

Meow modal editing has its own track (the hub links its brief and
drill note). Don't duplicate it.

## Procedure

1. **Orient.** Read the hub and the skill map, and the log's last two
   weeks.
2. **Gather evidence** (only what the moment needs):
   - what the user is doing right now: the best evidence there is;
   - `~/.emacs.d/var/prescient-save.el`: recent `M-x` picks. A command
     reached through `M-x` is one the user has no key for in muscle
     memory;
   - FRICTION entries in the log;
   - config changes since the hub's `CONFIG_SEEN` commit
     (`git -C ~/.emacs.d log --oneline <sha>..HEAD`, matching
     `CHANGELOG.md` entries). See *Config loop*.
3. **Resolve keys live.** Keys in this config change often, so never
   quote a key from memory or from an old note. Ask the running Emacs,
   in the user's current buffer so mode and meow maps apply:

   ```sh
   emacsclient --eval '(with-current-buffer (window-buffer (selected-window))
     (mapcar (lambda (c) (cons c (mapconcat (quote key-description)
                                            (where-is-internal c) ", ")))
             (quote (xref-find-definitions consult-ripgrep))))'
   ```

   An empty string means no key reaches the command there. That is
   worth reporting. If `emacsclient` fails, give command names and say
   the keys are unverified.
4. **Suggest at most three things.** Prefer, in order:
   - something that fits the task in hand;
   - the next step above a capability already at USING;
   - the hub's priority order;
   - a `whythough` capability (one the user can do but doesn't reach
     for), when the moment matches its trigger.

   For each: what it does, when to reach for it, command name and live
   key, one line on why it's worth it. For a `whythough` node, lead
   with the situation that should trigger it; if the node lacks a
   trigger, work one out with the user and write it into the node.
   When a capability only pays off inside a workflow, suggest the
   workflow and name the missing or broken piece.
5. **Record**, before the session ends:
   - append to the log under today's heading: `TIL` / `FRICTION` /
     `TRIED` / `LEVEL` / `SETUP`, one line each;
   - change a level only on evidence (the user said so, or you saw them
     use it); set the node's `:LEVEL:` and `:EVIDENCE: [date] what`;
   - add a node when you find one worth tracking: a capability (a
     task, not a key), a workflow (a loop that links its capabilities)
     or a concept. Create it with `denote` so the name and front matter
     are canonical, then refresh the skill map's dynamic blocks
     (`org-update-all-dblocks`);
   - workflow membership lives only in the workflow note; never copy
     it into the capability;
   - keep the hub's try-next queue to five open items or fewer; close
     done ones and drop stale ones;
   - a node under active study goes in the org-iw queue `LEARN-EMACS`
     and comes out once it's settled.
     Use `org-iw-add` / `org-iw-add-files` / `org-iw-remove`; never
     hand-write `IW_<QUEUE>` ranks. org-iw is the user's own
     review-queue package; don't add another SRS.

   Queue layout: the hub sits in both the general `LEARN` queue (the way
   in from general review) and `LEARN-EMACS`; the meow drills sit in
   `LEARN-EMACS`.

## Config loop

Learning and configuring feed each other. Both directions are part of
every visit.

- **Inbound (config → learning).** Read what changed since the hub's
  `CONFIG_SEEN`. For each user-facing change: add or edit the
  capabilities it touches (renamed commands, moved keys, new packages),
  and offer anything worth trying as a try-next item. Then set
  `CONFIG_SEEN` to the current `HEAD`.
- **Outbound (learning → config).** Friction that needs a code change,
  or a package worth trying, becomes a `.emacs.d` backlog item (see
  Boundaries). A stated preference becomes a line in the hub's profile.

## Boundaries

- Config friction that needs a code change goes to the `.emacs.d`
  backlog (`doctrine backlog new`), described in config terms only. The
  learning log records that it was filed.
- Build drills only when asked. Follow the meow-drills format: Do /
  Want / Answer, answers checked in batch Emacs, fluency at three clean
  runs.
- Elisp: offer to walk through a small command when it's the fastest
  fix. Respect it when the user would rather delegate.
- Be terse. Name commands; introduce unfamiliar packages in one line.
