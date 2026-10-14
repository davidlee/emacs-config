;;; dl-org-ql-test.el --- ert tests for org-ql entry points -*- lexical-binding: t; -*-

;; Run: `just check' (dl-test scans lisp/test), or M-x ert RET dl-org-ql RET.

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'dl-test-notes)
(require 'dl-notes-paths)
(require 'dl-org-ql)
(require 'dl-keymap)

(defconst dl-org-ql-test--corpus
  '("inbox.org" "slips/idea.org" "slips/archived-thought.org"
    "references/deep/paper.org" "archive/old.org" "slips/archive/older.org"
    "work/journal/day.org" "work/archive/legacy.org" "readme.txt")
  "A corpus with personal, work, archived and non-Org files.")

(defun dl-org-ql-test--relative (files)
  "FILES relative to the notes root, sorted."
  (sort (mapcar (lambda (file) (file-relative-name file dl-notes-root)) files)
        #'string<))

(defun dl-org-ql-test--scope-of (command)
  "The files COMMAND hands to org-ql, relative to the notes root, sorted."
  (let (scope)
    (cl-letf (((symbol-function 'org-ql-find)
               (lambda (files &rest _) (setq scope files)))
              ((symbol-function 'org-ql-search)
               (lambda (files &rest _) (setq scope files)))
              ((symbol-function 'read-string) (lambda (&rest _) "todo:")))
      (call-interactively command))
    (dl-org-ql-test--relative scope)))

(ert-deftest dl-org-ql/org-files-recurse-and-skip-archives ()
  "Every Org file below the directory, at any depth, except under archive/."
  (dl-test-with-notes dl-org-ql-test--corpus
    (should (equal (dl-org-ql-test--relative (dl-notes-org-files dl-notes-root))
                   '("inbox.org" "references/deep/paper.org"
                     "slips/archived-thought.org" "slips/idea.org"
                     "work/journal/day.org")))))

(ert-deftest dl-org-ql/org-files-skip-excluded-dirs ()
  (dl-test-with-notes dl-org-ql-test--corpus
    (should-not (seq-some (lambda (file) (string-prefix-p "work/" file))
                          (dl-org-ql-test--relative
                           (dl-notes-org-files dl-notes-root dl-notes-work-dir))))))

(ert-deftest dl-org-ql/find-and-search-cover-personal-notes ()
  "`C-c n q' and `C-c n Q' search the personal corpus, not the current buffer."
  (dl-test-with-notes dl-org-ql-test--corpus
    (dolist (command '(my/org-ql-find-notes my/org-ql-search-notes))
      (should (equal (dl-org-ql-test--scope-of command)
                     '("inbox.org" "references/deep/paper.org"
                       "slips/archived-thought.org" "slips/idea.org"))))))

(ert-deftest dl-org-ql/work-find-covers-work-notes ()
  (dl-test-with-notes dl-org-ql-test--corpus
    (should (equal (dl-org-ql-test--scope-of #'my/org-ql-find-work-notes)
                   '("work/journal/day.org")))))

(ert-deftest dl-org-ql/notes-keys ()
  (should (eq (keymap-lookup my-notes-map "q") #'my/org-ql-find-notes))
  (should (eq (keymap-lookup my-notes-map "Q") #'my/org-ql-search-notes))
  (should (eq (keymap-lookup my-notes-map "V") #'org-ql-view))
  (should (eq (keymap-lookup my-notes-work-map "q") #'my/org-ql-find-work-notes)))

(provide 'dl-org-ql-test)
;;; dl-org-ql-test.el ends here
