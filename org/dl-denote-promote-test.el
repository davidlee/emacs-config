;;; dl-denote-promote-test.el --- ert tests for dl-denote-promote -*- lexical-binding: t; -*-

;; Run from CLI:
;;   emacs --batch \
;;     -L ~/.emacs.d/core -L ~/.emacs.d/org \
;;     -l dl-denote-promote-test.el -f ert-run-tests-batch-and-exit
;;
;; Or interactively: M-x ert RET dl-denote-promote RET.

(require 'ert)
(require 'dl-notes-paths)
(require 'dl-denote-promote)

;;; Stub helper — pure string contract (design SL-013 §5.2).

(ert-deftest dl-denote-promote/stub-level-1 ()
  (should (equal (my/denote-promote--stub 1 "20260712T101010" "My idea")
                 "* → [[denote:20260712T101010][My idea]]")))

(ert-deftest dl-denote-promote/stub-preserves-level ()
  (should (equal (my/denote-promote--stub 3 "20260712T101010" "Deep thought")
                 "*** → [[denote:20260712T101010][Deep thought]]")))

(ert-deftest dl-denote-promote/stub-empty-title-degrades-to-id ()
  (should (equal (my/denote-promote--stub 2 "20260712T101010" "")
                 "** → [[denote:20260712T101010]]")))

;;; Curated targets — derived from dl-notes-*-dir defconsts (design D2).

(ert-deftest dl-denote-promote/targets-cover-both-realms ()
  (let ((labels (mapcar #'car my/denote-promote-targets)))
    (should (equal (length labels) 10))
    (dolist (label '("slips" "sources" "references" "projects" "areas"
                     "work/slips" "work/sources" "work/references"
                     "work/projects" "work/areas"))
      (should (member label labels)))))

(ert-deftest dl-denote-promote/targets-dirs-match-path-defconsts ()
  (should (equal (cdr (assoc "slips" my/denote-promote-targets))
                 dl-notes-slips-dir))
  (should (equal (cdr (assoc "work/areas" my/denote-promote-targets))
                 dl-notes-work-areas-dir)))

(provide 'dl-denote-promote-test)
;;; dl-denote-promote-test.el ends here
