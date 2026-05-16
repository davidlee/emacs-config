;;; dl-prose.el --- English, motherfucker, do you speak it? -*- lexical-binding: t; -*-


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;;   General prose-friendly behavior
;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; (use-package inflow
;;   :ensure nil
;;   :vc (:url "https://github.com/eshrh/inflow.el.git")
;;   :config
;;   (meow-normal-define-key
;;  '("`" . far-fill-paragraph)))


(when (>= emacs-major-version 30)       ; compat test
  (add-hook 'text-mode-hook 'visual-wrap-prefix-mode))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;;   Dictionary
;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(setopt dictionary-use-single-buffer t)
(setopt dictionary-server "dict.org")
(setopt dictionary-server "localhost")

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;;   Spell checking
;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Jinx: Enchanted spell-checking. Off by default; per-buffer with
;; `jinx-mode' (C-c t s), or `my/jinx-global-mode' (C-c t S) which
;; scopes a globalized toggle to `my/jinx-global-modes' only.
(use-package jinx
  :bind (("C-;"   . jinx-correct)
          ("M-$"   . jinx-correct)
          ("C-M-$" . jinx-languages))
  :custom
  (jinx-camel-modes '(prog-mode))
  (jinx-delay 0.01))

(defvar my/jinx-global-modes '(prog-mode text-mode org-mode)
  "Parent modes for `my/jinx-global-mode'; derived modes are included.")

(defun my/jinx-maybe-enable ()
  "Turn `jinx-mode' on iff current buffer derives from `my/jinx-global-modes'."
  (when (apply #'derived-mode-p my/jinx-global-modes)
    (jinx-mode 1)))

(define-minor-mode my/jinx-global-mode
  "Enable `jinx-mode' in all prog/text/org buffers, current and future."
  :global t
  :group 'jinx
  (if my/jinx-global-mode
    (progn
      (add-hook 'after-change-major-mode-hook #'my/jinx-maybe-enable)
      (dolist (buf (buffer-list))
        (with-current-buffer buf (my/jinx-maybe-enable))))
    (remove-hook 'after-change-major-mode-hook #'my/jinx-maybe-enable)
    (dolist (buf (buffer-list))
      (with-current-buffer buf
        (when (bound-and-true-p jinx-mode) (jinx-mode -1))))))

(provide 'dl-prose)
;;; dl-prose.el ends here
