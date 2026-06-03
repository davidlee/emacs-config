;; satan/patterns.eld — curated SATAN pattern definitions
;;
;; Each entry defines a recurring cue-shape (conjunctive set of handle strings)
;; that the outcome observer attributes interventions to.  The projection
;; (satan_pattern_outcomes) is rebuilt at each observer tick; editing a pattern's
;; cue_handles retroactively re-attributes its history.  Convention: a meaningful
;; cue change should use a new :id rather than mutating an existing one (§4.2).
;;
;; `:enabled' gates future live action (out of scope for DE-009 v1) — it does
;; NOT gate historical attribution, so a retired pattern retains its scars.
;;
;; `:intrusion_ceiling' is recorded but not enforced in v1 (DR-009 DEC-5, R2).
;;
;; Grammar: each cue_handle must be a `namespace:value' string where namespace
;; is a known grammar namespace and value is admissible for that namespace
;; (closed-world enum or open-world non-empty slug).  Typo'd handles are
;; rejected at sync time.

((:id "docs-after-error"
  :label "Documentation browsing after a config error"
  :cue_handles ("event_transition:command_error->browser"
                "domain_kind:docs"
                "artifact:none")
  :default_intervention "ask_extract"
  :intrusion_ceiling "inbox"
  :priority 5
  :enabled t
  :notes "User hits a command error, then opens browser documentation — likely solving a problem.  Low-friction ask-extract is appropriate.")

 (:id "terminal-coding"
  :label "Active terminal coding session"
  :cue_handles ("surface:terminal"
                "event:command_ok"
                "artifact:none")
  :default_intervention nil
  :intrusion_ceiling "visible_sign"
  :priority 3
  :enabled t
  :notes "User is actively running commands in the terminal and they're succeeding — deep flow state.  High ceiling: avoid interrupting unless genuinely urgent.")

 (:id "editor-commit"
  :label "Editing led to a commit"
  :cue_handles ("surface:editor"
                "artifact:commit"
                "surface_transition:editor->browser")
  :default_intervention nil
  :intrusion_ceiling "inbox"
  :priority 4
  :enabled t
  :notes "User edited code, committed, then switched to browser — completed a work unit.  Good moment for a low-key inbox entry."))
