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

;;; Layout saving (project-x)

(add-to-list 'load-path (expand-file-name "elpa/project-x" user-emacs-directory))
(require 'project-x)

(defmacro dl-project-test--with-layouts (root &rest body)
  "Run BODY with ROOT a scratch project and layouts in a scratch file.
The session starts having restored and saved nothing; restores are
tracked as in the live config."
  (declare (indent 1))
  `(let* ((,root (file-name-as-directory (make-temp-file "dl-project-test-" t)))
          (project-x-window-list-file (make-temp-file "dl-project-test-layouts-"))
          (project-x-window-alist nil)
          (dl-project--owned-layouts nil)
          (inhibit-message t))
     (advice-add 'project-x--window-state-restore :around
                 #'dl-project--note-restore)
     (unwind-protect
         (progn (write-region "" nil (expand-file-name ".project" ,root))
                ,@body)
       (advice-remove 'project-x--window-state-restore
                      #'dl-project--note-restore)
       (delete-directory ,root t)
       (delete-file project-x-window-list-file))))

(defun dl-project-test--earlier-layout (root)
  "Give ROOT a layout saved by an earlier session."
  (project-x--set-session-entry
   root `((earlier . t) (files) (windows . ,(window-state-get nil t)))))

(defun dl-project-test--earlier-layout-p (root)
  "Non-nil while ROOT's saved layout is the earlier session's."
  (alist-get 'earlier (project-x--session-entry root)))

(ert-deftest dl-project/saves-new-layout ()
  "A project with no saved layout gets one."
  (dl-project-test--with-layouts root
    (dl-project--save-layout root)
    (should (project-x--session-has-window-state-p root))))

(ert-deftest dl-project/keeps-unrestored-layout ()
  "A layout saved by an earlier session survives until it is restored.
Otherwise visiting the project without restoring would overwrite it."
  (dl-project-test--with-layouts root
    (dl-project-test--earlier-layout root)
    (dl-project--save-layout root)
    (should (dl-project-test--earlier-layout-p root))))

(ert-deftest dl-project/saves-over-restored-layout ()
  "Once restored, a layout is this session's to save over."
  (dl-project-test--with-layouts root
    (dl-project-test--earlier-layout root)
    (project-x--window-state-restore root)
    (dl-project--save-layout root)
    (should-not (dl-project-test--earlier-layout-p root))))

(ert-deftest dl-project/keeps-saving-own-layout ()
  "A layout this session saved stays this session's to save over."
  (dl-project-test--with-layouts root
    (dl-project--save-layout root)
    (project-x--set-session-entry
     root (cons '(earlier . t) (project-x--session-entry root)))
    (dl-project--save-layout root)
    (should-not (dl-project-test--earlier-layout-p root))))

(provide 'dl-project-test)
;;; dl-project-test.el ends here
