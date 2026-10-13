;;; dl-comment.el --- comment toggling on M-; -*- lexical-binding: t; -*-

;;; Commentary:

;; comment-dwim-2 is linux-only (see ~/flakes/emacs/emacs.nix); without
;; it `M-;' stays the built-in `comment-dwim'.

;;; Code:

(use-package comment-dwim-2
  :if (locate-library "comment-dwim-2")
  :bind
  ("M-;" . comment-dwim-2))

(provide 'dl-comment)
;;; dl-comment.el ends here
