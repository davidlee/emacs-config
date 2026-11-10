;;; dl-test-notes.el --- Test fixture: a throwaway notes corpus -*- lexical-binding: t; -*-

;; Shared by suites that read the notes corpus.  Not a test file itself
;; (no "-test" suffix), so `dl-test' loads it only through `require'.

;;; Code:

(defvar dl-notes-root)
(defvar dl-notes-work-dir)

(defmacro dl-test-with-notes (files &rest body)
  "Run BODY with the notes root bound to a fresh directory holding FILES.
Binds `dl-notes-root' and `dl-notes-work-dir' (its work/ child).  FILES
are paths relative to the root; each is created as a one-task Org file.
The directory is deleted afterwards."
  (declare (indent 1))
  `(let* ((dl-notes-root (file-name-as-directory (make-temp-file "dl-test-notes" t)))
          (dl-notes-work-dir (expand-file-name "work" dl-notes-root)))
     (unwind-protect
         (progn
           (dolist (file ,files)
             (let ((path (expand-file-name file dl-notes-root)))
               (make-directory (file-name-directory path) t)
               (write-region "* TODO Test task\n" nil path)))
           ,@body)
       (delete-directory dl-notes-root t))))

(provide 'dl-test-notes)
;;; dl-test-notes.el ends here
