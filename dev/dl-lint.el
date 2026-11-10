;;; dl-lint.el --- Byte-compile lint gate for the config -*- lexical-binding: t; -*-

;;; Commentary:

;; Reports, for one file, what Flymake's elisp byte-compile backend
;; would: it calls the same batch helper the Flymake child runs, with
;; the load path `lang/dl-elisp.el' hands that child.
;;
;;   bin/elisp-lint ──► emacs --batch -f dl-lint-batch FILE   (one per file,
;;        │                         │                          in parallel)
;;        │                         └─► elisp-flymake--batch-compile-for-flymake
;;        └─► exit 1 when any file prints a diagnostic
;;
;; `just lint' runs it over every tracked file; `just check' includes it.

;;; Code:

(require 'elisp-mode)
(require 'dl-path)

(defun dl-lint--line-at (file position)
  "Line number of POSITION in FILE, or 1 when POSITION is nil."
  (if (not position)
      1
    (with-temp-buffer
      (insert-file-contents file)
      (line-number-at-pos (min position (point-max))))))

(defconst dl-lint--root
  (file-name-directory
   (directory-file-name (file-name-directory (or load-file-name buffer-file-name))))
  "The config's root directory: this file lives in its dev/.")

(defconst dl-lint-excluded
  '(;; Compiling init.el loads the whole config: processes, gpg prompts,
    ;; network.  Each module it requires is checked on its own.
    "\\`init\\.el\\'"
    ;; Generated, and managed outside this repo.
    "\\`themes/noctalia-theme\\.el\\'"
    ;; Retired code and an archived spike: never loaded.
    "\\`compost/" "\\`\\.spec-driver/")
  "Regexps matching files, relative to the config root, left unchecked.")

(defun dl-lint-excluded-p (file)
  "Non-nil when FILE is one the byte-compile check leaves alone."
  (let ((relative (file-relative-name (expand-file-name file) dl-lint--root)))
    (and (not (string-prefix-p "../" relative))
         (seq-some (lambda (regexp) (string-match-p regexp relative))
                   dl-lint-excluded))))

(defconst dl-lint--output-marker ":elisp-flymake-output-start"
  "Printed by the Flymake helper before its diagnostics.")

(defun dl-lint--compile (file)
  "Run Flymake's batch byte-compile helper on FILE; return what it collects.
Each element is (MESSAGE POSITION FILL LEVEL)."
  (let* ((output (with-output-to-string
                   (elisp-flymake--batch-compile-for-flymake file)))
         (start (string-search dl-lint--output-marker output)))
    (car (read-from-string output (+ start (length dl-lint--output-marker))))))

(defun dl-lint-diagnostics (file)
  "Byte-compiler diagnostics for FILE as (LINE LEVEL MESSAGE), in line order."
  (let ((collected (dl-lint--compile file)))
    (sort (mapcar (pcase-lambda (`(,message ,position ,_fill ,level))
                    (list (dl-lint--line-at file position) level message))
                  collected)
          (lambda (a b) (< (car a) (car b))))))

(defun dl-lint-format (file diagnostic)
  "DIAGNOSTIC (LINE LEVEL MESSAGE) for FILE as FILE:LINE: LEVEL: MESSAGE.
Whitespace runs in MESSAGE collapse to one space: one diagnostic, one line."
  (pcase-let ((`(,line ,level ,message) diagnostic))
    (format "%s:%d: %s: %s" file line (substring (symbol-name level) 1)
            (string-clean-whitespace message))))

(defun dl-lint-batch ()
  "Print the diagnostics of the file named on the command line.
Exit 1 if there are any.  The file's directory and the config's Lisp
directories go on `load-path', as for Flymake's child.  An excluded
file (`dl-lint-excluded-p') exits 0 unchecked."
  (setq load-prefer-newer t)
  (let* ((file (car command-line-args-left))
         (absolute (expand-file-name file)))
    (when (dl-lint-excluded-p absolute)
      (kill-emacs 0))
    (dolist (dir (reverse (cons (file-name-directory absolute)
                                (dl-path-config-load-path))))
      (push dir load-path))
    (let ((diagnostics
           (condition-case err
               (dl-lint-diagnostics absolute)
             (error `((1 :error ,(format "lint failed: %S" err)))))))
      ;; A fresh line first: Emacs itself writes cursor-shape escapes to
      ;; stdout in batch, which would otherwise prefix the diagnostic.
      (dolist (diagnostic diagnostics)
        (princ (concat "\n" (dl-lint-format file diagnostic) "\n")))
      (kill-emacs (if diagnostics 1 0)))))

(provide 'dl-lint)
;;; dl-lint.el ends here
