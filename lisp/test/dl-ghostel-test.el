;;; dl-ghostel-test.el --- ert tests for ghostel integration -*- lexical-binding: t; -*-

;; Run: `just check' (dl-test scans lisp/test), or M-x ert RET dl-ghostel RET.

(require 'cl-lib)
(require 'ert)
(require 'pixel-scroll)
(require 'dl-modeline)

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

(ert-deftest dl-ghostel/status-shows-in-the-modeline ()
  "lambda-line ignores `global-mode-string', so a segment carries the indicator.
It shows in the active window only, and adds nothing while no terminal counts."
  (should (memq #'dl-ghostel--status-segment dl-modeline-segments))
  (cl-letf (((symbol-function 'dl-modeline-window-active-p) (lambda () t)))
    (let ((ghostel-status--indicator "2"))
      (should (equal (dl-ghostel--status-segment) "2 ")))
    (let ((ghostel-status--indicator nil))
      (should-not (dl-ghostel--status-segment))))
  (cl-letf (((symbol-function 'dl-modeline-window-active-p) #'ignore))
    (let ((ghostel-status--indicator "2"))
      (should-not (dl-ghostel--status-segment)))))

(ert-deftest dl-ghostel/status-indicator-tracks-terminals ()
  "Loading ghostel turns the indicator on."
  (skip-unless (featurep 'ghostel))
  (should ghostel-status-indicator-mode))

(ert-deftest dl-ghostel/consult-reaches-terminals ()
  "`consult-buffer' narrows to terminals and to those needing attention."
  (skip-unless (and (featurep 'ghostel) (require 'consult nil t)))
  (should (fboundp 'consult-ghostel))
  (should (memq 'consult-ghostel-source-hidden consult-buffer-sources))
  (should (memq 'consult-ghostel-status-source-hidden consult-buffer-sources)))

(ert-deftest dl-ghostel/pickers-work-before-consult-loads ()
  "Startup loads neither ghostel nor consult, so a picker must load them itself.
A fresh Emacs, as `dl-ghostel' in this one has long since met consult."
  (skip-unless (featurep 'ghostel))
  (let* ((script
          (format "%S"
                  `(progn
                     (setq user-emacs-directory ,user-emacs-directory
                           load-path ',load-path
                           load-prefer-newer t)
                     (require 'use-package)
                     (require 'dl-ghostel)
                     (prin1 (list (featurep 'consult)
                                  (commandp 'consult-ghostel)
                                  (commandp 'consult-ghostel-status))))))
         (output (with-output-to-string
                   (call-process (expand-file-name invocation-name invocation-directory)
                                 nil (list standard-output nil) nil
                                 "-Q" "--batch" "--eval" script))))
    (should (equal (car (read-from-string output)) '(nil t t)))))

(provide 'dl-ghostel-test)
;;; dl-ghostel-test.el ends here
