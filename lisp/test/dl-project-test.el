;;; dl-project-test.el --- ert tests for project detection -*- lexical-binding: t; -*-

;; Run: `just check' (dl-test scans lisp/test), or M-x ert RET dl-project RET.

(require 'ert)
(require 'dl-project)

(defmacro dl-project-test--with-marker-dir (sub &rest body)
  "Run BODY with SUB bound to a flake.nix dir nested in a scratch git repo.
SUB has no .git of its own, mimicking a directory inside the ~/.git repo."
  (declare (indent 1))
  (let ((outer (make-symbol "outer")))
    `(let* ((,outer (file-name-as-directory
                     (make-temp-file "dl-project-test-" t)))
            (,sub (file-name-as-directory (expand-file-name "sub" ,outer))))
       (unwind-protect
           (let ((default-directory ,outer))
             (make-directory ,sub)
             (call-process "git" nil nil nil "init" "-q")
             (dolist (f '("outer.el" "sub/flake.nix" "sub/inner.el"))
               (write-region "" nil (expand-file-name f ,outer)))
             ,@body)
         (delete-directory ,outer t)))))

(defun dl-project-test--relative-files (dir)
  "Files of the project at DIR, relative to its root."
  (let ((project (project-current nil dir)))
    (mapcar (lambda (f) (file-relative-name f (project-root project)))
            (project-files project))))

(ert-deftest dl-project/marker-dir-stops-root-climb ()
  "A flake.nix dir inside a larger repo is its own project root.
Otherwise the enclosing repo (e.g. ~/.git) becomes the project."
  (dl-project-test--with-marker-dir sub
    (should (file-equal-p (project-root (project-current nil sub)) sub))
    (should (equal (sort (dl-project-test--relative-files sub) #'string<)
                   '("flake.nix" "inner.el")))))

(ert-deftest dl-project/listing-does-not-follow-symlinks ()
  "Symlinked dirs (.direnv flake inputs, notes) are not crawled.
Following them turned `project-find-file' into a multi-million-file
walk that hung Emacs."
  (dl-project-test--with-marker-dir sub
    (let ((elsewhere (make-temp-file "dl-project-test-elsewhere-" t)))
      (unwind-protect
          (progn
            (write-region "" nil (expand-file-name "far.el" elsewhere))
            (make-symbolic-link elsewhere (expand-file-name "link" sub))
            (should-not (member "link/far.el"
                                (dl-project-test--relative-files sub))))
        (delete-directory elsewhere t)))))

(provide 'dl-project-test)
;;; dl-project-test.el ends here
