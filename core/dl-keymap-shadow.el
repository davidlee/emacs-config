;;; dl-keymap-shadow.el --- Let a buffer's keys beat a minor mode's -*- lexical-binding: t; -*-

;; A minor mode's map beats the buffer's major-mode map, so a global
;; minor mode (meow's motion state, `pixel-scroll-precision-mode') can
;; take keys a major mode relies on.  `dl-keymap-shadow-yield' gives
;; them back in one buffer, leaving the minor mode whole elsewhere.
;;
;; A mode's map lives in one of two registries:
;;   `minor-mode-map-alist'       `define-minor-mode'; shadowed per buffer
;;                                through `minor-mode-overriding-map-alist'
;;   `emulation-mode-map-alists'  outranks the above (meow puts its state
;;                                maps here); no per-buffer override, so
;;                                the buffer gets a local copy of the list

(defun dl-keymap-shadow--without (map keys)
  "Return a copy of MAP lacking KEYS."
  (let ((copy (copy-keymap map)))
    (dolist (key keys copy)
      (keymap-unset copy key t))))

(defun dl-keymap-shadow--emulation-alist (entry)
  "The alist an `emulation-mode-map-alists' ENTRY stands for."
  (if (symbolp entry) (symbol-value entry) entry))

(defun dl-keymap-shadow--emulation-alists (mode keys)
  "`emulation-mode-map-alists' with MODE's maps lacking KEYS."
  (mapcar (lambda (entry)
            (let ((alist (dl-keymap-shadow--emulation-alist entry)))
              (if (not (assq mode alist))
                entry
                (mapcar (lambda (cell)
                          (if (eq (car cell) mode)
                            (cons mode (dl-keymap-shadow--without (cdr cell) keys))
                            cell))
                  alist))))
    emulation-mode-map-alists))

(defun dl-keymap-shadow-yield (mode &rest keys)
  "Let KEYS fall through MODE's minor-mode map in this buffer.
The buffer gets a copy of MODE's map lacking KEYS (`keymap-set'
strings), so its own bindings for them apply.  The copy is taken now:
later changes to MODE's map do not reach this buffer."
  (when-let* ((map (cdr (assq mode minor-mode-map-alist))))
    (setq-local minor-mode-overriding-map-alist
      (cons (cons mode (dl-keymap-shadow--without map keys))
        minor-mode-overriding-map-alist)))
  (when (seq-some (lambda (entry)
                    (assq mode (dl-keymap-shadow--emulation-alist entry)))
          emulation-mode-map-alists)
    (setq-local emulation-mode-map-alists
      (dl-keymap-shadow--emulation-alists mode keys))))

(provide 'dl-keymap-shadow)
;;; dl-keymap-shadow.el ends here
