;;; elisp-locate-paren-error.el --- JSON paren locator for agents -*- lexical-binding: t; -*-

(require 'json)

(defun agent-parens--line-text ()
  (buffer-substring-no-properties
    (line-beginning-position)
    (line-end-position)))

(defun agent-parens--pos-info (pos)
  (save-excursion
    (goto-char pos)
    `((pos . ,pos)
       (line . ,(line-number-at-pos))
       (column . ,(current-column))
       (char . ,(unless (eobp) (char-to-string (char-after))))
       (text . ,(agent-parens--line-text))
       (toplevel . ,(agent-parens--toplevel-info pos)))))

(defun agent-parens--toplevel-info (pos)
  (save-excursion
    (goto-char pos)
    (condition-case nil
      (progn
        (beginning-of-defun)
        (let ((start (point)))
          (end-of-defun)
          `((start . ,start)
             (end . ,(point))
             (start_line . ,(save-excursion
                              (goto-char start)
                              (line-number-at-pos)))
             (end_line . ,(line-number-at-pos)))))
      (error nil))))

(defun agent-parens--open-stack ()
  "Return currently open parens at EOF, innermost first if available."
  (save-excursion
    (goto-char (point-min))
    (let* ((state (parse-partial-sexp (point-min) (point-max)))
            ;; In modern Emacs parser state, slot 9 is the stack of open paren positions.
            ;; Slot 1 is the innermost containing list, used as a fallback.
            (positions (or (nth 9 state)
                         (when (nth 1 state)
                           (list (nth 1 state))))))

      ;; Most useful for repair is the innermost opener first.
      (mapcar #'agent-parens--pos-info (reverse positions)))))

(defun agent-parens--report ()
  (emacs-lisp-mode)
  (condition-case err
    (save-excursion
      (goto-char (point-min))
      (check-parens)
      (let ((stack (agent-parens--open-stack)))
        (if stack
          `((ok . :json-false)
             (kind . "eof-with-open-parens")
             (message . "Buffer ends with unclosed parens")
             (open_stack . ,(vconcat stack)))
          `((ok . t)))))
    (error
      `((ok . :json-false)
         (kind . "check-parens")
         (message . ,(error-message-string err))
         (error . ,(agent-parens--pos-info (point)))
         (open_stack . ,(vconcat
                          (condition-case nil
                            (agent-parens--open-stack)
                            (error nil))))))))

(defun agent-parens-check-file (file)
  (with-temp-buffer
    (insert-file-contents file)
    (let ((report (agent-parens--report)))
      (princ (json-encode report))
      (terpri)
      (unless (eq t (alist-get 'ok report))
        (kill-emacs 2)))))

(let ((file (car command-line-args-left)))
  (unless file
    (princ "{\"ok\":false,\"message\":\"usage: emacs -Q --batch -l tools/elisp-locate-paren-error.el FILE\"}\n")
    (kill-emacs 64))
  (agent-parens-check-file file))

(provide 'dl-elisp-locate-paren-error)
;;; dl-elisp-locate-paren-error.el ends here
