;;; dl-global-text-scale.el --- Scale text size, all buffers -*- lexical-binding: t; -*-

(defun my/global-text-scale-increase ()
  "Increase text scale globally."
  (interactive)
  (global-text-scale-adjust 1))

(defun my/global-text-scale-decrease ()
  "Decrease text scale globally."
  (interactive)
  (global-text-scale-adjust -1))

(defun my/global-text-scale-reset ()
  "Reset global text scale."
  (interactive)
  (global-text-scale-adjust 0))


(provide 'dl-global-text-scale)
;;; dl-global-text-scale.el ends here
