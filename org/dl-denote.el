;;; dl-denote.el --- DENOTE config -*- lexical-binding: t; -*-

(require 'dl-notes-paths)

;; Bindings live in `core/dl-keymap.el' under the consolidated `C-c n …'
;; map (`my-notes-map' + sub-prefixes).  Keep this module to settings only.
(use-package denote
  :custom
  (denote-directory dl-notes-root)
  (denote-known-keywords
    '("pkm" "writing" "reading" "project" "area" "source" "slip"
       "reference" "index" "journal" "weekly" "emacs"
       "idea" "draft" "meeting" "person" "work"
       "work-relevant" "work-adjacent" "management" "technical-leadership"))
  (denote-infer-keywords t)
  (denote-sort-keywords t)
  (denote-file-type 'org)
  (denote-prompts '(title keywords)))


(defun my/denote-kill-link-to-current-file (&optional id-only)
  "Copy a denote link for the current buffer's file to the kill-ring.
With prefix arg ID-ONLY, omit the title and store the bare `[[denote:ID]]'."
  (interactive "P")
  (unless buffer-file-name (user-error "Buffer has no file"))
  (let* ((file  buffer-file-name)
         (id    (denote-retrieve-filename-identifier file))
         (type  (denote-filetype-heuristics file))
         (title (denote-retrieve-front-matter-title-value file type))
         (link  (if id-only
                  (format "[[denote:%s]]" id)
                  (format "[[denote:%s][%s]]" id (or title "")))))
    (kill-new link)
    (message "Killed: %s" link)))

(provide 'dl-denote)
