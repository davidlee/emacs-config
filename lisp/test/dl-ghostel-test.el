;;; dl-ghostel-test.el --- ert tests for ghostel integration -*- lexical-binding: t; -*-

;; Run: `just check' (dl-test scans lisp/test), or M-x ert RET dl-ghostel RET.

(require 'ert)
(require 'pixel-scroll)

(defconst dl-ghostel-test--package-dir
  (expand-file-name "elpa/ghostel/lisp" user-emacs-directory)
  "Ghostel's package-vc checkout; absent outside a provisioned config.")

;; On the path before `dl-ghostel' loads, or its `use-package' is skipped.
(when (file-directory-p dl-ghostel-test--package-dir)
  (add-to-list 'load-path dl-ghostel-test--package-dir)
  (require 'ghostel))
(require 'dl-ghostel)

(ert-deftest dl-ghostel/paging-reaches-terminal ()
  "PgUp/PgDn go to the buffer's own map despite `pixel-scroll-precision-mode'.
Its minor-mode map otherwise wins and scrolls the Emacs window.  Wheel
scrolling stays smooth."
  (let ((pixel-scroll-precision-mode t)
        (terminal (make-sparse-keymap)))
    (keymap-set terminal "<prior>" #'ignore)
    (keymap-set terminal "<next>" #'ignore)
    (with-temp-buffer
      (use-local-map terminal)
      (dl-ghostel--pass-paging-keys)
      (should (eq (key-binding [prior]) #'ignore))
      (should (eq (key-binding [next]) #'ignore))
      (should (eq (key-binding [wheel-down]) #'pixel-scroll-precision)))))

(ert-deftest dl-ghostel/window-keys-reach-emacs ()
  "Window moves (windmove, ace-window) work from a terminal buffer.
The semi-char map sends every key it binds to the terminal, so these
must stay unbound there; an ordinary meta key still goes through."
  (skip-unless (featurep 'ghostel))
  (dolist (key '("C-M-<left>" "C-M-<right>" "C-M-<up>" "C-M-<down>" "M-o"))
    (should-not (keymap-lookup ghostel-semi-char-mode-map key)))
  (should (eq (keymap-lookup ghostel-semi-char-mode-map "M-p")
              #'ghostel--send-event)))

(provide 'dl-ghostel-test)
;;; dl-ghostel-test.el ends here
