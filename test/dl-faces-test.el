;;; dl-faces-test.el --- ert tests for dl-faces -*- lexical-binding: t; -*-

;; Run: `just check' (dl-test scans test/), or M-x ert RET dl-faces RET.

(require 'ert)
(require 'org)                        ; dl-faces sets org faces at load
(require 'dl-faces)
(require 'dl-umbriel-buffer)

(ert-deftest dl-faces/loads-before-anything-defines-hl-line ()
  "Applying faces at load needs `hl-line', so dl-faces must load it itself.
Runs in a fresh Emacs: in this one, other tests have already loaded it."
  (let* ((core (file-name-directory (locate-library "dl-faces")))
         (form (prin1-to-string
                '(progn
                   (setq load-prefer-newer t)
                   (require 'org)
                   (require 'dl-faces)
                   (princ (if (facep 'hl-line) "yes" "no")))))
         (output (with-output-to-string
                   (with-current-buffer standard-output
                     (call-process (expand-file-name invocation-name invocation-directory)
                                   nil t nil "-Q" "--batch" "-L" core "--eval" form)))))
    (should (string-suffix-p "yes" output))))

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

(ert-deftest dl-faces/umbriel-pills-sit-below-their-sources-and-survive-recalc ()
  "The muted name and layout pills are darker than the colours they derive from."
  ;; White: batch `color-name-to-rgb' snaps to the nearest terminal colour.
  (let ((source "#ffffff"))
    (cl-letf (((symbol-function 'face-attribute)
               (let ((real (symbol-function 'face-attribute)))
                 (lambda (face &rest args)
                   (if (memq face '(default success))
                       source
                     (apply real face args)))))
              ((symbol-function 'color-defined-p) #'always))
      (my/shade-umbriel-pills))
    (dolist (face '(dl-umbriel-buffer-workspace-name dl-umbriel-buffer-layout))
      (custom-theme-recalc-face face)
      (should (< (dl-faces-test--red face)
                 (car (color-values-from-color-spec source)))))))

(ert-deftest dl-faces/nerd-icons-fall-back-to-the-mono-font ()
  "A face whose own font lacks the icons still finds them in the mono font."
  ;; The rule, not its effect: batch has no fonts to resolve.
  (let (rule)
    (cl-letf (((symbol-function 'set-fontset-font)
               (lambda (&rest args) (setq rule args))))
      (my/apply-icon-fontset))
    (pcase-let ((`(,fontset (,first . ,last) ,font) rule))
      (should (eq t fontset))
      (should (<= first #xF0208 last))
      (should (equal (my/font-role 'mono)
                     (symbol-name (font-get font :family)))))))

;; Font roles

(ert-deftest dl-faces/every-role-names-a-known-font ()
  "Each role reaches a family, directly or through another role."
  (pcase-dolist (`(,role . ,_) my/font-roles)
    (should (stringp (my/font-role role)))))

(ert-deftest dl-faces/ui-text-and-org-headings-use-their-own-cuts ()
  "Small UI text gets the text cut of Inter, headings the display cut."
  (should (equal (my/font-role 'ui) "Inter"))
  (should (equal (my/font-role 'org-heading) "Inter Display")))

;; The legend in *umbriel*'s header aligns by columns, so it needs a mono font.
(ert-deftest dl-faces/headers-and-tab-bar-are-mono-and-tab-line-fits-more ()
  "Headers and the tab bar stay fixed-width; the tab line is proportional."
  (should (equal (my/font-role 'header) (my/font-role 'mono)))
  (should (equal (my/font-role 'tab) (my/font-role 'mono)))
  (should (equal (my/font-role 'tab-line) "Inter")))

(defconst dl-faces-test--chrome
  '((header header-line header-line-inactive)
    (tab tab-bar tab-bar-tab tab-bar-tab-inactive)
    (tab-line tab-line tab-line-tab tab-line-tab-current
              tab-line-tab-inactive tab-line-tab-special))
  "Which faces each chrome role must set, independent of the code's table.")

(ert-deftest dl-faces/chrome-roles-each-set-only-their-own-faces ()
  "Changing one chrome role moves its faces, active and inactive, and no others.
Themes leave some of these with no family, so they would draw in `default'."
  (unwind-protect
      (pcase-dolist (`(,role . ,_) dl-faces-test--chrome)
        (let ((my/font-roles (cons (cons role 'hack)
                                   (assq-delete-all role
                                                    (copy-alist my/font-roles)))))
          (my/apply-ui-faces)
          (pcase-dolist (`(,owner . ,faces) dl-faces-test--chrome)
            (dolist (face faces)
              (should (eq (eq owner role)
                          (equal (face-attribute face :family nil) "Hack")))))))
    (my/apply-ui-faces)))

;; A role, not a family: the role can change while org buffers are open.
(ert-deftest dl-faces/org-body-role-draws-org-text-and-nothing-else ()
  "Org buffers draw plain text in the `org-body' role; others stay on `default'."
  (with-temp-buffer
    (org-mode)
    (should (member 'dl-faces-org-body (alist-get 'default face-remapping-alist))))
  (with-temp-buffer
    (text-mode)
    (should-not (alist-get 'default face-remapping-alist)))
  (unwind-protect
      (let ((my/font-roles (cons '(org-body . hack) my/font-roles)))
        (my/apply-org-faces)
        (should (equal (face-attribute 'dl-faces-org-body :family nil) "Hack")))
    (my/apply-org-faces)))

(ert-deftest dl-faces/visiting-a-buffer-leaves-global-faces-alone ()
  "Faces are global: mode hooks must not reapply them per buffer."
  (let ((applied 0))
    (cl-letf (((symbol-function 'my/apply-fonts)
               (lambda (&rest _) (cl-incf applied))))
      (with-temp-buffer
        (prog-mode)
        (display-line-numbers-mode 1)))
    (should (zerop applied))))

(provide 'dl-faces-test)
;;; dl-faces-test.el ends here
