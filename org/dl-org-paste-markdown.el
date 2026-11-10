;;; dl-org-paste-markdown.el --- org-paste-markdown -*- lexical-binding: t; -*-

;; (use-package org-review
;;   :bind (:map org-agenda-mode-map
;; ("C-c C-r" . org-review-insert-last-review)))

;; (add-hook 'org-mode-hook #'variable-pitch-mode)

(declare-function org-element-map "org-element")
(declare-function org-element-parse-buffer "org-element")
(declare-function org-element-property "org-element-ast")
(declare-function org-table-align "org-table")

;; PASTE AGENT SLOP AS ORG-MODE
;; can you tell an agent wrote this elisp?
(defun org-paste-markdown-as-org ()
  "Convert Markdown from the clipboard to Org using Pandoc."
  (interactive)
  (unless (executable-find "pandoc")
    (user-error "Pandoc is not available"))
  (let ((markdown (gui-get-selection 'CLIPBOARD 'UTF8_STRING)))
    (unless (and (stringp markdown) (not (string-empty-p markdown)))
      (user-error "Clipboard has no text"))
    (let ((stderr-file (make-temp-file "org-paste-pandoc-"))
          (coding-system-for-read 'utf-8-unix)
          (coding-system-for-write 'utf-8-unix))
      (unwind-protect
          (let ((org-text
                 (with-temp-buffer
                   (let ((status (call-process-region
                                  markdown nil "pandoc" nil (list t stderr-file) nil
                                  "-f" "markdown" "-t" "org")))
                     (unless (equal status 0)
                       (user-error "Pandoc failed (%s): %s" status
                                   (with-temp-buffer
                                     (insert-file-contents stderr-file)
                                     (string-trim (buffer-string)))))
                     (require 'org-element)
                     (require 'org-table)
                     ;; Work backwards so alignment cannot move a later table.
                     (dolist (pos (reverse
                                   (org-element-map (org-element-parse-buffer) 'table
                                     (lambda (table)
                                       (when (eq (org-element-property :type table) 'org)
                                         (org-element-property :begin table))))))
                       (when pos
                         (goto-char pos)
                         ;; Pandoc normally emits an Org rule; accept a
                         ;; Markdown-style header separator as well.
                         (forward-line 1)
                         (when (looking-at
                                "[ \t]*|[ \t]*:?-\\{3,\\}:?[ \t]*\\(?:|[ \t]*:?-\\{3,\\}:?[ \t]*\\)+|?[ \t]*$")
                           (replace-match "|-"))
                         (goto-char pos)
                         (org-table-align)))
                     (buffer-substring-no-properties (point-min) (point-max))))))
            (insert org-text))
        (delete-file stderr-file)))))

(provide 'dl-org-paste-markdown)
;;; dl-org-paste-markdown.el ends here
