# Implementation Plan SL-017: umbriel buffer scratchpad sections and pad toggle

Prose companion to `plan.toml`. Narrative only — no queried data lives here
(the storage rule); the phase list, criteria, verification, and links are
authored in the TOML. Use this for the plan's rationale and sequencing.
<!-- Reference forms: `lib:reference/glossary.md` § reference forms. -->

## Overview

Two phases: pads appear in the buffer, then the buffer can toggle them.

## Sequencing & Rationale

Sections come first because the toggle needs the `umbriel-scratchpad` section as a target, and the sections are useful alone. Refusal on a pad heading sits with the toggle, since both change `dl-umbriel-buffer--plan`.

## Notes

Existing test `dl-umbriel-model-group/keeps-every-window` has a `w-2` scratch fixture with an empty `scratchpad`, so it stays in the nil group. Buffer fixture `w-scratch` likewise. Pad cases get new fixtures.
