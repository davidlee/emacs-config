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
(defvar pixel-scroll-precision-mode-map)

(defun dl-ghostel--pass-paging-keys ()
  "Send PgUp/PgDn to the terminal in this buffer.
`pixel-scroll-precision-mode' binds them to scroll the window, and a
minor mode's map beats ghostel's major-mode map.  Shadow that map here
with a copy lacking those keys; wheel scrolling stays smooth."
  (let ((map (copy-keymap pixel-scroll-precision-mode-map)))
    (keymap-unset map "<prior>" t)
    (keymap-unset map "<next>" t)
    (setq-local minor-mode-overriding-map-alist
      (cons (cons 'pixel-scroll-precision-mode map)
        minor-mode-overriding-map-alist))))

(use-package ghostel
  :ensure nil
  :vc (:url "https://github.com/dakra/ghostel"
        :rev :newest)
  :custom
  ;; Upstream's list, plus the tab chords (core/dl-keybind.el) so they
  ;; switch tabs here too; the terminal no longer sees M-/C-M-PgUp/PgDn.
  (ghostel-keymap-exceptions
    '("C-c" "C-x" "C-u" "C-h" "M-x" "M-:" "C-\\"
       "M-<prior>" "M-<next>" "C-M-<prior>" "C-M-<next>"))
  :hook (ghostel-mode . dl-ghostel--pass-paging-keys))

(use-package popterm
  :config
  (setq
    popterm-backend        'ghostel
    popterm-display-method 'window ;; | 'posframe | 'fullscreen
    popterm-scope          'project ;; | 'frame | 'dedicated | nil
    popterm-auto-cd        t)
  :bind
  ("C-M-` " . popterm-toggle)) ;; note: conflict with popper-mode toggle

(provide 'dl-ghostel)
;;; dl-ghostel.el ends here
