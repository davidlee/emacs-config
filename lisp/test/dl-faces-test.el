;;; dl-faces-test.el --- ert tests for dl-faces -*- lexical-binding: t; -*-

;; Run: `just check' (dl-test scans lisp/test), or M-x ert RET dl-faces RET.

(require 'ert)
(require 'org)                        ; dl-faces sets org faces at load
(require 'dl-faces)
(require 'dl-umbriel-buffer)

(ert-deftest dl-faces/line-numbers-pad-the-text-while-shown ()
  "Text is prefixed off the line numbers only while they are displayed."
  (with-temp-buffer
    (display-line-numbers-mode 1)
    (should (equal line-prefix " "))
    (should (equal wrap-prefix " "))
    (display-line-numbers-mode -1)
    (should-not line-prefix)
    (should-not wrap-prefix)))

(ert-deftest dl-faces/visual-wrap-continuation-keeps-the-pad ()
  "List-item continuation lines align with their first line's text."
  (with-temp-buffer
    (text-mode)
    (visual-wrap-prefix-mode 1)
    (insert "- item\n")
    (display-line-numbers-mode 1)
    (jit-lock-fontify-now)
    (should (equal (get-text-property 1 'wrap-prefix)
                   '(space :align-to (3 . width))))
    (display-line-numbers-mode -1)
    (jit-lock-fontify-now)
    (should (equal (get-text-property 1 'wrap-prefix)
                   '(space :align-to (2 . width))))))

(ert-deftest dl-faces/line-number-faces-survive-theme-recalc ()
  "Line-number alignment settings outlive a theme recalculation of the faces.
Themes (and `spacious-padding') recalc faces on new frames; ad-hoc
`set-face-attribute' edits are wiped, mismatching the two faces' families."
  (my/apply-line-number-faces)
  (let ((family (my/font-role 'line-number)))
    (dolist (face '(line-number line-number-current-line))
      (custom-theme-recalc-face face)
      (should (equal (face-attribute face :family nil) family))
      (should (eq (face-attribute face :weight nil) 'regular)))))

(ert-deftest dl-faces/graphical-frame-refires-theme-hooks ()
  "A new graphical frame re-runs `enable-theme-functions' for enabled themes.
A daemon's first frame is a terminal, where theme-derived colours are
unresolved; the hooks are idempotent, so they re-run once a real frame exists."
  (let* ((seen nil)
         (enable-theme-functions (list (lambda (theme) (push theme seen))))
         (custom-enabled-themes '(alpha beta)))
    (cl-letf (((symbol-function 'display-graphic-p) (lambda (&rest _) nil)))
      (my/refire-theme-hooks-on-graphical-frame (selected-frame))
      (should-not seen))
    (cl-letf (((symbol-function 'display-graphic-p) (lambda (&rest _) t)))
      (my/refire-theme-hooks-on-graphical-frame (selected-frame))
      (should (equal (sort seen #'string<) '(alpha beta))))))


(defun dl-faces-test--red (face)
  "The red channel of FACE's background."
  (car (color-values-from-color-spec (face-attribute face :background nil))))

(ert-deftest dl-faces/umbriel-workspace-shades-step-darker-and-survive-recalc ()
  "Rows sit below `default', the heading below the rows, across a recalc."
  ;; White: batch `color-name-to-rgb' snaps to the nearest terminal colour.
  (let ((default "#ffffff"))
    (cl-letf (((symbol-function 'face-attribute)
               (let ((real (symbol-function 'face-attribute)))
                 (lambda (face &rest args)
                   (if (eq face 'default)
                       default
                     (apply real face args)))))
              ((symbol-function 'color-defined-p) #'always))
      (my/shade-umbriel-active-workspace))
    (dolist (face '(dl-umbriel-buffer-active-workspace
                    dl-umbriel-buffer-active-workspace-window))
      (custom-theme-recalc-face face)
      (should (eq t (face-attribute face :extend nil))))
    (should (< (dl-faces-test--red 'dl-umbriel-buffer-active-workspace)
               (dl-faces-test--red 'dl-umbriel-buffer-active-workspace-window)
               (car (color-values-from-color-spec default))))))

(provide 'dl-faces-test)
;;; dl-faces-test.el ends here
