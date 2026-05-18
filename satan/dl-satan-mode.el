;;; dl-satan-mode.el --- SATAN mode registry -*- lexical-binding: t; -*-

;; A mode-spec is a plist (see SATAN.local.md §"Mode Contract").  Built-in
;; modes register themselves at load time.

(require 'cl-lib)

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
  (expand-file-name "satan/prompts/" user-emacs-directory)
  "Directory holding mode prompt files.")

(dl-satan-mode-register
 (list :name "morning"
       :prompt-file (expand-file-name "morning.txt" dl-satan-prompts-dir)
       :context-fn 'dl-satan-context-morning
       :tools '("org.read_context" "org.update_owned_block"
                "proposal.stage" "notify.send" "memory.add_candidate")
       :capabilities '(write-daily stage-proposal notify memory-candidate)
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
       :tools '("org.read_context" "org.update_owned_block" "notify.send")
       :capabilities '(write-motd notify)
       :harness '(:cmd "jailed-satan-gptel-harness" :args () :env nil)
       :jail-profile 'specDev
       :provider 'openrouter
       :model "anthropic/claude-haiku-4.5"
       :budget-tokens 5000
       :output-handler 'dl-satan-output/motd
       :auto-apply 'owned
       :timeout-seconds 45
       :budget-tool-calls 4))

(dl-satan-mode-register
 (list :name "self-edit"
       :prompt-file (expand-file-name "self-edit.txt" dl-satan-prompts-dir)
       :context-fn 'dl-satan-context-self-edit
       :tools '("proposal.stage")
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
