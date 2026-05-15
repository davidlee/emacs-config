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
(use-package ghostel
  :ensure nil
  :vc (:url "https://github.com/dakra/ghostel"
        :lisp-dir "lisp"
        :rev :newest))
(provide 'dl-ghostel)
;;; dl-ghostel.el ends here
