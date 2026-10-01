;;; dl-org-iw.el --- org-iw (incremental writing) -*- lexical-binding: t; -*-

(require 'dl-modeline)

(use-package org-iw
  :load-path "~/dev/org-incremental-writing"
  :commands (org-iw-add org-iw-visit-next org-iw-continue org-iw-end-session)
  :custom
  (org-iw-sources '("~/notes"))
  (org-iw-exclude-regexp "/notes/archive/") ; matched against true names
  (org-iw-queues '(("ARTICLES" :name "Articles")
                    ("LEARN" :name "Learn")
                    ("READ" :name "Read")
                    ("DO" :name "Do"))))

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
