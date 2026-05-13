;;; dl-corfu.el --- completion setup -*- lexical-binding: t; -*-

(use-package corfu
  :custom
  (corfu-auto t)
  (corfu-cycle t)
  :config
  (global-corfu-mode))

;; Pretty icons for corfu
(use-package kind-icon
  :if (display-graphic-p)
  :after corfu
  :config
  (add-to-list 'corfu-margin-formatters #'kind-icon-margin-formatter))

;; Use Dabbrev with Corfu
;; (use-package dabbrev
;;   ;; Swap M-/ and C-M-/
;;   :bind (("M-/" . dabbrev-completion)
;;          ("C-M-/" . dabbrev-expand))
;;   :config
;;   (add-to-list 'dabbrev-ignored-buffer-regexps "\\` ")
;;   (add-to-list 'dabbrev-ignored-buffer-modes 'authinfo-mode)
;;   (add-to-list 'dabbrev-ignored-buffer-modes 'doc-view-mode)
;;   (add-to-list 'dabbrev-ignored-buffer-modes 'pdf-view-mode)
;;   (add-to-list 'dabbrev-ignored-buffer-modes 'tags-table-mode))


;;
;; Cape
;;
(use-package cape
  :init
  (add-to-list 'completion-at-point-functions #'cape-file)
  (add-to-list 'completion-at-point-functions #'cape-dabbrev))


(provide 'dl-corfu)
