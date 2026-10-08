;;; dl-ediff.el --- ediff config -*- lexical-binding: t; -*-

;; Plain-window, side-by-side ediff.  Plain `ediff-*' sessions restore
;; the window layout they replaced on quit / suspend.  Magit's ediff
;; sessions restore their own (magit clears `ediff-quit-hook' locally),
;; so these hooks only serve non-magit sessions.

(defvar dl-ediff--winconf nil
  "Window configuration saved before the current ediff session.")

(defun dl-ediff--save-winconf ()
  "Save the window configuration ediff is about to replace."
  (setq dl-ediff--winconf (current-window-configuration)))

(defun dl-ediff--restore-winconf ()
  "Restore the window configuration saved before ediff started."
  (when dl-ediff--winconf
    (set-window-configuration dl-ediff--winconf)))

(use-package ediff
  :defer t
  :custom
  (ediff-diff-options "")
  (ediff-custom-diff-options "-u")
  (ediff-window-setup-function #'ediff-setup-windows-plain)
  (ediff-split-window-function #'split-window-horizontally)
  :config
  ;; Append, so the restore runs after ediff's own window cleanup
  ;; rather than being undone by it.
  (add-hook 'ediff-before-setup-hook #'dl-ediff--save-winconf)
  (add-hook 'ediff-quit-hook #'dl-ediff--restore-winconf 90)
  (add-hook 'ediff-suspend-hook #'dl-ediff--restore-winconf 90))

(provide 'dl-ediff)
;;; dl-ediff.el ends here
