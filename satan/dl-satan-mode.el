;;; dl-satan-mode.el --- SATAN mode registry -*- lexical-binding: t; -*-

;; A mode-spec is a plist (see SATAN.local.md §"Mode Contract").  Built-in
;; modes register themselves at load time.

(require 'cl-lib)
(require 'dl-notes-paths)

(defvar dl-satan-modes nil
  "Alist of (NAME . SPEC) mode registrations.")

(defun dl-satan-mode-register (spec)
  "Register or replace mode SPEC keyed by `:name'."
  (let ((name (plist-get spec :name)))
    (setq dl-satan-modes
          (cons (cons name spec)
                (cl-remove name dl-satan-modes :key #'car :test #'equal)))))

(defun dl-satan-mode-resolve (name)
  "Return the mode-spec named NAME, or signal if unknown."
  (or (cdr (assoc name dl-satan-modes))
      (error "Unknown SATAN mode: %s" name)))

(defun dl-satan-mode-names ()
  (mapcar #'car dl-satan-modes))

(defvar dl-satan-prompts-dir
  (expand-file-name "satan/prompts/" dl-notes-root)
  "Directory holding mode prompt files.
Canonical model-facing text lives under `~/notes/satan/prompts/'.
Dotfiles must not be the source of truth for prompt content.")

(dl-satan-mode-register
 (list :name "morning"
       :prompt-file (expand-file-name "morning.txt" dl-satan-prompts-dir)
       :context-fn 'dl-satan-context-morning
       :tools '("org_read_context" "org_update_owned_block"
                "proposal_stage" "notify_send" "hippocampus_write"
                "inbox_append" "agenda_read")
       :capabilities '(write-daily stage-proposal notify hippocampus-write
                       inbox-write)
       :harness '(:cmd "jailed-satan-gptel-harness" :args () :env nil)
       :jail-profile 'specDev
       :provider 'openrouter
       :model "anthropic/claude-haiku-4.5"
       :budget-tokens 20000
       :output-handler 'dl-satan-output/morning
       :auto-apply 'owned
       :timeout-seconds 90
       :budget-tool-calls 8))

(dl-satan-mode-register
 (list :name "motd"
       :prompt-file (expand-file-name "motd.txt" dl-satan-prompts-dir)
       :context-fn 'dl-satan-context-motd
       :tools '("org_read_context" "notify_send" "inbox_append" "agenda_read")
       :capabilities '(notify inbox-write)
       :harness '(:cmd "jailed-satan-gptel-harness" :args () :env nil)
       :jail-profile 'specDev
       :provider 'openrouter
       :model "anthropic/claude-haiku-4.5"
       :budget-tokens 10000
       :output-handler 'dl-satan-output/motd
       :auto-apply 'owned
       :timeout-seconds 45
       :budget-tool-calls 4))

(dl-satan-mode-register
 (list :name "self-edit-mech"
       :prompt-file (expand-file-name "self-edit-mech.txt" dl-satan-prompts-dir)
       :context-fn 'dl-satan-context-self-edit
       :source-roots-var 'dl-satan-self-edit-mech-roots
       :tools '("proposal_stage")
       :capabilities '(stage-proposal)
       :harness '(:cmd "jailed-satan-gptel-harness" :args () :env nil)
       :jail-profile 'specDev
       :provider 'openrouter
       :model "anthropic/claude-haiku-4.5"
       :budget-tokens 50000
       :output-handler 'dl-satan-output/self-edit
       :auto-apply 'none
       :timeout-seconds 180
       :budget-tool-calls 20))

(dl-satan-mode-register
 (list :name "self-edit-mind"
       :prompt-file (expand-file-name "self-edit-mind.txt" dl-satan-prompts-dir)
       :context-fn 'dl-satan-context-self-edit
       :source-roots-var 'dl-satan-self-edit-mind-roots
       :tools '("proposal_stage")
       :capabilities '(stage-proposal)
       :harness '(:cmd "jailed-satan-gptel-harness" :args () :env nil)
       :jail-profile 'specDev
       :provider 'openrouter
       :model "anthropic/claude-haiku-4.5"
       :budget-tokens 50000
       :output-handler 'dl-satan-output/self-edit
       :auto-apply 'none
       :timeout-seconds 180
       :budget-tool-calls 20))

(provide 'dl-satan-mode)
;;; dl-satan-mode.el ends here
