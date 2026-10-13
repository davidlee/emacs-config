;;; dl-ghostel.el --- Ghostty for Emacs -*- lexical-binding: t; -*-

;; Installed via package-vc (not nix) so the package dir is writable and
;; `ghostel-download-module' / `ghostel-module-compile' can drop the native
;; .so next to ghostel.el. `:ensure nil' is load-bearing on two sides:
;;
;;   - emacs-overlay parser (parse.nix `parsePackagesFromUsePackage') only
;;     respects `:ensure' and `:disabled', not `:vc'.  Without `:ensure nil'
;;     plus `alwaysEnsure = true' in emacs.nix, nix resolves `ghostel'
;;     against melpa-nix and bakes it into the read-only package set.
;;   - use-package itself: with `use-package-always-ensure' (or `:ensure t')
;;     it would also try `package-install' from regular archives in parallel
;;     with the `:vc' handler, racing the VC install for the same dir.
;;
;; `:lisp-dir "lisp"' is needed because ghostel's elisp lives in `lisp/'
;; inside the repo, not at the root.  package-vc writes autoloads /
;; load-path entries based on this.
(require 'dl-keymap-shadow)
(defvar ghostel-mode-map)

(defun dl-ghostel--pass-paging-keys ()
  "Send PgUp/PgDn to the terminal in this buffer.
`pixel-scroll-precision-mode' binds them to scroll the window; wheel
scrolling stays smooth."
  (dl-keymap-shadow-yield 'pixel-scroll-precision-mode "<prior>" "<next>"))

(use-package ghostel
  :ensure nil
  :vc (:url "https://github.com/dakra/ghostel"
        :rev :newest)
  :custom
  ;; Upstream's list, plus the tab chords and window moves
  ;; (core/dl-keybind.el, editing/dl-motion.el) so they work here too,
  ;; and S-PgUp/PgDn so they page the scrollback, as in ghostty.  The
  ;; terminal no longer sees these.
  (xterm-extra-capabilities '(getSelection setSelection)) ;; make selection work / OSC 52
  (select-enable-clipboard t)
  (ghostel-keymap-exceptions
    '("C-c" "C-x" "C-u" "C-h" "M-x" "M-:" "C-\\"
       "C-<prior>" "C-<next>" "M-<prior>" "M-<next>"
       "C-M-<prior>" "C-M-<next>" "S-<prior>" "S-<next>"
       "C-M-<left>" "C-M-<right>" "C-M-<up>" "C-M-<down>" "M-o"))
  :hook (ghostel-mode . dl-ghostel--pass-paging-keys)
  ;; The scrollback is buffer text, so paging it is a window scroll.
  ;; Bound in the parent map: the semi-char map is rebuilt on change.
  :bind (:map ghostel-mode-map
          ("S-<prior>" . scroll-down-command)
          ("S-<next>"  . scroll-up-command)))

(use-package popterm
  :config
  (setq
    popterm-backend        'ghostel
    popterm-display-method 'window ;; | 'posframe | 'fullscreen
    popterm-scope          'project ;; | 'frame | 'dedicated | nil
    popterm-auto-cd        t)
  ;; `C-M-`' is `popper-toggle-type' (`dl-popups.el').
  :bind ("C-<f1>" . popterm-toggle))

(provide 'dl-ghostel)
;;; dl-ghostel.el ends here
