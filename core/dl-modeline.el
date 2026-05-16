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

;; `lambda-line-compose' is margin-naive in two places:
;;   1. lambda-line.el:639 -- uses `window-body-width' (excludes margins),
;;      so the buffer name truncates aggressively when olivetti / vfc widen
;;      the margins.
;;   2. lambda-line.el:729 -- uses `:align-to right', which per Emacs's
;;      display spec resolves to the right edge of the text area (inside
;;      the right margin). The right segment stops short of the modeline's
;;      actual right edge.
;; Patch both via :around advice.
(with-eval-after-load 'lambda-line
  (define-advice lambda-line-compose
    (:around (orig &rest args) margin-aware)
    (let* ((win (or (get-buffer-window (current-buffer)) (selected-window)))
            (rm  (or (cdr (window-margins win)) 0))
            (result (cl-letf (((symbol-function 'window-body-width)
                                (lambda (&optional window pixelwise)
                                  (window-total-width window pixelwise))))
                      (apply orig args))))
      (when (and (> rm 0) (stringp result))
        (let ((pos 0) (len (length result)))
          (while (< pos len)
            (let ((disp (get-text-property pos 'display result)))
              (when (and (consp disp)
                      (eq (car disp) 'space)
                      (plist-get (cdr disp) :align-to))
                (let* ((plist (copy-sequence (cdr disp)))
                        (expr  (plist-get plist :align-to)))
                  (setq plist (plist-put plist :align-to `(+ ,expr ,rm)))
                  (put-text-property pos (1+ pos)
                    'display (cons 'space plist)
                    result))))
            (setq pos (1+ pos)))))
      result)))

;; lambda-line.el:520 -- the VC segment runs project/icon/branch together with
;; no spacing. Override with explicit padding around the VC symbol.
(with-eval-after-load 'lambda-line
  (define-advice lambda-line-vc-project-branch
    (:override () extra-spacing)
    (let ((backend (vc-backend buffer-file-name)))
      (concat
        (when (and buffer-file-name vc-mode)
          (let ((project-name (lambda-line-project-name)))
            (unless (string= "-" project-name)
              (concat
                (propertize " •" 'face '(:inherit fringe))
                (format " %s " project-name)))))
        (when vc-mode
          (concat
            lambda-line-vc-symbol
            " "
            (substring-no-properties vc-mode
              (+ (if (eq backend 'Hg) 2 3) 2))))))))

(use-package lambda-line
  ;;  :ensure nil
  ;;  :vc (:url "https://github.com/Lambda-Emacs/lambda-line.git")
  :custom

  ;; (lambda-line-icon-time t) ;; requires ClockFace font (see below)
  ;;(lambda-line-clockface-update-fontset "ClockFace") ;; set clock icon
  (lambda-line-position 'top) ;; Set position of status-line
  (lambda-line-abbrev t) ;; abbreviate major modes
  (lambda-line-hspace "  ")  ;; add some cushion
  (lambda-line-prefix t) ;; use a prefix symbol
  (lambda-line-prefix-padding nil) ;; no extra space for prefix
  (lambda-line-status-invert nil)  ;; no invert colors
  (lambda-line-space-top +.20)  ;; padding on top and bottom of line
  (lambda-line-space-bottom -.20)

  (lambda-line-symbol-position -0.01) ;; adjust the vertical placement of symbol
  (lambda-line-user-mode #'dl-meow-indicator) ;; show meow state in modeline(greys out when inactive)
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
  '(" " flymake-mode-line-error-counter
     flymake-mode-line-warning-counter flymake-mode-line-note-counter " "))

(customize-set-variable 'flymake-mode-line-format
  '(" " flymake-mode-line-exception flymake-mode-line-counters))

(setopt lambda-line-space-right +.15)

(set-window-fringes (selected-window) 5)

(set-frame-parameter (selected-frame) 'child-frame-border-width 30)

(provide 'dl-modeline)
;;; dl-modeline.el ends here
