;;; dl-gnus-test.el --- ert tests for gnus + fastmail -*- lexical-binding: t; -*-

;; Run: `just check' (dl-test scans lisp/test), or M-x ert RET dl-gnus RET.

(require 'ert)
(require 'dl-gnus)
(require 'gnus-sum)
(require 'gnus-msg)

(ert-deftest dl-gnus/archive-moves-to-archive-folder ()
  "Archiving moves the articles to Fastmail's Archive folder.
The prefix passes through, so process marks and counts still apply."
  (let (moved)
    (cl-letf (((symbol-function 'gnus-summary-move-article)
               (lambda (&rest args) (setq moved args))))
      (my/gnus-summary-archive 3))
    (should (equal moved '(3 "nnimap+fastmail:Archive")))))

(ert-deftest dl-gnus/archive-key-in-summary ()
  "`y' archives from the summary buffer, as in Gmail."
  (should (eq (keymap-lookup gnus-summary-mode-map "y")
              #'my/gnus-summary-archive)))

(ert-deftest dl-gnus/sent-mail-kept-on-server ()
  "Sent mail is copied to Fastmail's Sent folder, already read."
  (should (equal gnus-message-archive-group "nnimap+fastmail:Sent"))
  (should gnus-gcc-mark-as-read))

(provide 'dl-gnus-test)
;;; dl-gnus-test.el ends here
