;;; dl-declare.el --- Generate declare-function forms from warnings -*- lexical-binding: t; -*-

;; Turns "the function ‘foo’ is not known to be defined" warnings into
;; `declare-function' forms.  `dl-declare-insert-from-flymake' reads the
;; current buffer's Flymake diagnostics; the rest is pure.
;;
;; A declaration silences the warning, it does not fix it.  Prefer
;; `(require ...)' / `:commands' when the file should be loaded anyway;
;; declare only deliberate soft dependencies.

(require 'flymake)

(defconst dl-declare--warning-regexp
  "the function [‘`']\\([^’']+\\)[’'] is not known to be defined"
  "Matches the byte-compiler's undefined-function warning; group 1 is the name.")

(defun dl-declare-undefined-functions (messages)
  "Sorted, unique function symbols named by undefined-function MESSAGES."
  (sort (delete-dups
         (delq nil
               (mapcar (lambda (message)
                         (when (string-match dl-declare--warning-regexp message)
                           (intern (match-string 1 message))))
                       messages)))
        #'string<))

(defun dl-declare--defining-file (function)
  "Name, without directory or extension, of the file defining FUNCTION, or nil."
  (when-let* ((file (or (symbol-file function 'defun)
                        (let ((definition (and (fboundp function)
                                               (symbol-function function))))
                          (and (autoloadp definition) (nth 1 definition))))))
    (file-name-sans-extension (file-name-nondirectory file))))

(defun dl-declare-form (function)
  "A `declare-function' form string for FUNCTION, as text."
  (if-let* ((file (dl-declare--defining-file function)))
      (format "(declare-function %s \"%s\")" function file)
    (format "(declare-function %s \"\") ; FIXME: defining file unknown" function)))

(defun dl-declare-insert-from-flymake ()
  "Insert `declare-function' forms for this buffer's undefined-function warnings."
  (interactive)
  (let ((functions (dl-declare-undefined-functions
                    (mapcar #'flymake-diagnostic-text (flymake-diagnostics)))))
    (if functions
        (progn (insert (mapconcat #'dl-declare-form functions "\n") "\n")
               (message "Declared %d function(s)" (length functions)))
      (user-error "No undefined-function warnings in this buffer"))))

(provide 'dl-declare)
;;; dl-declare.el ends here
