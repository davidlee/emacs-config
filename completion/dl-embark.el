;;; dl-embark.el --- EMBARK -*- lexical-binding: t; -*-

;; embark replaces which-key for prefix help:
;; https://www.matem.unam.mx/~omar/apropos-emacs.html#the-case-against-which-key-a-polemic
;; Its `embark-keybinding' grid layout lives with vertico multiform in
;; `dl-vertico.el'.

(declare-function ring-ref "ring")
(defvar avy-ring)
(defvar avy-dispatch-alist)
(defvar org-mode-map)

(defun dl-embark--avy-act (pt)
  "Avy dispatch action: run `embark-act' at PT, then return to the origin."
  (unwind-protect
    (save-excursion
      (goto-char pt)
      (embark-act))
    (select-window
      (cdr (ring-ref avy-ring 0))))
  t)

(use-package embark
  :custom
  (prefix-help-command #'embark-prefix-help-command)
  ;; `C-,' took over from `goto-last-change' (now `C-.' in
  ;; `dl-motion.el').  `M-.' runs `embark-dwim', whose default action
  ;; on an identifier is `xref-find-definitions', so code navigation
  ;; keeps working and other targets (URLs, files) gain an action.
  ;; `C-c a' is reserved for `org-agenda' per Policy.
  :bind (("C-,"   . embark-act)
          ("M-."   . embark-dwim)
          ("C-h B" . embark-bindings))
  :init
  ;; Org binds `C-,' to `org-cycle-agenda-files', which keeps `C-''.
  (with-eval-after-load 'org
    (keymap-set org-mode-map "C-," #'embark-act))
  ;; After invoking avy-goto-char-timer, hit "." to run embark at the
  ;; selected candidate.
  (with-eval-after-load 'avy
    (setf (alist-get ?. avy-dispatch-alist) #'dl-embark--avy-act)))

(use-package embark-consult
  :after (embark consult))

(provide 'dl-embark)
