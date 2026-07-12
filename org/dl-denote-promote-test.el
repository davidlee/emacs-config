;;; dl-denote-promote-test.el --- ert tests for dl-denote-promote -*- lexical-binding: t; -*-

;; Run from CLI:
;;   emacs --batch \
;;     -L ~/.emacs.d/core -L ~/.emacs.d/org \
;;     -l dl-denote-promote-test.el -f ert-run-tests-batch-and-exit
;;
;; Or interactively: M-x ert RET dl-denote-promote RET.

(require 'ert)
(require 'cl-lib)
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

;;; Promote wrapper — end-to-end (VT-1) and quit path (VT-2).
;;
;; Isolated corpus: `my/denote-promote-targets' let-bound to a temp alist and
;; `completing-read' stubbed — never touches ~/notes.  skip-unless denote-org
;; so the suite passes on an emacs without the package (design §9).

(ert-deftest dl-denote-promote/e2e-creates-note-and-stub ()
  "Promote a tagged 2-level subtree: note lands in chosen dir, subtree gone,
stub sits at the same outline level linking the new ID, tags become keywords."
  (skip-unless (require 'denote-org nil t))
  (let* ((root   (make-temp-file "promote-root-" t))
         (slips  (expand-file-name "slips" root))
         (dl-notes-root root)
         (my/denote-promote-targets (list (cons "slips" slips)))
         (denote-directory root))
    (make-directory slips t)
    (unwind-protect
        (let ((origin (current-buffer)))
          (with-current-buffer origin
            (org-mode)
            (insert "* Keeper heading\n"
                    "before body\n"
                    "** Promote me :alpha:beta:\n"
                    "subtree body\n"
                    "*** child\n"
                    "child body\n"
                    "* After heading\n"
                    "after body\n")
            (goto-char (point-min))
            (search-forward "Promote me")
            (cl-letf (((symbol-function 'completing-read)
                       (lambda (&rest _) "slips")))
              (my/denote-promote-subtree)))
          ;; Back at origin: subtree gone, siblings intact, stub at level 2.
          (let ((txt (with-current-buffer origin (buffer-string))))
            (should-not (string-match-p "subtree body" txt))
            (should-not (string-match-p "child body"  txt))
            (should (string-match-p "Keeper heading" txt))
            (should (string-match-p "After heading"  txt))
            (should (string-match
                     "^\\*\\* → \\[\\[denote:\\([0-9T]+\\)\\]\\[Promote me\\]\\]"
                     txt))
            (let* ((id    (match-string 1 txt))
                   (files (directory-files slips t "\\.org\\'")))
              (should (= (length files) 1))
              (let ((created (car files)))
                (should (string-match-p (regexp-quote id)
                                        (file-name-nondirectory created)))
                (with-temp-buffer
                  (insert-file-contents created)
                  (let ((note (buffer-string)))
                    (should (string-match-p "^#\\+title:.*Promote me" note))
                    (should (string-match-p "^#\\+filetags:.*alpha" note))
                    (should (string-match-p "child body" note))))))))
      (delete-directory root t))))

(ert-deftest dl-denote-promote/quit-leaves-origin-untouched ()
  "Quitting the target prompt aborts before any mutation; origin byte-identical."
  (skip-unless (require 'denote-org nil t))
  (let ((my/denote-promote-targets '(("slips" . "/nonexistent"))))
    (with-temp-buffer
      (org-mode)
      (insert "* Keeper\n** Promote me :x:\nbody\n")
      (goto-char (point-min))
      (search-forward "Promote me")
      (let ((before (buffer-string))
            (quit-caught nil))
        (cl-letf (((symbol-function 'completing-read)
                   (lambda (&rest _) (signal 'quit nil))))
          (condition-case nil
              (my/denote-promote-subtree)
            (quit (setq quit-caught t))))
        (should quit-caught)
        (should (equal (buffer-string) before))))))

(provide 'dl-denote-promote-test)
;;; dl-denote-promote-test.el ends here
