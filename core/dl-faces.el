;;; dl-faces.el --- font roles + universal face customization -*- lexical-binding: t; -*-

;; Single home for face customization in this config: font roles,
;; per-face attrs, line-numbers, mode-line, org headings, flymake /
;; jinx underlines.  Other files don't set face attributes —
;; everything funnels through here.

(defvar my/known-fonts

  '(;; Monospace

     (jetbrains-mono . "JetBrainsMono NF")
     (jetbrains-mono-nerd . "JetBrainsMono Nerd Font Mono")
     (monolisa . "MonoLisa Nerd Font Mono")
     (zedmono . "ZedMono NF")
     (iosevka . "Iosevka NF")
     (monaspace-neon . "Monaspace Neon NF")
     (monaspace-argon . "Monaspace Argon NF")
     (hack . "Hack")
     (dejavu-mono . "DejaVu Sans Mono")

     ;; Sans

     (roboto . "Roboto")
     (source-sans . "Source Sans 3")
     (noto-sans . "Noto Sans")

     ;; Serif

     (et-book . "ETBembo")
     (libertinus-serif . "Libertinus Serif")
     (source-serif . "Source Serif 4")
     (noto-serif . "Noto Serif")))

(defvar my/font-roles
  '((mono . jetbrains-mono)
     (mono-alt . monolisa)
     (mono-narrow . iosevka)
     (sans . roboto)
     (serif . et-book)
     (ui . iosevka)
     (modeline . hack)
     (header . monaspace-neon)
     (tab . monaspace-argon)
     (line-number . zedmono)
     (org-body . sans)
     (org-code . mono)
     (org-heading . serif)))

(defun my/set-font-role (role font)
  "Set font ROLE to FONT and reapply fonts."
  (interactive
    (list
      (intern (completing-read "Role: " (mapcar #'car my/font-roles) nil t))
      (intern (completing-read "Font: " (mapcar #'car my/known-fonts) nil t))))
  (setf (alist-get role my/font-roles) font)
  (my/apply-fonts)
  (message "Set %s font to %s" role font))

(defun my/font-name (font)
  "Return concrete font family string for FONT symbol."
  (or (alist-get font my/known-fonts)
    (user-error "Unknown font: %S" font)))

(defun my/font-role (role)
  "Return concrete font family string for ROLE."
  (let ((font (alist-get role my/font-roles)))
    (unless font
      (user-error "Unknown font role: %S" role))
    (if (alist-get font my/font-roles)
      (my/font-role font)
      (my/font-name font))))

(defun my/set-face-font (face role &rest attrs)
  "Set FACE to use font ROLE plus ATTRS."
  (apply #'set-face-attribute
    face nil
    :family (my/font-role role)
    attrs))

(defun my/apply-lambda-line-faces ()
  (my/set-face-font 'mode-line 'modeline :height 140 :weight 'semibold)
  (my/set-face-font 'mode-line-inactive 'modeline :height 140 :weight 'regular))

(define-minor-mode my/gutter-padding-mode
  "Add a little space between gutter and buffer text."
  :init-value nil
  :lighter nil
  (setq left-margin-width (if my/gutter-padding-mode 1 0))
  (set-window-buffer nil (current-buffer)))

(add-hook 'prog-mode-hook #'my/gutter-padding-mode)
(add-hook 'text-mode-hook #'my/gutter-padding-mode)

(defun my/apply-line-number-faces ()
  "Apply stable line-number faces."
  (let ((family (my/font-role 'line-number)))
    (set-face-attribute 'line-number nil
      :family family
      :height 1.0
      :weight 'regular)
    (set-face-attribute 'line-number-current-line nil
      :inherit 'line-number
      :family family
      :height 1.0
      :weight 'regular)))

(defun my/apply-org-faces ()
  (interactive)
  (my/set-face-font 'org-document-title 'org-heading :height 160 :weight 'bold)
  (my/set-face-font 'org-level-1 'org-heading :height 140 :weight 'bold)
  (my/set-face-font 'org-level-2 'org-heading :height 125 :weight 'semibold)
  (my/set-face-font 'org-level-3 'org-heading :height 115 :weight 'regular)
  (my/set-face-font 'org-block 'org-code :height 100)
  (my/set-face-font 'org-code 'org-code :height 100)
  (my/set-face-font 'org-verbatim 'org-code :height 100))

(defun my/apply-ui-faces ()
  "Apply font roles to core UI faces."
  (let ((ui       (my/font-role 'ui))
         (modeline (my/font-role 'modeline))
         (mono     (my/font-role 'mono)))
    ;; Minibuffer / prompt / completions.
    (set-face-attribute 'minibuffer-prompt nil
      :family ui
      :height 1.0
      :weight 'semibold)

    ;; Built-in completion UI.
    (set-face-attribute 'completions-common-part nil
      :family ui
      :height 1.0
      :weight 'regular)
    (set-face-attribute 'completions-first-difference nil
      :family ui
      :height 1.0
      :weight 'semibold)

    ;; Mode line.
    (set-face-attribute 'mode-line nil
      :family modeline
      :height 1.0)
    (set-face-attribute 'mode-line-inactive nil
      :family modeline
      :height 1.0)
    (when (facep 'mode-line-active)
      (set-face-attribute 'mode-line-active nil
        :family modeline
        :height 1.0))

    ;; Header/tab/line numbers.
    (set-face-attribute 'header-line nil
      :family ui
      :height 1.0)
    (set-face-attribute 'tab-bar nil
      :family ui
      :height 1.0)
    (set-face-attribute 'tab-line nil
      :family ui
      :height 1.0)

    (my/apply-line-number-faces)))

(defvar my/font-default-height 105
  "Base font height for the default face.")

(defun my/apply-fonts (&rest _)
  "Apply all font role assignments and per-face attrs.
Variadic to fit `enable-theme-functions', which passes the theme."
  (interactive)
  (set-face-attribute 'default nil
    :family (my/font-role 'mono)
    :height my/font-default-height
    :weight 'regular)

  (set-face-attribute 'fixed-pitch nil
    :family (my/font-role 'mono)
    :height 1.0)

  (set-face-attribute 'variable-pitch nil
    :family (my/font-role 'sans)
    :height 1.0)

  (my/apply-ui-faces)
  (my/apply-org-faces))

(with-eval-after-load 'lambda-line
  (my/apply-lambda-line-faces))

;; Diagnostic underlines — straight lines, muted hues. Wave style is noisy.
(with-eval-after-load 'flymake
  (set-face-attribute 'flymake-error   nil :underline '(:style line :color "#b87575"))
  (set-face-attribute 'flymake-warning nil :underline '(:style line :color "#b89060"))
  (set-face-attribute 'flymake-note    nil :underline '(:style line :color "#6a8caf")))

(with-eval-after-load 'jinx
  ;; Grey, recedes — misspellings hint, not shout.
  (set-face-attribute 'jinx-misspelled nil :underline '(:style line :color "#7a7a7a")))

;; Apply at startup; re-apply on theme rotation so font/face attrs
;; survive `<f5>' (themes reset every face they touch).
(my/apply-fonts)
(add-hook 'enable-theme-functions #'my/apply-fonts)

(provide 'dl-faces)
;;; dl-faces.el ends here

