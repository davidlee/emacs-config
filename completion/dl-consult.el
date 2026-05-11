;;; dl-consult.el --- CONSULT -*- lexical-binding: t; -*-

(use-package consult
  :bind (("C-c s l" . consult-line)
          ("C-x b" . consult-buffer)
          ("M-y" . consult-yank-pop)
          ("M-g g" . consult-goto-line)
          ("M-g i" . consult-imenu)
          ("M-s r" . consult-ripgrep)
          ("C-c s g" . consult-ripgrep)
          ("C-c s f" . consult-find)
          ("C-c s b" . consult-buffer)
          ("C-c s o" . consult-outline)
          ("C-c s m" . consult-mark)
          ("C-c s i" . consult-imenu)))

(provide 'dl-consult)
