;;; dl-insert-elisp-header.el --- Insert elisp header/footer if missing -*- lexical-binding: t; -*-

(defun my/insert-elisp-header-footer-if-missing (&optional description)
  "Insert a standard Emacs Lisp header/footer if missing.

The file and feature names are derived from `buffer-file-name'.
When called interactively, prompt for DESCRIPTION if the header is absent."
  (interactive)
  (unless buffer-file-name
    (user-error "Buffer is not visiting a file"))

  (let* ((file (file-name-nondirectory buffer-file-name))
          (base (file-name-sans-extension file))
          (feature base)
          (has-header nil)
          (has-provide nil)
          (has-closing-comment nil))
    (save-excursion
      (goto-char (point-min))
      (setq has-header
        (looking-at-p
          (regexp-quote (format ";;; %s ---" file))))

      (goto-char (point-min))
      (setq has-provide
        (re-search-forward
          (format "^(provide '%s)" (regexp-quote feature))
          nil t))

      (goto-char (point-min))
      (setq has-closing-comment
        (re-search-forward
          (format "^;;; %s ends here" (regexp-quote file))
          nil t))

      (unless has-header
        (let ((desc (or description
                      (read-string "Description: " "DESCR"))))
          (goto-char (point-min))
          (insert
            (format ";;; %s --- %s -*- lexical-binding: t; -*-\n\n"
              file desc))))

      (goto-char (point-max))

      (unless has-provide
        (unless (bolp)
          (insert "\n"))
        (insert
          (format "\n(provide '%s)\n" feature)))

      (unless has-closing-comment
        (unless (bolp)
          (insert "\n"))
        (insert
          (format ";;; %s ends here\n" file))))))
;; (global-set-key (kbd "C-c h") #'my/insert-elisp-header-footer-if-missing)

(provide 'dl-insert-elisp-header)
;;; dl-insert-elisp-header.el ends here
