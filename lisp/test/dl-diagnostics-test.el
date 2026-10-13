;;; dl-diagnostics-test.el --- ert tests for dl-diagnostics -*- lexical-binding: t; -*-

;; Run: `just check' (dl-test scans lisp/test), or M-x ert RET dl-diagnostics RET.

;;; Commentary:

;; Flymake is the single diagnostics frontend; flycheck contributes
;; checkers through flymake-flycheck; flyover draws them inline.
;; Fixtures here never run a real checker process: flymake starts no
;; check on enable, and the flycheck checker is a fake.

;;; Code:

(require 'ert)
(require 'dl-diagnostics)
(require 'flycheck)
(require 'flymake-flycheck)
(require 'flyover)

(declare-function nix-mode "nix-mode")

(define-derived-mode dl-diagnostics-test-mode prog-mode "DiagTest")

(flycheck-define-generic-checker 'dl-diagnostics-test-checker
  "A checker that never runs; it only has to be usable."
  :start (lambda (_checker callback) (funcall callback 'finished nil))
  :modes '(dl-diagnostics-test-mode))

(defun dl-diagnostics-test--fake-lsp (_report-fn &rest _)
  "Stand-in for `eglot-flymake-backend'.")

(defmacro dl-diagnostics-test--visiting (mode &rest body)
  "Run BODY in MODE, in a buffer visiting a fresh temp file.
The fake checker leads `flycheck-checkers'; the file is trusted, as
config files are; no check starts on enable."
  (declare (indent 1))
  `(let* ((flymake-start-on-flymake-mode nil)
          (flycheck-checkers (cons 'dl-diagnostics-test-checker
                                   flycheck-checkers))
          (trusted-content :all)
          (file (make-temp-file "dl-diagnostics-test"))
          (buf (find-file-noselect file)))
     (unwind-protect
         (with-current-buffer buf
           (funcall #',mode)
           ,@body)
       (kill-buffer buf)
       (delete-file file))))

(defun dl-diagnostics-test--backends ()
  "This buffer's local Flymake backends, without the global marker t."
  (remq t flymake-diagnostic-functions))

(ert-deftest dl-diagnostics/prog-modes-get-flycheck-checkers ()
  "A programming buffer runs Flymake with flycheck's usable checkers."
  (dl-diagnostics-test--visiting dl-diagnostics-test-mode
    (should flymake-mode)
    (should (memq (flymake-flycheck-diagnostic-function-for
                   'dl-diagnostics-test-checker)
                  (dl-diagnostics-test--backends)))))

(ert-deftest dl-diagnostics/flycheck-checkers-survive-eglot ()
  "Eglot replaces the backend list, then re-enables `flymake-mode'.
The flycheck checkers come back alongside the LSP backend."
  (dl-diagnostics-test--visiting dl-diagnostics-test-mode
    ;; Mirrors `eglot--managed-mode': set the list, then `flymake-mode' 1.
    (setq-local flymake-diagnostic-functions '(dl-diagnostics-test--fake-lsp))
    (flymake-mode 1)
    (should (equal (dl-diagnostics-test--backends)
                   (list #'dl-diagnostics-test--fake-lsp
                         (flymake-flycheck-diagnostic-function-for
                          'dl-diagnostics-test-checker))))))

(ert-deftest dl-diagnostics/builtin-backends-not-duplicated ()
  "Where Emacs ships a Flymake backend, flycheck's twin stays out."
  (dolist (case '((emacs-lisp-mode emacs-lisp emacs-lisp-checkdoc)
                  (sh-mode sh-shellcheck)))
    (dl-diagnostics-test--visiting (lambda () (funcall (car case)))
      (should flymake-mode)
      (dolist (checker (cdr case))
        (should-not (memq (flymake-flycheck-diagnostic-function-for checker)
                          flymake-diagnostic-functions))))))

(ert-deftest dl-diagnostics/nix-parse-errors-left-to-nixd ()
  "nixd (eglot) reports Nix parse errors and unused bindings.
flycheck's `nix' parse check stays out; statix, which nixd lacks, runs."
  (skip-unless (and (executable-find "nix-instantiate")
                    (executable-find "statix")))
  (require 'nix-mode)
  (dl-diagnostics-test--visiting nix-mode
    (should-not (memq (flymake-flycheck-diagnostic-function-for 'nix)
                      (dl-diagnostics-test--backends)))
    (should (memq (flymake-flycheck-diagnostic-function-for 'statix)
                  (dl-diagnostics-test--backends)))))

(ert-deftest dl-diagnostics/buffers-without-files-stay-unchecked ()
  "Hidden buffers put into a programming mode get no Flymake.
Org fontifies source blocks this way, in buffers nobody edits."
  (let ((flymake-start-on-flymake-mode nil))
    (with-temp-buffer
      (dl-diagnostics-test-mode)
      (should-not flymake-mode))))

(ert-deftest dl-diagnostics/flyover-draws-flymake-diagnostics ()
  "flyover rides along with Flymake and reads only Flymake."
  (dl-diagnostics-test--visiting dl-diagnostics-test-mode
    (should flyover-mode)
    (should (equal flyover-checkers '(flymake)))))

(ert-deftest dl-diagnostics/report-runs-update-hook-in-its-buffer ()
  "A Flymake report runs the reporting buffer's update hook.
flyover listens there; disabling it in another buffer must not
silence this one."
  (dl-diagnostics-test--visiting dl-diagnostics-test-mode
    (let ((ran nil))
      (dl-diagnostics-test--visiting dl-diagnostics-test-mode
        (flyover-mode -1))
      (should (memq #'flyover--maybe-display-errors-debounced
                    flymake-after-update-diagnostics-hook))
      (add-hook 'flymake-after-update-diagnostics-hook
                (lambda () (setq ran (current-buffer))) nil t)
      (setq-local flymake-diagnostic-functions
                  (list (lambda (report-fn &rest _) (funcall report-fn nil))))
      (flymake-start nil t)
      (should (eq ran (current-buffer))))))

(ert-deftest dl-diagnostics/toggle-inline-style-round-trips ()
  "The toggle swaps flyover for Flymake's `fancy' display, and back."
  (dl-diagnostics-test--visiting dl-diagnostics-test-mode
    (my/diagnostics-toggle-inline-style)
    (should-not flyover-mode)
    (should (eq flymake-inline-diagnostics 'fancy))
    (my/diagnostics-toggle-inline-style)
    (should flyover-mode)
    (should-not flymake-inline-diagnostics)))

(provide 'dl-diagnostics-test)
;;; dl-diagnostics-test.el ends here
