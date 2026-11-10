;;; dl-dirs.el --- The config's directory lists -*- lexical-binding: t; -*-

;;; Commentary:

;; The one place that names the config's Lisp directories.  No side
;; effects on load, so batch tools can load it on its own:
;;
;;   core/dl-path.el        live load-path and trusted-content
;;   dev/dl-lint.el         Flymake / `just lint' child load-path
;;   lang/dl-elisp.el       Flymake child load-path
;;   core/dl-policy-lint.el  directories the policy lint reads
;;   dev/dl-test.el         directories scanned for ERT files
;;   Justfile              `check' and `wc'
;;
;; Tracked directories (config, tests) resolve against `dl-dirs-root',
;; the checkout holding this file; installed ones (checkouts, elpa/)
;; against `user-emacs-directory'.  Live, the two are the same; in a
;; worktree, a batch tool reads the worktree's sources and the live
;; config's installed packages (elpa/ is untracked, so a worktree has none).

;;; Code:

(defconst dl-dirs-root
  (file-name-directory
   (directory-file-name
    (file-name-directory (or load-file-name buffer-file-name))))
  "The checkout holding this file: this file lives in its core/.")

(defconst dl-dirs-config
  '("core" "editing" "completion" "apps" "org" "dev" "lang")
  "My own Lisp directories.")

(defconst dl-dirs-checkouts
  '("checkout" "elpa/org-timeblock" "~/dev/satan/satan")
  "Installed checkout Lisp directories, under `user-emacs-directory'.")

(defconst dl-dirs-tests '("test")
  "Directories holding ERT files and their helpers.")

(defun dl-dirs-expand (dirs &optional root)
  "DIRS as absolute paths under ROOT, by default `dl-dirs-root'."
  (mapcar (lambda (dir) (expand-file-name dir (or root dl-dirs-root))) dirs))

(defun dl-dirs-load-path ()
  "Absolute config and checkout directories, in `load-path' order."
  (append (dl-dirs-expand dl-dirs-config)
          (dl-dirs-expand dl-dirs-checkouts user-emacs-directory)))

(defun dl-dirs-batch-load-path ()
  "Put the config, checkout and test directories on `load-path'.
For `emacs -Q --batch -l core/dl-dirs.el -f dl-dirs-batch-load-path'."
  (setq load-path (append (dl-dirs-load-path) (dl-dirs-expand dl-dirs-tests)
                          load-path)))

(provide 'dl-dirs)
;;; dl-dirs.el ends here
