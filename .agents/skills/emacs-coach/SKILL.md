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

State is three denote notes. Denote renames files when the title or
tags change, so find each one by its identifier (`fd <ID> ~/notes`):

| ID                | Note               | Holds                                        |
|-------------------|--------------------|----------------------------------------------|
| `20261008T094800` | emacs-fluency      | profile, priorities, try-next queue          |
| `20261008T094801` | emacs-skill-map    | capabilities, each with a level + evidence   |
| `20261008T094802` | emacs-learning-log | dated append-only log                        |

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
   - recent config changes (`git -C ~/.emacs.d log --oneline -20`, top of
     `CHANGELOG.md`): new bindings are candidates.
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
   - the hub's priority order.

   For each: what it does, when to reach for it, command name and live
   key, one line on why it's worth it.
5. **Record**, before the session ends:
   - append to the log under today's heading: `TIL` / `FRICTION` /
     `TRIED` / `LEVEL` / `SETUP`, one line each;
   - change a level only on evidence (the user said so, or you saw them
     use it); set `:EVIDENCE: [date] what`;
   - add a capability heading (a task, not a key) when you find one
     worth tracking;
   - keep the hub's try-next queue to five open items or fewer; close
     done ones and drop stale ones.

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
