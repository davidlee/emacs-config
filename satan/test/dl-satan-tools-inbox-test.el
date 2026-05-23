;;; dl-satan-tools-inbox-test.el --- ert tests for dl-satan-tools-inbox -*- lexical-binding: t; -*-

;; Run from CLI:
;;   emacs --batch \
;;     -L ~/.emacs.d/core -L ~/.emacs.d/satan -L ~/.emacs.d/satan/test \
;;     -l dl-satan-tools-inbox-test.el -f ert-run-tests-batch-and-exit

(require 'ert)
(require 'cl-lib)
(require 'dl-satan-tools-inbox)

(ert-deftest dl-satan-inbox/handler-appends-headline ()
  (let* ((tmp (make-temp-file "satan-inbox-"))
         (dl-satan-inbox-file tmp))
    (unwind-protect
        (let* ((res (dl-satan-tool/inbox-append
                     '(:title "Daily plan ready"
                       :body "Focus section blank; nudge to fill in.")
                     '(:id "r1" :mode-name "motd"
                       :capabilities (inbox-write)))))
          (should (eq (car res) 'ok))
          (let ((text (with-temp-buffer
                        (insert-file-contents tmp)
                        (buffer-string))))
            (should (string-match-p "#\\+title:    SATAN inbox" text))
            (should (string-match-p "^\\* \\[.*\\] Daily plan ready" text))
            (should (string-match-p ":unread:satan:" text))
            (should (string-match-p ":RUN_ID: r1" text))
            (should (string-match-p "Focus section blank" text))))
      (when (file-exists-p tmp) (delete-file tmp)))))

(ert-deftest dl-satan-inbox/capability-required ()
  (let ((res (dl-satan-tool/inbox-append
              '(:title "t" :body "b")
              '(:capabilities (write-daily)))))
    (should (eq (car res) 'error))
    (should (string-match-p "inbox-write" (cdr res)))))

(ert-deftest dl-satan-inbox/append-preserves-existing ()
  (let* ((tmp (make-temp-file "satan-inbox-"))
         (dl-satan-inbox-file tmp))
    (unwind-protect
        (progn
          (dl-satan-tool/inbox-append
           '(:title "first" :body "a")
           '(:id "r1" :mode-name "motd" :capabilities (inbox-write)))
          (dl-satan-tool/inbox-append
           '(:title "second" :body "b" :urgency "urgent")
           '(:id "r1" :mode-name "motd" :capabilities (inbox-write)))
          (let ((text (with-temp-buffer
                        (insert-file-contents tmp)
                        (buffer-string))))
            (should (string-match-p "first" text))
            (should (string-match-p "second" text))
            (should (string-match-p ":urgent:" text))))
      (when (file-exists-p tmp) (delete-file tmp)))))

(ert-deftest dl-satan-inbox/unread-count-matches-tags ()
  (let* ((tmp (make-temp-file "satan-inbox-"))
         (dl-satan-inbox-file tmp))
    (unwind-protect
        (progn
          (should (equal (my/satan-inbox-unread-count) 0))
          (dl-satan-tool/inbox-append
           '(:title "a" :body "x")
           '(:capabilities (inbox-write)))
          (dl-satan-tool/inbox-append
           '(:title "b" :body "y")
           '(:capabilities (inbox-write)))
          (should (equal (my/satan-inbox-unread-count) 2)))
      (when (file-exists-p tmp) (delete-file tmp)))))

(provide 'dl-satan-tools-inbox-test)
;;; dl-satan-tools-inbox-test.el ends here
