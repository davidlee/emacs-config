;;; dl-policy-lint.el --- Lint personal `C-c <letter>' grammar -*- lexical-binding: t; -*-

;; Enforces the `C-c <letter>' Policy codified in `KEYS.md'.
;;
;; Walks `mode-specific-map' (the global `C-c' prefix) and reports any
;; single-letter binding whose value is neither one of the `my-*-map'
;; family maps nor an explicitly reserved singleton
;; (`C-c a' org-agenda, `C-c c' org-capture, `C-c l' org-store-link).
;;
;; - M-x `my-policy-lint'    pops `*Policy Lint*'.
;; - On startup, a silent scan runs from `emacs-startup-hook'; it logs
;;   to *Messages* iff violations are found, never opens a buffer.
;;
;; `my/bind' already prints an override warning when two personal
;; bindings fight for the same key, but it can't see foreign packages
;; that grab `C-c <letter>' from their `:config' (the symptom this
;; module exists to surface — `ready-player' / `rg.el' clobbered
;; `C-c m' / `C-c s' before this lint existed).

(require 'cl-lib)

(defconst my-policy-lint-family-maps
  '(my-file-map my-buffer-map my-window-map my-search-map my-project-map
     my-jump-map my-git-map my-notes-map my-org-map my-toggle-map
     my-eval-map my-term-map my-fold-map)
  "Variables whose value is a permitted top-level `C-c <letter>' prefix map.
Keep in sync with the prefix declarations in `core/dl-keymap.el'.")

(defconst my-policy-lint-reserved-singletons
  '((?a . org-agenda)
     (?c . org-capture)
     (?l . org-store-link))
  "Per `KEYS.md' Policy clause 6: single-letter `C-c <letter>' commands
allowed to bind directly to a command instead of a `my-*-map' family.")

(defun my-policy-lint--family-map-symbol (value)
  "Return the `my-*-map' symbol whose `symbol-value' is VALUE, or nil."
  (cl-find-if (lambda (sym)
                (and (boundp sym) (eq (symbol-value sym) value)))
    my-policy-lint-family-maps))

(defun my-policy-lint--letter-p (event)
  (and (characterp event)
    (or (and (>= event ?a) (<= event ?z))
      (and (>= event ?A) (<= event ?Z)))))

(defun my-policy-lint-scan ()
  "Return Policy violations as a list of plists.
Each entry: (:key STRING :binding BINDING :reason SYMBOL).
Reason is `foreign-map' (a keymap not in the family allowlist) or
`foreign-command' (a non-prefix command outside the reserved set)."
  (let (violations)
    (map-keymap
      (lambda (event binding)
        (when (my-policy-lint--letter-p event)
          (let ((key (format "C-c %c" event)))
            (cond
              ((keymapp binding)
                (unless (my-policy-lint--family-map-symbol binding)
                  (push (list :key key :binding binding :reason 'foreign-map)
                    violations)))
              ((or (symbolp binding) (functionp binding))
                (let ((reserved (alist-get event my-policy-lint-reserved-singletons)))
                  (unless (eq binding reserved)
                    (push (list :key key :binding binding :reason 'foreign-command)
                      violations))))
              (t
                (push (list :key key :binding binding :reason 'foreign-command)
                  violations))))))
      mode-specific-map)
    (nreverse violations)))

(defun my-policy-lint--format-binding (binding)
  (cond
    ((keymapp binding)
      (let ((prompt (keymap-prompt binding)))
        (format "<keymap%s>" (if prompt (format " %S" prompt) ""))))
    ((symbolp binding) (symbol-name binding))
    (t (format "%S" binding))))

;;;###autoload
(defun my-policy-lint ()
  "Report Policy violations under `C-c <letter>'.
Pops `*Policy Lint*' when there are violations; otherwise echoes
\"clean\".  Returns the violation list."
  (interactive)
  (let ((violations (my-policy-lint-scan)))
    (cond
      ((null violations)
        (message "my-policy-lint: clean (no `C-c <letter>' Policy violations)."))
      (t
        (with-current-buffer (get-buffer-create "*Policy Lint*")
          (let ((inhibit-read-only t))
            (erase-buffer)
            (insert "Policy violations under `C-c <letter>'\n")
            (insert "=======================================\n\n")
            (dolist (v violations)
              (insert (format "  %-10s  %s  (%s)\n"
                        (plist-get v :key)
                        (my-policy-lint--format-binding (plist-get v :binding))
                        (plist-get v :reason))))
            (insert "\nSee KEYS.md `Policy'.  Lift offending bindings into\n"
              "`core/dl-keymap.el' under the appropriate `my-*-map' family,\n"
              "or disable the foreign package's global key install.\n")
            (goto-char (point-min)))
          (display-buffer (current-buffer)))
        (message "my-policy-lint: %d Policy violation(s) — see *Policy Lint*."
          (length violations))))
    violations))

(defun my-policy-lint--startup-check ()
  "Silent startup scan: log a one-line summary iff violations exist."
  (let ((violations (my-policy-lint-scan)))
    (when violations
      (message "my-policy-lint: %d Policy violation(s) under `C-c <letter>' — M-x my-policy-lint."
        (length violations)))))

(add-hook 'emacs-startup-hook #'my-policy-lint--startup-check)

(provide 'dl-policy-lint)
;;; dl-policy-lint.el ends here
