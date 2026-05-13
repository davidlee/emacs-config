;;; dl-embark.el --- EMBARK -*- lexical-binding: t; -*-

(use-package embark
  :custom
  (prefix-help-command #'embark-prefix-help-command)
  :after (avy embark-consult)
  ;; use embark instead of which-key

  ;; https://www.matem.unam.mx/~omar/apropos-emacs.html#the-case-against-which-key-a-polemic
  (vertico-multiform-mode)
  (add-to-list 'vertico-multiform-categories '(embark-keybinding grid))

  :bind (("C-c a"  . embark-act) ; C-. ?
          ("C-;"   . embark-dwim)
          ("C-h B" . embark-bindings))
  :init
  ;; Add the option to run embark when using avy
  (defun bedrock/avy-action-embark (pt)
    (unwind-protect
      (save-excursion
        (goto-char pt)
        (embark-act))
      (select-window
        (cdr (ring-ref avy-ring 0))))
    t)

  
  ;; After invoking avy-goto-char-timer, hit "." to run embark at the next
  ;; candidate you select
  (setf (alist-get ?. avy-dispatch-alist) 'bedrock/avy-action-embark))

(use-package embark-consult
  :after (embark consult))

(provide 'dl-embark)
