;;; dl-sediment.el --- sediment -*- lexical-binding: t; -*-

;; At compile time too, so the compiler finds the `require' below.
(eval-and-compile
  (add-to-list 'load-path "/workspace/sediment/emacs"))
(require 'sediment)
(setq sediment-cli '("/workspace/sediment/scripts/sediment"))

(provide 'dl-sediment)
;;; dl-sediment.el ends here
