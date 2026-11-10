;;; dl-emskin.el --- emskin nested-compositor client -*- lexical-binding: t; -*-

;; emskin runs Emacs inside a nested Wayland compositor and embeds native
;; apps (firefox, foot, ...) in Emacs windows.  The elisp and the `emskin'
;; binary both come from the emskin input of ~/flakes/emacs, so they match;
;; launch it without --standalone so this copy is the one that loads.
;;
;; Loaded only inside emskin: it exports XDG_SESSION_DESKTOP=emskin to the
;; Emacs it spawns.  Must load during init, because emskin auto-connects
;; from `emacs-startup-hook'.

(defun dl-emskin-inside-p ()
  "Non-nil when this Emacs was started by emskin."
  (equal (getenv "XDG_SESSION_DESKTOP") "emskin"))

(use-package emskin
  :ensure nil
  :if (dl-emskin-inside-p)
  :demand t)

(provide 'dl-emskin)
;;; dl-emskin.el ends here
