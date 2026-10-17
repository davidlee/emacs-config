;;; dl-llm-gateway-test.el --- ert tests for dl-llm-gateway -*- lexical-binding: t; -*-

;; Run: `just check' (dl-test scans lisp/test), or M-x ert RET dl-llm-gateway RET.
;;
;; Key files live in a temp directory bound to
;; `dl-llm-gateway-key-directory'.  A stub `op' on `exec-path'/`PATH'
;; logs its argv, so tests can prove the reader never shells out.

(require 'ert)
(require 'dl-llm-gateway)

(defmacro dl-llm-gateway-test--with-keys (log-var &rest body)
  "Run BODY with a temp key directory and a logging stub `op' on PATH.
LOG-VAR is bound to a function returning the stub's logged argv lines,
or nil when the stub was never invoked."
  (declare (indent 1))
  `(let* ((root (make-temp-file "dl-llm-gateway-test-" t))
          (dl-llm-gateway-key-directory (expand-file-name "keys" root))
          (bindir (expand-file-name "bin" root))
          (log-file (expand-file-name "argv" root))
          (exec-path (list bindir))
          (process-environment (cons (concat "PATH=" bindir) process-environment))
          (,log-var (lambda ()
                      (when (file-exists-p log-file)
                        (split-string
                         (with-temp-buffer (insert-file-contents log-file)
                                           (buffer-string))
                         "\n" t)))))
     (unwind-protect
         (progn
           (make-directory dl-llm-gateway-key-directory t)
           (make-directory bindir t)
           (let ((stub (expand-file-name "op" bindir)))
             (with-temp-file stub
               (insert "#!/bin/sh\n"
                       (format "echo \"$*\" >> %s\n" (shell-quote-argument log-file))))
             (set-file-modes stub #o755))
           ,@body)
       ;; Restore modes so cleanup can't fail on a 000 file.
       (dolist (f (directory-files dl-llm-gateway-key-directory t "\\`[^.]"))
         (set-file-modes f #o600))
       (delete-directory root t))))

(defun dl-llm-gateway-test--write (client contents &optional mode)
  "Write CONTENTS to CLIENT's key file, then set MODE if given."
  (let ((file (expand-file-name client dl-llm-gateway-key-directory)))
    (with-temp-file file (insert contents))
    (when mode (set-file-modes file mode))))

(defun dl-llm-gateway-test--error-message (client)
  "Return the `user-error' message from reading CLIENT's key."
  (cadr (should-error (dl-llm-gateway-key client) :type 'user-error)))

(defun dl-llm-gateway-test--should-name-client-and-command (client)
  "Assert reading CLIENT's key fails with a message naming it and the command."
  (let ((msg (dl-llm-gateway-test--error-message client)))
    (should (string-match-p (regexp-quote client) msg))
    (should (string-match-p "llm-gateway issue" msg))))

;;; VT-1 — read, trim, no cache.

(ert-deftest dl-llm-gateway-key-returns-trimmed-contents ()
  (dl-llm-gateway-test--with-keys _log
    (dl-llm-gateway-test--write "gptel" "sk-abc\n")
    (should (equal (dl-llm-gateway-key "gptel") "sk-abc"))))

(ert-deftest dl-llm-gateway-key-sees-rewritten-file ()
  (dl-llm-gateway-test--with-keys _log
    (dl-llm-gateway-test--write "gptel" "sk-abc\n")
    (should (equal (dl-llm-gateway-key "gptel") "sk-abc"))
    (dl-llm-gateway-test--write "gptel" "sk-def\n")
    (should (equal (dl-llm-gateway-key "gptel") "sk-def"))))

(ert-deftest dl-llm-gateway-key-expands-tilde-directory ()
  (dl-llm-gateway-test--with-keys _log
    (dl-llm-gateway-test--write "minuet" "sk-m\n")
    (let ((dl-llm-gateway-key-directory
           (abbreviate-file-name dl-llm-gateway-key-directory)))
      (should (equal (dl-llm-gateway-key "minuet") "sk-m")))))

;;; VT-2 — failure modes signal a `user-error' naming client and command.

(ert-deftest dl-llm-gateway-key-missing-file-errors ()
  (dl-llm-gateway-test--with-keys _log
    (dl-llm-gateway-test--should-name-client-and-command "gptel")))

(ert-deftest dl-llm-gateway-key-unreadable-file-errors ()
  (skip-unless (not (zerop (user-uid))))
  (dl-llm-gateway-test--with-keys _log
    (dl-llm-gateway-test--write "gptel" "sk-abc\n" #o000)
    (dl-llm-gateway-test--should-name-client-and-command "gptel")))

(ert-deftest dl-llm-gateway-key-empty-file-errors ()
  (dl-llm-gateway-test--with-keys _log
    (dl-llm-gateway-test--write "gptel" "")
    (dl-llm-gateway-test--should-name-client-and-command "gptel")))

(ert-deftest dl-llm-gateway-key-whitespace-only-file-errors ()
  (dl-llm-gateway-test--with-keys _log
    (dl-llm-gateway-test--write "gptel" "\n")
    (dl-llm-gateway-test--should-name-client-and-command "gptel")))

(ert-deftest dl-llm-gateway-key-error-message-shape ()
  (dl-llm-gateway-test--with-keys _log
    (let ((msg (dl-llm-gateway-test--error-message "gptel")))
      (should (string-match-p "--models … --budget … --out " msg))
      (should (string-match-p "\\`No LLM gateway key for gptel at " msg)))))

;;; VT-3 — never shells out to `op'.

(ert-deftest dl-llm-gateway-test-stub-op-is-live ()
  "Positive control: the stub logs when actually called."
  (dl-llm-gateway-test--with-keys log
    (should (zerop (call-process "op" nil nil nil "probe")))
    (should (equal (funcall log) '("probe")))))

(ert-deftest dl-llm-gateway-key-never-calls-op ()
  (dl-llm-gateway-test--with-keys log
    (dl-llm-gateway-test--write "gptel" "sk-abc\n")
    (dl-llm-gateway-key "gptel")
    (ignore-errors (dl-llm-gateway-key "minuet")) ; missing -> error path
    (should-not (funcall log))))

(ert-deftest dl-llm-gateway-key-error-paths-never-call-op ()
  (dl-llm-gateway-test--with-keys log
    (dl-llm-gateway-test--write "empty" "\n")
    (ignore-errors (dl-llm-gateway-key "missing"))
    (ignore-errors (dl-llm-gateway-key "empty"))
    (should-not (funcall log))))

;;; Static dependency check (EX-1) — source-level.

(ert-deftest dl-llm-gateway-source-has-no-client-or-process-dependencies ()
  (let ((src (with-temp-buffer
               (insert-file-contents (locate-library "dl-llm-gateway.el"))
               (buffer-string))))
    (dolist (forbidden '("(require 'dl-secret" "(require 'gptel"
                         "(require 'minuet" "(require 'plz" "setenv"
                         "call-process" "make-process" "\"op\""))
      (should-not (string-search forbidden src)))))

(provide 'dl-llm-gateway-test)
;;; dl-llm-gateway-test.el ends here
