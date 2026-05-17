;;; dl-window.el --- Window helpers -*- lexical-binding: t; -*-

;; Window-management defuns, modes, and the transpose-frame wrapper.
;; Bindings live in `core/dl-keymap.el' (window-map) and
;; `core/dl-keybind.el' (ergonomic chords).

(require 'cl-lib)

(defun split-and-follow-horizontally ()
  "Split below, balance, and follow point into the new window."
  (interactive)
  (split-window-below)
  (balance-windows)
  (other-window 1))

(defun split-and-follow-vertically ()
  "Split right, balance, and follow point into the new window."
  (interactive)
  (split-window-right)
  (balance-windows)
  (other-window 1))

(use-package transpose-frame
  :commands (transpose-frame)
  :bind (("C-x 7" . transpose-frame)))

;; Undo/redo for window configs.
(winner-mode 1)

(defun my/rotate-windows (count)
  "Rotate non-dedicated windows by COUNT positions."
  (interactive "p")
  (let* ((wins (cl-remove-if #'window-dedicated-p (window-list)))
         (n (length wins))
         (step (+ n count))
         (i 0))
    (if (< n 2)
        (user-error "Need at least 2 non-dedicated windows to rotate")
      (dotimes (_ (1- n))
        (let* ((j  (% (+ step i) n))
               (w1 (elt wins i)) (w2 (elt wins j))
               (b1 (window-buffer w1)) (b2 (window-buffer w2))
               (s1 (window-start  w1)) (s2 (window-start  w2)))
          (set-window-buffer w1 b2) (set-window-buffer w2 b1)
          (set-window-start  w1 s2) (set-window-start  w2 s1)
          (setq i j))))))

(defun my/rotate-windows-backward (count)
  "Rotate non-dedicated windows by COUNT positions in reverse."
  (interactive "p")
  (my/rotate-windows (- count)))

(provide 'dl-window)
;;; dl-window.el ends here
