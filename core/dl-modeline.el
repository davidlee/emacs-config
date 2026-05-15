;;; dl-modeline.el --- Modeline -*- lexical-binding: t; -*-
;; Modeline


;; ./elpa/lambda-line/lambda-line.el
(defun dl-modeline--prepend-user-mode (composed)
  "Prepend `lambda-line-user-mode' output to a composed lambda-line string.
Applied at the `lambda-line-compose' return — injecting earlier (e.g.
into `lambda-line-mode-name') gets wiped because compose calls
`(propertize SEGMENT 'face …)' which strips per-character faces set by
the user-mode renderer (e.g. `meow-indicator')."
  (if (functionp lambda-line-user-mode)
      (concat (funcall lambda-line-user-mode) composed)
    composed))

(use-package lambda-line
  ;;  :ensure nil
  ;;  :vc (:url "https://github.com/Lambda-Emacs/lambda-line.git")
  :custom
  (lambda-line-icon-time t) ;; requires ClockFace font (see below)
  (lambda-line-clockface-update-fontset "ClockFace") ;; set clock icon
  (lambda-line-position 'top) ;; Set position of status-line
  (lambda-line-abbrev t) ;; abbreviate major modes
  (lambda-line-hspace "             ")  ;; add some cushion
  (lambda-line-prefix t) ;; use a prefix symbol
  (lambda-line-prefix-padding nil) ;; no extra space for prefix
  (lambda-line-status-invert nil)  ;; no invert colors
  (lambda-line-space-top +.20)  ;; padding on top and bottom of line
  (lambda-line-space-bottom -.20)

  (lambda-line-symbol-position -0.01) ;; adjust the vertical placement of symbol
  (lambda-line-user-mode #'meow-indicator) ;; show meow state in modeline
  :config
  (advice-add 'lambda-line-compose :filter-return
    #'dl-modeline--prepend-user-mode)
  ;; activate lambda-line
  (lambda-line-mode)
  ;; set divider line in footer
  (when (eq lambda-line-position 'top)
    (setq-default mode-line-format (list "%_"))
    (setq mode-line-format (list "%_"))))

(customize-set-variable 'flymake-mode-line-counter-format
  '(" " flymake-mode-line-error-counter flymake-mode-line-warning-counter flymake-mode-line-note-counter " »"))

(customize-set-variable 'flymake-mode-line-format
  '(" " flymake-mode-line-exception flymake-mode-line-counters))

(setopt lambda-line-space-right +.00)
(provide 'dl-modeline)
;;; dl-modeline.el ends here
