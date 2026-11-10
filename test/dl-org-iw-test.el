;;; dl-org-iw-test.el --- ert tests for dl-org-iw -*- lexical-binding: t; -*-

;; Each test builds a throwaway notes tree and points org-iw at it, so
;; nothing touches ~/notes.

(require 'ert)
(require 'dl-denote-journal-test)
(require 'dl-org-iw)
(require 'org-iw)

(defmacro dl-org-iw-test--with-notes (&rest body)
  "Run BODY as `dl-denote-journal-test--with-notes' does, org-iw on its notes.
New notes are announced to `dl-org-iw--enrol-journal' alone."
  (declare (indent 0) (debug t))
  `(dl-denote-journal-test--with-notes
     (let ((org-iw-sources (list notes))
           (org-iw-exclude-regexp nil)
           (my/journal-created-functions (list #'dl-org-iw--enrol-journal)))
       ,@body)))

(defun dl-org-iw-test--queue-files (queue)
  "The true names of QUEUE's members, in order."
  (mapcar #'org-iw-entry-file
          (org-iw--order (org-iw--scan) queue)))

(ert-deftest dl-org-iw/new-dailies-join-their-realm-queue ()
  (dl-org-iw-test--with-notes
    (let ((personal (my/journal--ensure-today))
          (work (my/work-journal--ensure-today)))
      (should (equal (dl-org-iw-test--queue-files "JOURNAL")
                     (list (file-truename personal))))
      (should (equal (dl-org-iw-test--queue-files "WORK-JOURNAL")
                     (list (file-truename work)))))))

(ert-deftest dl-org-iw/visited-daily-joins-queue-on-first-save ()
  (dl-org-iw-test--with-notes
    (let ((file (my/journal--today-file dl-notes-journal-dir "journal")))
      (with-current-buffer (find-file-noselect file)
        (save-buffer)
        (should (equal (dl-org-iw-test--queue-files "JOURNAL")
                       (list (file-truename file))))
        (should-not (buffer-modified-p))))))

(ert-deftest dl-org-iw/new-weekly-joins-no-queue ()
  (dl-org-iw-test--with-notes
    (my/journal--ensure-file
     (my/journal--week-file dl-notes-weekly-dir "weekly_journal")
     (my/journal--week-skeleton ":weekly:journal:"))
    (should-not (dl-org-iw-test--queue-files "JOURNAL"))))

(provide 'dl-org-iw-test)
;;; dl-org-iw-test.el ends here
