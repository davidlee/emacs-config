;;; dl-review-test.el --- ert tests for dl-review views -*- lexical-binding: t; -*-

;; Run from CLI:
;;   emacs --batch \
;;     -L ~/.emacs.d/core -L ~/.emacs.d/org \
;;     -l dl-review-test.el -f ert-run-tests-batch-and-exit
;;
;; Or interactively: M-x ert RET dl-review RET.

(require 'ert)
(require 'cl-lib)
(require 'org-ql)
(require 'dl-notes-paths)
(require 'dl-review)

;;; VT-1 — journal-open query surfaces open-keyword headings only.
;;
;; Temp journal corpus; `dl-notes-journal-dir' / `dl-notes-weekly-dir'
;; let-bound (defconsts are special).  `org-todo-keywords' let-bound so the
;; NEXT keyword is a recognised not-done state independent of live config.

(ert-deftest dl-review/journal-open-selects-open-keywords ()
  "`(todo)' over the journal file set returns TODO+NEXT, excludes DONE."
  (let* ((journal (make-temp-file "review-journal-" t))
         (weekly  (make-temp-file "review-weekly-" t))
         (dl-notes-journal-dir journal)
         (dl-notes-weekly-dir  weekly)
         (org-todo-keywords '((sequence "TODO" "NEXT" "|" "DONE")))
         (file (expand-file-name "2026-07-12.org" journal)))
    (unwind-protect
        (progn
          (with-temp-file file
            (insert "* TODO drain the inbox\n"
                    "* NEXT promote a slip\n"
                    "* DONE already filed\n"
                    "* plain heading no keyword\n"))
          (let ((headings (org-ql-select (my/review--journal-files) '(todo)
                            :action '(org-get-heading t t))))
            (should (member "drain the inbox" headings))
            (should (member "promote a slip" headings))
            (should-not (member "already filed" headings))
            (should-not (member "plain heading no keyword" headings))))
      (delete-directory journal t)
      (delete-directory weekly t))))

;;; VT-2 — recent-note-files: durable org files, mtime desc, capped at N.

(ert-deftest dl-review/recent-note-files-orders-and-caps ()
  "Newest-first by mtime, only .org, capped at N across the given dirs."
  (let* ((da (make-temp-file "review-recent-a-" t))
         (db (make-temp-file "review-recent-b-" t)))
    (unwind-protect
        (cl-labels ((plant (dir name epoch)
                      (let ((f (expand-file-name name dir)))
                        (with-temp-file f (insert "x"))
                        (set-file-times f (seconds-to-time epoch))
                        f)))
          ;; epochs ascending → newest is the largest
          (plant da "old.org"    1000)
          (plant db "mid.org"    2000)
          (plant da "new.org"    3000)
          (plant db "newest.org" 4000)
          (plant da "note.txt"   9999) ; non-org, must be ignored
          (let ((got (mapcar #'file-name-nondirectory
                             (my/review--recent-note-files (list da db) 3))))
            (should (equal got '("newest.org" "new.org" "mid.org")))))
      (delete-directory da t)
      (delete-directory db t))))

(provide 'dl-review-test)
;;; dl-review-test.el ends here
