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
;; Directories are relative to `user-emacs-directory'.

;;; Code:

(defconst dl-dirs-config
  '("core" "editing" "completion" "apps" "org" "dev" "lang")
  "My own Lisp directories.")

(defconst dl-dirs-checkouts
  '("checkout" "elpa/org-timeblock" "~/dev/satan/satan")
  "External checkout Lisp directories.")

(defconst dl-dirs-tests '("test")
  "Directories holding ERT files and their helpers.")

(defun dl-dirs-expand (dirs)
  "DIRS as absolute paths under `user-emacs-directory'."
  (mapcar (lambda (dir) (expand-file-name dir user-emacs-directory)) dirs))

(defun dl-dirs-load-path ()
  "Absolute config and checkout directories, in `load-path' order."
  (dl-dirs-expand (append dl-dirs-config dl-dirs-checkouts)))

(defun dl-dirs-batch-load-path ()
  "Put the config, checkout and test directories on `load-path'.
For `emacs -Q --batch -l core/dl-dirs.el -f dl-dirs-batch-load-path'."
  (setq load-path (append (dl-dirs-load-path) (dl-dirs-expand dl-dirs-tests)
                          load-path)))

(provide 'dl-dirs)
;;; dl-dirs.el ends here
