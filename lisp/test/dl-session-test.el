;;; dl-session-test.el --- ert tests for dl-session -*- lexical-binding: t; -*-

;; Run: `just check' (dl-test scans lisp/test), or M-x ert RET dl-session RET.

(require 'ert)
(require 'cl-lib)
(require 'dl-session)

(defun dl-session-test--save-conflicting (daemon)
  "Call `desktop-save' over a desktop file this Emacs did not load.
DAEMON stubs `daemonp'; the batch frame is the initial frame.  Return
whether `desktop-save' asked a question."
  (let* ((dir (make-temp-file "dl-session-test-" t))
         (desktop-file-modtime nil)
         (desktop-dirname nil)
         asked)
    (unwind-protect
        (progn
          (with-temp-file (expand-file-name desktop-base-file-name dir)
            (insert ";; another Emacs's desktop\n"))
          (cl-letf (((symbol-function 'daemonp) (lambda () daemon))
                    ((symbol-function 'yes-or-no-p)
                     (lambda (&rest _) (setq asked t) nil)))
            (ignore-errors (desktop-save dir)))
          asked)
      (setq desktop-dirname nil)
      (delete-directory dir t))))

(ert-deftest dl-session/frameless-daemon-never-prompts ()
  "A daemon with no frame skips the save rather than ask.
Its question would go to the initial terminal, whose stdin is
/dev/null: nothing answers, and the daemon hangs."
  (should-not (dl-session-test--save-conflicting t)))

(ert-deftest dl-session/frame-keeps-conflict-prompt ()
  "With a frame to answer in, a conflicting save still asks."
  (should (dl-session-test--save-conflicting nil)))

(ert-deftest dl-session/agenda-files-not-saved ()
  "Agenda files stay out of the desktop: org-agenda reopens them anyway."
  (require 'org)
  (let ((org-agenda-files '("/tmp/dl-session-agenda.org")))
    (should-not (desktop-save-buffer-p
                 "/tmp/dl-session-agenda.org" "dl-session-agenda.org" 'org-mode))
    (should (desktop-save-buffer-p
             "/tmp/dl-session-other.org" "dl-session-other.org" 'org-mode))))

(provide 'dl-session-test)
;;; dl-session-test.el ends here
