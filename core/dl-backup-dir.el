;;; dl-backup-dir.el --- Backup settings -*- lexical-binding: t; -*-

(use-package emacs
  :ensure nil
  :init
  ;; Don't litter file system with *~ backup files; put them all somewhere nice
  (defun bedrock--backup-file-name (fpath)
    "Return a new file path of a given file path.
     If the new path's directories does not exist, create them."
    (let* ((backupRootDir (concat user-emacs-directory "emacs-backup/"))
           (filePath (replace-regexp-in-string "[A-Za-z]:" "" fpath )) ; remove Windows driver letter in path
           (backupFilePath (replace-regexp-in-string "//" "/" (concat backupRootDir filePath "~") )))
      (make-directory (file-name-directory backupFilePath) (file-name-directory backupFilePath))
      backupFilePath))  
  :custom
  (make-backup-file-name-function 'bedrock--backup-file-name))

(provide 'dl-backup-dir)
