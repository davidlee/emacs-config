;;; dl-eca.el --- ECA coding agents -*- lexical-binding: t; -*-

;; https://github.com/editor-code-assistant/eca-emacs
;; TODO keybindings

;; The server runs sandboxed as `jailed-eca' (bubblewrap, via `op run' for
;; API keys) or unjailed as `eca'; both are the pinned llm-agents build from
;; ~/flakes/modules/home/linux/eca.nix.  `dl-eca-toggle-jail' switches.
;;
;; Jailed: the jail binds its cwd, so start it from the first workspace root;
;; roots added later are not visible to it.  The jail has its own pid
;; namespace, so Emacs' pid is invisible to the server's parent-liveness
;; probe (it would exit at once); bwrap's --die-with-parent covers orphan
;; cleanup instead.
;;
;; Unjailed, `op run' resolves the op:// key refs in Emacs' environment.

(defvar eca-custom-command)
(defvar eca-process-wrapper-function)
(defvar eca-send-process-id)

(defun dl-eca--run-in-first-root (command roots)
  "Return COMMAND prefixed to run from the first of ROOTS.
Without ROOTS, run from `default-directory'.  Signal `user-error' if
that directory contains ~: the jail binds it read-write, which would
expose all of home."
  (let ((root (or (car roots) default-directory)))
    (when (file-in-directory-p "~" root)
      (user-error "Refusing to jail eca with %s as workspace; start it from a project"
                  root))
    (when (cdr roots)
      (display-warning 'eca (format "jailed-eca binds only %s" root)))
    (append (list "env" "-C" (expand-file-name root)) command)))

(defun dl-eca--launch-settings (jailed)
  "Return the eca launch settings for JAILED, as (VARIABLE . VALUE) pairs."
  (if jailed
      '((eca-custom-command . ("jailed-eca" "server"))
        (eca-process-wrapper-function . dl-eca--run-in-first-root)
        (eca-send-process-id . nil))
    '((eca-custom-command . ("op" "run" "--" "eca" "server"))
      (eca-process-wrapper-function . nil)
      (eca-send-process-id . t))))

(defcustom dl-eca-jailed t
  "Whether new eca servers run sandboxed as `jailed-eca'."
  :type 'boolean
  :group 'eca
  :set (lambda (symbol jailed)
         (set-default symbol jailed)
         (pcase-dolist (`(,variable . ,value) (dl-eca--launch-settings jailed))
           (set-default variable value))))

(defun dl-eca-toggle-jail ()
  "Toggle `dl-eca-jailed'.  Applies to the next server start."
  (interactive)
  (customize-set-variable 'dl-eca-jailed (not dl-eca-jailed))
  (message "eca: next server runs %s" (if dl-eca-jailed "jailed" "UNJAILED")))

(use-package eca
  :ensure t
  :defer t
  :vc (:url "https://github.com/editor-code-assistant/eca-emacs" :rev :newest))

(provide 'dl-eca)
;;; dl-eca.el ends here
