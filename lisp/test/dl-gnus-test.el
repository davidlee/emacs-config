;;; dl-gnus-test.el --- ert tests for gnus + fastmail -*- lexical-binding: t; -*-

;; Run: `just check' (dl-test scans lisp/test), or M-x ert RET dl-gnus RET.

(require 'ert)
(require 'meow)
(require 'dl-keymap)
(require 'dl-gnus)

(meow-setup)
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

(ert-deftest dl-gnus/summary-keys-beat-meow-motion ()
  "Limiting (`/') and ticking (`!') work in a summary buffer under meow.
Meow's motion map otherwise takes them; its `C-c' stand-in `o' stays.
The map is registered as `meow-global-mode' does, ahead of minor modes."
  (let ((emulation-mode-map-alists
          (cons `((meow-motion-mode . ,meow-motion-state-keymap))
            emulation-mode-map-alists)))
    (with-temp-buffer
      (use-local-map gnus-summary-mode-map)
      (meow-motion-mode)
      (run-hooks 'gnus-summary-mode-hook)
      (should (eq (key-binding "/") 'gnus-summary-limit-map))
      (should (eq (key-binding "!") #'gnus-summary-tick-article-forward))
      (should (eq (key-binding "o") #'my/meow-ctrl-c)))))

(ert-deftest dl-gnus/usenet-over-tls ()
  "Frugal Usenet is a news server, reached over NNTPS (port 563)."
  (let ((news (seq-find (lambda (method) (equal (cadr method) "frugal"))
                gnus-secondary-select-methods)))
    (should (eq (car news) 'nntp))
    (should (equal (cadr (assq 'nntp-address news)) "news.frugalusenet.com"))
    (should (equal (cadr (assq 'nntp-port-number news)) 563))
    (should (eq (cadr (assq 'nntp-open-connection-function news))
                'nntp-open-ssl-stream))))

(ert-deftest dl-gnus/sent-mail-kept-on-server ()
  "Sent mail is copied to Fastmail's Sent folder, already read."
  (should (equal gnus-message-archive-group "nnimap+fastmail:Sent"))
  (should gnus-gcc-mark-as-read))

(provide 'dl-gnus-test)
;;; dl-gnus-test.el ends here
