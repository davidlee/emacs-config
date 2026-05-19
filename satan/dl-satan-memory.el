;;; dl-satan-memory.el --- SATAN memory substrate aggregator -*- lexical-binding: t; -*-

;; Single entry point for the canonical-handle memory substrate.  Pulls
;; in the five `dl-satan-memory-*' submodules + the two tool modules
;; (`dl-satan-tools-memory', `dl-satan-tools-bough') and exposes a small
;; `my/satan-memory-*' interactive surface for inspecting the store from
;; Emacs.  See `~/.emacs.d/satan/memory.design.md' §11.

(require 'cl-lib)
(require 'dl-satan-memory-grammar)
(require 'dl-satan-memory-canon)
(require 'dl-satan-memory-evidence)
(require 'dl-satan-memory-store)
(require 'dl-satan-memory-migrate)
(require 'dl-satan-tools-bough)
(require 'dl-satan-tools-memory)

(defun my/satan-memory-resonate (handles)
  "Resonate against HANDLES (whitespace-separated minibuffer input).
Pop a `*satan-memory*' buffer listing the top matches as
TRACE-ID  SCORE  MATCHED-HANDLES."
  (interactive (list (split-string (read-string "Cue handles: "))))
  (pcase (dl-satan-memory-store-resonate :cue-handles handles)
    (`(ok . ,rows)
     (let ((buf (get-buffer-create "*satan-memory*")))
       (with-current-buffer buf
         (let ((inhibit-read-only t))
           (erase-buffer)
           (special-mode)
           (insert (format "resonate: %s\n\n" (string-join handles " ")))
           (if (null rows)
               (insert "(no matches)\n")
             (dolist (row rows)
               (insert (format "%s  %.3f  %s\n"
                               (plist-get row :trace_id)
                               (plist-get row :score)
                               (string-join (plist-get row :matched_handles)
                                            " ")))))))
       (pop-to-buffer buf)))
    (`(error . ,msg) (error "resonate failed: %s" msg))))

(defun my/satan-memory-show (trace-id)
  "Pretty-print the trace identified by TRACE-ID into `*satan-memory*'."
  (interactive (list (read-string "Trace id: ")))
  (pcase (dl-satan-memory-store-show trace-id)
    (`(ok . nil) (message "no trace: %s" trace-id))
    (`(ok . ,row)
     (let ((buf (get-buffer-create "*satan-memory*")))
       (with-current-buffer buf
         (let ((inhibit-read-only t))
           (erase-buffer)
           (special-mode)
           (insert (pp-to-string row))))
       (pop-to-buffer buf)))
    (`(error . ,msg) (error "show failed: %s" msg))))

(defun my/satan-memory-status ()
  "Report substrate status: grammar version + migration applied/pending."
  (interactive)
  (let* ((rows (dl-satan-memory-migrate-status))
         (by-status (lambda (s) (cl-count-if (lambda (r)
                                               (eq (plist-get r :status) s))
                                             rows))))
    (message
     "memory: db=%s grammar=v%d migrations=%d applied, %d pending, %d tampered, %d missing"
     dl-satan-memory-store-database
     dl-satan-memory-grammar-current-version
     (funcall by-status 'applied)
     (funcall by-status 'pending)
     (funcall by-status 'tampered)
     (funcall by-status 'missing))))

(provide 'dl-satan-memory)
;;; dl-satan-memory.el ends here
