;;; dl-dirs-test.el --- ert tests for the config's directory lists -*- lexical-binding: t; -*-

;; Run: `just check' (dl-test scans test/), or M-x ert RET dl-dirs RET.

(require 'ert)
(require 'dl-dirs)

(ert-deftest dl-dirs/every-listed-directory-exists ()
  "A stale entry (a directory since moved or removed) fails here."
  (dolist (dir (append dl-dirs-config dl-dirs-tests))
    (should (file-directory-p (expand-file-name dir user-emacs-directory)))))

(ert-deftest dl-dirs/every-config-source-directory-is-listed ()
  "A top-level directory holding config `dl-*.el' sources is in `dl-dirs-config'.
Catches a new domain directory that was never added to the list."
  (let ((root (expand-file-name user-emacs-directory)))
    (dolist (dir (directory-files root nil "\\`[^.]"))
      (when (and (file-directory-p (expand-file-name dir root))
                 (not (member dir (append dl-dirs-tests '("elpa" "eln-cache"))))
                 (directory-files (expand-file-name dir root) nil "\\`dl-.*\\.el\\'"))
        (should (member dir dl-dirs-config))))))

(ert-deftest dl-dirs/load-path-is-config-then-checkouts-absolute ()
  (let ((user-emacs-directory "/cfg/"))
    (should (equal (dl-dirs-load-path)
                   (mapcar (lambda (dir) (expand-file-name dir "/cfg/"))
                           (append dl-dirs-config dl-dirs-checkouts))))))

(ert-deftest dl-dirs/batch-load-path-adds-tests ()
  (let ((load-path nil)
        (user-emacs-directory "/cfg/"))
    (dl-dirs-batch-load-path)
    (should (equal load-path
                   (mapcar (lambda (dir) (expand-file-name dir "/cfg/"))
                           (append dl-dirs-config dl-dirs-checkouts
                                   dl-dirs-tests))))))

(ert-deftest dl-dirs/load-path-lets-a-bare-emacs-require-config-libs ()
  "A child `emacs -Q' given the config's -L dirs finds `dl-project' and `dl-consult-notes'.
This is Flymake's byte-compile subprocess: it inherits no `load-path'."
  (let* ((args (mapcan (lambda (dir) (list "-L" dir)) (dl-dirs-load-path)))
         (exit (apply #'call-process (expand-file-name invocation-name invocation-directory)
                      nil nil nil "-Q" "--batch" (append args '("--eval"
                      "(unless (and (locate-library \"dl-project\") (locate-library \"dl-consult-notes\")) (kill-emacs 1))")))))
    (should (zerop exit))))

(provide 'dl-dirs-test)
;;; dl-dirs-test.el ends here
