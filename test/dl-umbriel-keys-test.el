;;; dl-umbriel-keys-test.el --- ert tests for the umbriel keys and integration -*- lexical-binding: t; -*-

;; Run: `just check' (dl-test scans test/), or M-x ert RET dl-umbriel-keys RET.
;;
;; The umbriel client itself (~/dev/umbriel.el) is tested by its own
;; `just check'; this suite covers the config side: the keys this repo binds,
;; and `desktop/dl-umbriel.el', the integration file that loads the package.

(require 'ert)
(require 'seq)
(require 'subr-x)

;; The checkout may be absent (a host without ~/dev/umbriel.el): then the
;; package-facing tests below skip and the config-side ones still run.
(require 'umbriel-buffer nil t)
(require 'umbriel-focus nil t)

(require 'meow)
(require 'dl-keymap)
(require 'dl-meow-map)
(meow-setup)

;;; keys

(defconst dl-umbriel-keys-test--global-keys
  '(("u" . umbriel)
    ("w" . umbriel-switch-workspace)
    ("l" . umbriel-set-active-layout))
  "The `my-umbriel-map' bindings (DEC-024).")

(ert-deftest dl-umbriel-keys/global-map-binds-the-three-commands ()
  "`my-umbriel-map' carries u/w/l, not f, and sits on C-c u.
A frame that runs a key already has focus, so f had nothing to do."
  (pcase-dolist (`(,key . ,command) dl-umbriel-keys-test--global-keys)
    (should (eq (keymap-lookup my-umbriel-map key) command)))
  (should-not (keymap-lookup my-umbriel-map "f"))
  (should (eq (keymap-lookup global-map "C-c u") my-umbriel-map)))

(ert-deftest dl-umbriel-keys/leader-mirrors-the-global-map ()
  "`meow-setup' puts `my-umbriel-map' on the leader, SPC u.
The leader map is empty of `u' first, so the binding seen is meow-setup's."
  (let ((meow-keymap-alist (copy-alist meow-keymap-alist)))
    (setf (alist-get 'leader meow-keymap-alist)
          (copy-keymap (alist-get 'leader meow-keymap-alist)))
    (keymap-unset (alist-get 'leader meow-keymap-alist) "u" t)
    (should-not (keymap-lookup (alist-get 'leader meow-keymap-alist) "u"))
    (meow-setup)
    (should (eq (keymap-lookup (alist-get 'leader meow-keymap-alist) "u")
                my-umbriel-map))))

(ert-deftest dl-umbriel-keys/row-keys-are-not-shadowed-by-motion-state ()
  "No row key is bound in the config's meow motion-state map."
  (skip-unless (locate-library "umbriel-buffer"))
  (dolist (key '("RET" "s" "m" "t" "c" "k" "L" "M-<left>" "<" "M-<right>"
                 ">" "e" "E" "g" "q"))
    (should-not (keymap-lookup meow-motion-state-keymap key)))
  ;; Each of those keys is in fact a row key.
  (should (keymap-lookup umbriel-buffer-mode-map "RET")))

(ert-deftest dl-umbriel-keys/buffer-mode-starts-in-motion-state ()
  "meow guesses motion state for `umbriel-buffer-mode'."
  (skip-unless (locate-library "umbriel-buffer"))
  (should (eq (alist-get 'umbriel-buffer-mode meow-mode-state-list
                         (with-temp-buffer
                           (umbriel-buffer-mode)
                           (meow--mode-guess-state)))
              'motion)))

;;; fresh-Emacs helper

(defun dl-umbriel-keys-test--fresh-emacs (load-path-dirs form)
  "Run the Elisp text FORM in a fresh batch Emacs with LOAD-PATH-DIRS.
Return (cons EXIT-STATUS OUTPUT-STRING); stdout and stderr both land in
the output.  `LD_LIBRARY_PATH' is scrubbed from the child's environment:
a dev-shell value breaks every subprocess (AGENTS.md trap 6)."
  (let* ((expr (concat "(progn"
                       " (setq load-prefer-newer t load-path '"
                       (prin1-to-string load-path-dirs) ")"
                       ;; Not a `let': `--eval' is lexically bound, so only a
                       ;; global defvar reaches `bound-and-true-p' in
                       ;; core/dl-checkout.el, whose guard then writes no .elc.
                       " (defvar byte-compile-current-file"
                       " \"dl-umbriel-keys-test\")"
                       " " form ")"))
         (process-environment
          (seq-remove (lambda (variable)
                        (string-prefix-p "LD_LIBRARY_PATH=" variable))
                      process-environment)))
    (with-temp-buffer
      (let ((status (call-process "timeout" nil t nil "60"
                                  (expand-file-name invocation-name
                                                    invocation-directory)
                                  "--batch" "-Q" "--eval" expr)))
        (cons status (buffer-string))))))

;;; load order

(defun dl-umbriel-keys-test--resolve-form (features)
  "Elisp text that requires FEATURES in order and princs the C-c u keys."
  (concat "(dolist (feature '" (prin1-to-string features) ")"
          " (require feature))"
          " (dolist (key '(\"u\" \"w\" \"l\"))"
          "   (let ((cmd (keymap-lookup global-map"
          " (concat \"C-c u \" key))))"
          "     (princ (format \"%s %S %s\\n\" key cmd (commandp cmd))))))"))

(ert-deftest dl-umbriel-keys/keys-resolve-in-either-load-order ()
  "C-c u u/w/l resolve and are commands whichever loads first."
  (skip-unless (locate-library "umbriel-buffer"))
  (skip-unless (file-executable-p (expand-file-name invocation-name
                                                    invocation-directory)))
  (skip-unless (executable-find "timeout"))
  (let ((expected (concat "u umbriel t\n"
                          "w umbriel-switch-workspace t\n"
                          "l umbriel-set-active-layout t\n")))
    (dolist (order '((dl-keymap umbriel-buffer umbriel-focus)
                     (umbriel-buffer umbriel-focus dl-keymap)))
      (let ((result (dl-umbriel-keys-test--fresh-emacs
                     load-path (dl-umbriel-keys-test--resolve-form order))))
        (should (equal 0 (car result)))
        (should (equal expected (cdr result)))))))

;;; integration (desktop/dl-umbriel.el)

(ert-deftest dl-umbriel-keys/integration-loads-the-package-in-a-fresh-emacs ()
  "A fresh Emacs requires `dl-umbriel' and gets the package and its commands.
The checkout's own compile guard must write no .elc while doing it."
  (skip-unless (locate-library "umbriel-buffer"))
  (let* ((dir (file-name-directory (locate-library "umbriel-buffer")))
         (elcs (lambda () (directory-files dir nil "\\.elc\\'")))
         (before (funcall elcs))
         (result (dl-umbriel-keys-test--fresh-emacs
                  load-path
                  (concat "(require 'dl-umbriel)"
                          " (princ (list (featurep 'umbriel-buffer)"
                          " (commandp 'umbriel)))"))))
    (should (equal 0 (car result)))
    (should (string-suffix-p "(t t)" (cdr result)))
    (should (equal before (funcall elcs)))))

(ert-deftest dl-umbriel-keys/integration-warns-and-skips-without-the-checkout ()
  "Without the checkout on the load path, `dl-umbriel' warns and loads.
The warning is the integration file's own guard; use-package alone would
only print its generic \"Cannot load\" message, so it is the negative control."
  (let* ((load-path
          (seq-remove (lambda (dir)
                        (file-exists-p (expand-file-name "umbriel-buffer.el"
                                                         dir)))
                      load-path))
         (result (dl-umbriel-keys-test--fresh-emacs
                  load-path
                  (concat "(require 'dl-umbriel)"
                          " (princ (featurep 'umbriel-buffer))"))))
    (should (equal 0 (car result)))
    (should (string-match-p "umbriel checkout not on load-path" (cdr result)))
    (should (string-suffix-p "nil" (cdr result)))))

(provide 'dl-umbriel-keys-test)
;;; dl-umbriel-keys-test.el ends here
