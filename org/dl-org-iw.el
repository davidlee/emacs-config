;;; dl-org-iw.el --- org-iw (incremental writing) -*- lexical-binding: t; -*-

(require 'dl-modeline)

(use-package org-iw
  :load-path "~/dev/org-incremental-writing"
  :commands (org-iw-add org-iw-visit-next org-iw-continue org-iw-end-session
              org-iw-move org-iw-remove org-iw-list-queue org-iw-add-files)
  :custom
  (org-iw-sources '("~/notes"))
  (org-iw-exclude-regexp "/notes/archive/") ; matched against true names
  (org-iw-queues '(
                    ("HABITS" :name "Habits")
                    ("PROJECTS" :name "Projects")
                    ("JOURNAL" :name "Journal")
                    ("WORK-JOURNAL" :name "Work journal")
                    ("ARTICLES" :name "Articles")
                    ("LEARN" :name "Learn")
                    ("READ" :name "Read")
                    ("DO" :name "Do" :placements
                      (("Next" (after 1))
                        ("Halfway" (percent 50))
                        ("Last" end))
                      :default "Next"))))

(defvar dl-org-iw-journal-queues
  '(((personal daily) . "JOURNAL")
     ((work daily) . "WORK-JOURNAL"))
  "Queue each new journal note joins, by its (REALM TYPE).
A note whose (REALM TYPE) is absent joins none.")

(defun dl-org-iw--enrol-journal (file realm type)
  "Add the new journal note FILE to the end of its queue, if any.
REALM and TYPE choose the queue from `dl-org-iw-journal-queues'.  For
`my/journal-created-functions': a refusal is reported, not raised, so
it never interrupts creating the note."
  (when-let* ((queue (alist-get (list realm type) dl-org-iw-journal-queues
                       nil nil #'equal)))
    (with-demoted-errors "org-iw journal enrolment: %S"
      (org-iw-add-files queue (list file)))))

(add-hook 'my/journal-created-functions #'dl-org-iw--enrol-journal)

(defvar org-iw--session)
(declare-function org-iw--mode-line "org-iw")

;; lambda-line ignores `global-mode-string', where org-iw shows its
;; session.  Until org-iw has a public session string (IMP-001), call
;; the private one, trailing space and all.
(defun dl-org-iw--modeline-segment ()
  "The org-iw session for the active window's modeline, or nil."
  (when (and (bound-and-true-p org-iw--session)
          (dl-modeline-window-active-p))
    (org-iw--mode-line)))

(add-to-list 'dl-modeline-segments #'dl-org-iw--modeline-segment 'append)

(provide 'dl-org-iw)
;;; dl-org-iw.el ends here
