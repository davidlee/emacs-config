;;; dl-gptel-macher-test.el --- ert tests for macher workspace detection -*- lexical-binding: t; -*-

;; Run: `just check' (dl-test scans lisp/test), or M-x ert RET dl-gptel-macher RET.

;;; Code:

(require 'ert)
(require 'dl-gptel-macher)

(defun dl-gptel-macher-test--git-init (dir)
  "Make DIR a git repository, so project.el sees it as a project."
  (make-directory dir t)
  (let ((default-directory dir))
    (call-process "git" nil nil nil "init" "--quiet")))

(defmacro dl-gptel-macher-test--with-home (home &rest body)
  "Run BODY with a fresh git repo bound to HOME and as $HOME."
  (declare (indent 1))
  `(let* ((,home (file-name-as-directory (make-temp-file "dl-gptel-macher-home" t)))
          (process-environment (cons (concat "HOME=" ,home) process-environment)))
     (unwind-protect
         (progn (dl-gptel-macher-test--git-init ,home) ,@body)
       (delete-directory ,home t))))

(defun dl-gptel-macher-test--workspace-in (dir)
  "The workspace `dl-gptel-macher-workspace-project' finds for a buffer in DIR."
  (with-temp-buffer
    (setq default-directory dir)
    (dl-gptel-macher-workspace-project)))

(ert-deftest dl-gptel-macher/home-repo-is-not-a-workspace ()
  "A buffer in the $HOME dotfiles repo gets no project workspace."
  (dl-gptel-macher-test--with-home home
    (should-not (dl-gptel-macher-test--workspace-in home))
    (let ((subdir (expand-file-name "notes/" home)))
      (make-directory subdir)
      (should-not (dl-gptel-macher-test--workspace-in subdir)))))

(ert-deftest dl-gptel-macher/nested-project-is-a-workspace ()
  "A project of its own under $HOME is still a workspace."
  (dl-gptel-macher-test--with-home home
    (let ((project (expand-file-name "dev/thing/" home)))
      (dl-gptel-macher-test--git-init project)
      (should (equal (dl-gptel-macher-test--workspace-in project)
                     (cons 'project (abbreviate-file-name project)))))))

;;; dl-gptel-macher-test.el ends here
