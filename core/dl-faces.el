;;; dl-faces.el --- font roles + universal face customization -*- lexical-binding: t; -*-

(require 'cl-lib)
(require 'color)

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
    (geist . "Geist Mono")

    ;; Sans

    (inter . "Inter Regular")
    (roboto . "Roboto")
    (source-sans . "Source Sans 3")
    (noto-sans . "Noto Sans")
    (geist-sans . "Geist Medium")

    ;; Serif

    (et-book . "ETBembo")
    (libertinus-serif . "Libertinus Serif")
    (libertine . "Linux Libertine O")
    (source-serif . "Source Serif 4")
    (noto-serif . "Noto Serif")))

(defvar my/font-roles
  '((mono . jetbrains-mono)
    (mono-alt . monolisa)
    (mono-narrow . iosevka)
    (sans . roboto)
    (serif . inter)
    (ui . inter)
    (modeline . geist)
    (header . monaspace-neon)
    (tab . monaspace-argon)
    (line-number . zedmono)
    ;; (org-body . et-book)
    (org-body . monolisa)
    (org-code . mono)
    (org-heading . inter)))

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

(defun my/refresh-window-margins ()
  "Re-apply margin settings of the current buffer in windows showing it.
Margins take effect on `set-window-buffer'.  Never pulls the buffer into
the selected window: hidden work buffers (formatter scratch, background
visits) run mode hooks too, and must not pop up."
  (dolist (window (get-buffer-window-list nil nil t))
    (set-window-buffer window (current-buffer))))

(defun my/pad-line-numbers ()
  "Space the text off the line numbers while `display-line-numbers-mode' is on.
`line-prefix' is drawn after the number; margins sit outside it.
`wrap-prefix' keeps continuation lines aligned.  `visual-wrap-prefix-mode'
puts its own `wrap-prefix' text properties on prefixed lines (list items),
which override the variable, so it gets the pad as extra indent."
  (let ((pad (and display-line-numbers-mode " ")))
    (setq-local line-prefix pad
                wrap-prefix pad
                visual-wrap-extra-indent (if pad 1 0))
    (when (bound-and-true-p visual-wrap-prefix-mode)
      (jit-lock-refontify))))

(add-hook 'display-line-numbers-mode-hook #'my/pad-line-numbers)
(add-hook 'display-line-numbers-mode-hook #'my/apply-fonts) ;; hopefully fix spacing issue with ruler
(add-hook 'prog-mode-hook #'my/apply-fonts)

(defun my/apply-line-number-faces ()
  "Give both line-number faces one family, height and weight.
Declared in the `user' theme, not via `set-face-attribute': theme specs
on these faces (e.g. `spacious-padding') recalc on new frames and wipe
ad-hoc edits, leaving the two faces in different families (misaligned)."
  (interactive)
  (let ((family (my/font-role 'line-number)))
    (custom-theme-set-faces 'user
                            `(line-number ((t :family ,family :height 1.0 :weight regular)))
                            `(line-number-current-line
                              ((t :inherit line-number :family ,family :height 1.0 :weight regular))))))

(defvar my/org-face-styles
  '((org-document-title  :role org-heading :height 1.6  :weight semibold)
    (org-level-1        :role org-heading :height 1.4  :weight semibold)
    (org-level-2        :role org-heading :height 1.25 :weight semibold)
    (org-level-3        :role org-heading :height 1.15 :weight regular)
    (org-level-4        :role org-heading :height 1.1  :weight regular)
    (org-level-5        :role org-heading :height 1.05 :weight regular)
    (org-level-6        :role org-heading :height 1.0  :weight regular)
    (org-level-7        :role org-heading :height 1.0  :weight regular)
    (org-level-8        :role org-heading :height 1.0  :weight regular)
    (org-block          :role org-code    :height 1.0)
    (org-code           :role org-code    :height 1.0)
    (org-verbatim       :role org-code    :height 1.0))
  "Per-face style for org. Each entry: (FACE :role ROLE [ATTRS...]).
Heights must be floats so they multiply through `default' and scale
with `text-scale-adjust' (C-mousewheel).  Edit and call
`my/apply-org-faces' to re-apply.")

;; face for hl-line - have a darker thingy
(defun my/apply-hl-line-faces ()
  (let ((bg (face-attribute 'default :background nil t)))
    (when (color-defined-p bg)
      (set-face-background 'hl-line (color-darken-name bg 25)))))

(defun my/apply-org-faces ()
  "Apply `my/org-face-styles' to org faces."
  (interactive)
  (pcase-dolist (`(,face . ,plist) my/org-face-styles)
    (let ((role (plist-get plist :role))
          (attrs (copy-sequence plist)))
      (cl-remf attrs :role)
      (apply #'my/set-face-font face role attrs)))
  (setq org-todo-keyword-faces
        '( ("TODO"     . (:foreground "#f38ba8" :weight bold))
           ("NEXT"     . (:foreground "#fab387" :weight bold))
           ("STARTED"  . (:foreground "#a6e3a1" :weight bold))
           ("WAITING"  . (:foreground "#f9e2af"))
           ("MAYBE"    . (:foreground "#cba6f7"))
           ("DONE"     . (:foreground "#6c7086"))
           ("CANCELED" . (:foreground "#585b70"))
           ("MOVED"    . (:foreground "#89b4fa"))))
  (setq org-modern-todo-faces
        '( ("TODO"     :background "#f38ba8" :foreground "#1e1e2e")
           ("NEXT"     :background "#fab387" :foreground "#1e1e2e")
           ("STARTED"  :background "#a6e3a1" :foreground "#1e1e2e")
           ("WAITING"  :background "#f9e2af" :foreground "#1e1e2e")
           ("MAYBE"    :background "#cba6f7" :foreground "#1e1e2e")
           ("DONE"     :background "#45475a" :foreground "#6c7086")
           ("CANCELED" :background "#313244" :foreground "#585b70")
           ("MOVED"    :background "#89b4fa" :foreground "#1e1e2e"))))

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

(defconst my/nerd-icon-range '(#xF0001 . #xF1AF0)
  "The codepoints of Nerd Fonts' Material Design icons.")

(defun my/apply-icon-fontset ()
  "Find Nerd Font icons in the mono font, for faces whose own font lacks them."
  (set-fontset-font t my/nerd-icon-range
                    (font-spec :family (my/font-role 'mono))))

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

  (my/apply-icon-fontset)
  (my/apply-ui-faces)
  (my/apply-org-faces)
  (my/apply-hl-line-faces))

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

(defun my/apply-meow-indicator-faces (&rest _)
  "Paint meow state indicators as coloured blocks.
Re-applied after theme load so rotating themes can't clobber them."
  (pcase-dolist (`(,face ,bg) '((meow-normal-indicator "#a6e3a1")
                                (meow-insert-indicator "#f38ba8")
                                (meow-motion-indicator "#89b4fa")
                                (meow-keypad-indicator "#f9e2af")
                                (meow-beacon-indicator "#cba6f7")))
    (set-face-attribute face nil
                        :background bg :foreground "black" :weight 'bold)))

(with-eval-after-load 'meow
  (my/apply-meow-indicator-faces)
  (add-hook 'enable-theme-functions #'my/apply-meow-indicator-faces))

(with-eval-after-load 'treesit-fold
  (set-face-attribute 'treesit-fold-replacement-face nil
                      :foreground "#808080"
                      :box nil
                      :weight 'bold))

;; Apply at startup; re-apply on theme rotation so font/face attrs
;; survive `<f5>' (themes reset every face they touch).
(my/apply-fonts)

(add-hook 'enable-theme-functions #'my/apply-fonts)

(defun my/blend-borders-into-background (&rest _)
  "Paint the fringe as `default' and window dividers a shade lighter.
Declared in the `user' theme, not via `set-face-*': theme specs (e.g.
`foxglove-dark' sets `window-divider') recalc on new frames and wipe ad-hoc
edits.  Re-run on every theme change.  Read before a frame exists (daemon
start) the background is `unspecified-bg', so wait for a real colour."
  (let ((bg (face-attribute 'default :background nil t)))
    (when (color-defined-p bg)
      (let ((divider (color-lighten-name bg 4)))
        (custom-theme-set-faces
         'user
         `(fringe ((t :background ,bg)))
         `(window-divider ((t :foreground ,divider)))
         `(window-divider-first-pixel ((t :foreground ,divider)))
         `(window-divider-last-pixel ((t :foreground ,divider))))))))

(my/blend-borders-into-background)
(add-hook 'enable-theme-functions #'my/blend-borders-into-background)

(defun my/shade-umbriel-active-workspace (&rest _)
  "Shade an active workspace in *umbriel*: rows below `default', heading lower.
Declared in the `user' theme, and so re-run on theme change, for the
reasons `my/blend-borders-into-background' gives.  A `user' spec replaces
the defface spec, so these carry the whole face."
  (let ((bg (face-attribute 'default :background nil t)))
    (when (color-defined-p bg)
      (custom-theme-set-faces
       'user
       `(dl-umbriel-buffer-active-workspace-window
         ((t :background ,(color-darken-name bg 20) :extend t)))
       `(dl-umbriel-buffer-active-workspace
         ((t :inherit magit-section-heading
             :background ,(color-darken-name bg 40) :extend t)))))))

(my/shade-umbriel-active-workspace)
(add-hook 'enable-theme-functions #'my/shade-umbriel-active-workspace)

(defun my/shade-umbriel-pills (&rest _)
  "Shade *umbriel*'s pills: an inactive name and every layout.
The name is a dull `success', a layout's background a dark `default'.
Declared in the `user' theme, and so re-run on theme change, for the
reasons `my/blend-borders-into-background' gives."
  (let ((accent (face-attribute 'success :foreground nil t))
        (fg (face-attribute 'default :foreground nil t)))
    (when (and (color-defined-p accent) (color-defined-p fg))
      (custom-theme-set-faces
       'user
       `(dl-umbriel-buffer-workspace-name
         ((t :inherit default
             :background ,(color-darken-name
                           (color-desaturate-name accent 50) 50))))
       `(dl-umbriel-buffer-layout
         ((t :background ,(color-darken-name fg 70))))))))

(my/shade-umbriel-pills)
(add-hook 'enable-theme-functions #'my/shade-umbriel-pills)

(defun my/refire-theme-hooks-on-graphical-frame (frame)
  "Re-run `enable-theme-functions' for the enabled themes once FRAME is graphical.
A daemon starts on a terminal frame, where theme-derived colours (`default'
bg/fg, `unspecified-bg') are unresolved, so hooks that read them skip or
misread at the first theme load.  They are idempotent, so re-run them when
a real frame appears."
  (when (display-graphic-p frame)
    (with-selected-frame frame
      (dolist (theme custom-enabled-themes)
        (run-hook-with-args 'enable-theme-functions theme)))))

(add-hook 'after-make-frame-functions #'my/refire-theme-hooks-on-graphical-frame)

(provide 'dl-faces)
;;; dl-faces.el ends here
