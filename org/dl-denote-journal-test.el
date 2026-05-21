;;; dl-denote-journal-test.el --- ert tests for dl-denote-journal -*- lexical-binding: t; -*-

;; Run from CLI:
;;   emacs --batch \
;;     -L ~/.emacs.d/core -L ~/.emacs.d/org \
;;     --eval "(require 'package)" \
;;     -l dl-denote-journal-test.el -f ert-run-tests-batch-and-exit
;;
;; Or interactively: M-x ert RET dl-denote-journal RET.

(require 'ert)
(require 'dl-notes-paths)
(require 'dl-denote-journal)

;;; Helpers

(defmacro with-journal-buffer ((realm type) &rest body)
  "Create a temp buffer pretending to be a REAM-TYPE journal file, run BODY.
Sets `buffer-file-name' to a fake path matching the journal naming
convention so that `my/journal--buffer-realm' and friends work."
  (declare (indent 1) (debug t))
  (let ((id        (gensym "id"))
        (slug      (gensym "slug"))
        (dir       (gensym "dir"))
        (suffix    (gensym "suffix"))
        (path      (gensym "path"))
        (date-str  (gensym "date-str"))
        (week-str  (gensym "week-str"))
        (monday    (gensym "monday")))
    `(let* ((,date-str "2026-05-21")
            (,week-str "2026-w21")
            (,monday  "20260518T000000")
            (,id      (pcase ,type
                        ('daily "20260521T000000")
                        ('weekly "20260518T000000")))
            (,slug    (pcase ,type
                        ('daily  (concat ,date-str "-thursday"))
                        ('weekly ,week-str)))
            (,suffix  (pcase (cons ,realm ,type)
                        ('(personal . daily)   "journal")
                        ('(work . daily)       "work_journal")
                        ('(personal . weekly)  "weekly_journal")
                        ('(work . weekly)      "work_weekly_journal")))
            (,dir     (pcase (cons ,realm ,type)
                        ('(personal . daily)   dl-notes-journal-dir)
                        ('(work . daily)       dl-notes-work-journal-dir)
                        ('(personal . weekly)  dl-notes-weekly-dir)
                        ('(work . weekly)      dl-notes-work-weekly-dir)))
            (,path    (expand-file-name
                       (format "%s--%s__%s.org" ,id ,slug ,suffix) ,dir)))
       (with-temp-buffer
         (setq buffer-file-name ,path)
         ,@body))))

(defun my/journal--nav-string ()
  "Return the first line of the :NAV: drawer content from current buffer.
Helper for tests: calls `my/journal--links-string' and parses out the
first pipe-separated line between the drawer boundaries.
For weeklies, a second line with day links is available via
`my/journal--nav-day-links'."
  (when-let ((drawer (my/journal--links-string)))
    (when (string-match ":NAV:\n\\([^\n]+\\)" drawer)
      (match-string 1 drawer))))

(defun my/journal--nav-day-links ()
  "Return the second line (day links) of the :NAV: drawer content.
Returns nil if there's only one line (i.e. daily notes)."
  (when-let ((drawer (my/journal--links-string)))
    (when (string-match ":NAV:\n[^\n]+\n\\([^\n]+\\)" drawer)
      (match-string 1 drawer))))

;;; Personal daily

(ert-deftest dl-denote-journal/personal-daily-nav ()
  "Personal daily links: prev-day | WkNN | *Personal* | Work | next-day"
  (with-journal-buffer (personal daily)
    (let ((nav (my/journal--nav-string)))
      (should nav)
      ;; Check structure: 5 pipe-separated fields
      (let ((parts (split-string nav " | ")))
        (should (= (length parts) 5))
        ;; Field 1: prev-day link
        (should (string-match
                 (format "\\[\\[file:%s.*2026-05-20.*\\]\\[← 2026-05-20 .*\\]\\]"
                         (regexp-quote (expand-file-name "~/notes/journal/")))
                 (nth 0 parts)))
        ;; Field 2: week link (WkNN)
        (should (string-match "\\[\\[file:.*\\]\\[Wk21\\]\\]" (nth 1 parts)))
        ;; Field 3: realm label
        (should (equal (nth 2 parts) "*Personal*"))
        ;; Field 4: cross-realm link
        (should (string-match "\\[\\[file:.*work/journal/20260521.*\\]\\[Work\\]\\]"
                              (nth 3 parts)))
        ;; Field 5: next-day link
        (should (string-match
                 (format "\\[\\[file:%s.*2026-05-22.*\\]\\[2026-05-22 .* →\\]\\]"
                         (regexp-quote (expand-file-name "~/notes/journal/")))
                 (nth 4 parts)))))))

;;; Work daily

(ert-deftest dl-denote-journal/work-daily-nav ()
  "Work daily links: prev-day | WkNN | *Work* | Personal | next-day"
  (with-journal-buffer (work daily)
    (let ((nav (my/journal--nav-string)))
      (should nav)
      (let ((parts (split-string nav " | ")))
        (should (= (length parts) 5))
        (should (string-match "\\[\\[file:.*work/journal/20260520.*\\]\\[← 2026-05-20"
                              (nth 0 parts)))
        (should (string-match "\\[\\[file:.*\\]\\[Wk21\\]\\]" (nth 1 parts)))
        (should (equal (nth 2 parts) "*Work*"))
        (should (string-match "\\[\\[file:.*journal/20260521.*\\]\\[Personal\\]\\]"
                              (nth 3 parts)))
        (should (string-match "\\[\\[file:.*work/journal/20260522.*\\]\\[2026-05-22 .* →\\]\\]"
                              (nth 4 parts)))))))

;;; Personal weekly

(ert-deftest dl-denote-journal/personal-weekly-nav ()
  "Personal weekly links: prev-week | *Personal* | Work | next-week"
  (with-journal-buffer (personal weekly)
    (let ((nav (my/journal--nav-string))
          (day-links (my/journal--nav-day-links)))
      (should nav)
      (let ((parts (split-string nav " | ")))
        (should (= (length parts) 4))
        (should (string-match "\\[\\[file:.*\\]\\[← Wk20\\]\\]" (nth 0 parts)))
        (should (equal (nth 1 parts) "*Personal*"))
        (should (string-match "\\[\\[file:.*work/weekly/20260518.*\\]\\[Work\\]\\]"
                              (nth 2 parts)))
        (should (string-match "\\[\\[file:.*\\]\\[Wk22 →\\]\\]" (nth 3 parts))))
      ;; Second row: day links for Mon–Sun of this week
      (should day-links)
      (let ((day-parts (split-string day-links " | ")))
        (should (= (length day-parts) 7))
        (should (string-match "\\[\\[file:.*journal/20260518.*\\]\\[Mon 18\\]\\]" (nth 0 day-parts)))
        (should (string-match "\\[\\[file:.*journal/20260519.*\\]\\[Tue 19\\]\\]" (nth 1 day-parts)))
        (should (string-match "\\[\\[file:.*journal/20260520.*\\]\\[Wed 20\\]\\]" (nth 2 day-parts)))
        (should (string-match "\\[\\[file:.*journal/20260521.*\\]\\[Thu 21\\]\\]" (nth 3 day-parts)))
        (should (string-match "\\[\\[file:.*journal/20260522.*\\]\\[Fri 22\\]\\]" (nth 4 day-parts)))
        (should (string-match "\\[\\[file:.*journal/20260523.*\\]\\[Sat 23\\]\\]" (nth 5 day-parts)))
        (should (string-match "\\[\\[file:.*journal/20260524.*\\]\\[Sun 24\\]\\]" (nth 6 day-parts)))))))

;;; Work weekly

(ert-deftest dl-denote-journal/work-weekly-nav ()
  "Work weekly links: prev-week | *Work* | Personal | next-week"
  (with-journal-buffer (work weekly)
    (let ((nav (my/journal--nav-string))
          (day-links (my/journal--nav-day-links)))
      (should nav)
      (let ((parts (split-string nav " | ")))
        (should (= (length parts) 4))
        (should (string-match "\\[\\[file:.*\\]\\[← Wk20\\]\\]" (nth 0 parts)))
        (should (equal (nth 1 parts) "*Work*"))
        (should (string-match "\\[\\[file:.*weekly/20260518.*\\]\\[Personal\\]\\]"
                              (nth 2 parts)))
        (should (string-match "\\[\\[file:.*\\]\\[Wk22 →\\]\\]" (nth 3 parts))))
      ;; Second row: work daily links for Mon–Sun
      (should day-links)
      (let ((day-parts (split-string day-links " | ")))
        (should (= (length day-parts) 7))
        (should (string-match "\\[\\[file:.*work/journal/20260518.*\\]\\[Mon 18\\]\\]" (nth 0 day-parts)))
        (should (string-match "\\[\\[file:.*work/journal/20260519.*\\]\\[Tue 19\\]\\]" (nth 1 day-parts)))
        (should (string-match "\\[\\[file:.*work/journal/20260520.*\\]\\[Wed 20\\]\\]" (nth 2 day-parts)))
        (should (string-match "\\[\\[file:.*work/journal/20260521.*\\]\\[Thu 21\\]\\]" (nth 3 day-parts)))
        (should (string-match "\\[\\[file:.*work/journal/20260522.*\\]\\[Fri 22\\]\\]" (nth 4 day-parts)))
        (should (string-match "\\[\\[file:.*work/journal/20260523.*\\]\\[Sat 23\\]\\]" (nth 5 day-parts)))
        (should (string-match "\\[\\[file:.*work/journal/20260524.*\\]\\[Sun 24\\]\\]" (nth 6 day-parts)))))))

;;; Buffer-realm detection

(ert-deftest dl-denote-journal/buffer-realm-personal-daily ()
  (with-journal-buffer (personal daily)
    (should (equal (my/journal--buffer-realm) '(personal daily)))))

(ert-deftest dl-denote-journal/buffer-realm-work-daily ()
  (with-journal-buffer (work daily)
    (should (equal (my/journal--buffer-realm) '(work daily)))))

(ert-deftest dl-denote-journal/buffer-realm-personal-weekly ()
  (with-journal-buffer (personal weekly)
    (should (equal (my/journal--buffer-realm) '(personal weekly)))))

(ert-deftest dl-denote-journal/buffer-realm-work-weekly ()
  (with-journal-buffer (work weekly)
    (should (equal (my/journal--buffer-realm) '(work weekly)))))

;;; find-file-hook — populating non-existent journal files

(ert-deftest dl-denote-journal/populate-empty-daily ()
  "Empty personal daily buffer gets skeleton + :NAV: drawer from hook."
  (let ((dl-notes-journal-dir (make-temp-file "test-journal-" t))
        (path nil))
    (unwind-protect
        (progn
          (setq path (expand-file-name
                      "20260521T000000--2026-05-21-thursday__journal.org"
                      dl-notes-journal-dir))
          (with-temp-buffer
            (setq buffer-file-name path)
            (should (= (point-max) 1))
            (should (not (file-exists-p path)))
            (my/journal--populate-if-empty)
            (should (> (point-max) 1))
            (should (string-match "^#\\+title:" (buffer-string)))
            (should (string-match ":NAV:" (buffer-string)))))
      (when path (delete-file path))
      (delete-directory dl-notes-journal-dir t))))

(ert-deftest dl-denote-journal/populate-empty-weekly ()
  "Empty personal weekly buffer gets skeleton + :NAV: drawer from hook."
  (let ((dl-notes-weekly-dir (make-temp-file "test-weekly-" t))
        (path nil))
    (unwind-protect
        (progn
          (setq path (expand-file-name
                      "20260518T000000--2026-w21__weekly_journal.org"
                      dl-notes-weekly-dir))
          (with-temp-buffer
            (setq buffer-file-name path)
            (my/journal--populate-if-empty)
            (should (> (point-max) 1))
            (should (string-match "^#\\+title:" (buffer-string)))
            (should (string-match ":NAV:" (buffer-string)))
            (should (string-match "Mon 18" (buffer-string)))))
      (when path (ignore-errors (delete-file path)))
      (delete-directory dl-notes-weekly-dir t))))

(ert-deftest dl-denote-journal/populate-empty-work-daily ()
  "Empty work daily buffer gets skeleton + :NAV: drawer from hook."
  (let ((dl-notes-work-journal-dir (make-temp-file "test-work-journal-" t))
        (path nil))
    (unwind-protect
        (progn
          (setq path (expand-file-name
                      "20260521T000000--2026-05-21-thursday__work_journal.org"
                      dl-notes-work-journal-dir))
          (with-temp-buffer
            (setq buffer-file-name path)
            (my/journal--populate-if-empty)
            (should (> (point-max) 1))
            (should (string-match "^#\\+title:" (buffer-string)))
            (should (string-match ":NAV:" (buffer-string)))
            (should (string-match "\\*Work\\*" (buffer-string)))))
      (when path (ignore-errors (delete-file path)))
      (delete-directory dl-notes-work-journal-dir t))))

(ert-deftest dl-denote-journal/populate-existing-noop ()
  "Visiting an existing journal file does not trigger population."
  (let* ((dl-notes-journal-dir (make-temp-file "test-journal-" t))
         (path (expand-file-name
                "20260521T000000--2026-05-21-thursday__journal.org"
                dl-notes-journal-dir)))
    (unwind-protect
        (progn
          (with-temp-file path (insert "#+title: existing\n"))
          (with-temp-buffer
            (setq buffer-file-name path)
            (insert "#+title: existing\n")
            (my/journal--populate-if-empty)
            (should (equal (buffer-string) "#+title: existing\n"))))
      (when path (ignore-errors (delete-file path)))
      (delete-directory dl-notes-journal-dir t))))

(ert-deftest dl-denote-journal/populate-non-journal-noop ()
  "Empty buffer for non-journal path is not modified."
  (with-temp-buffer
    (setq buffer-file-name "/tmp/some-random-file.org")
    (my/journal--populate-if-empty)
    (should (equal (buffer-string) ""))))

(provide 'dl-denote-journal-test)
;;; dl-denote-journal-test.el ends here