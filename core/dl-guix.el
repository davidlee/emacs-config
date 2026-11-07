;;; dl-guix.el --- Package sources on Guix System -*- lexical-binding: t; -*-

;; Guix Home supplies Emacs and most packages.  This module covers the
;; rest: packages Guix lacks come from the archives, and forks or
;; unpublished packages from their repositories.
;;
;; Fetching is an explicit step (`just guix-packages').  Startup stays
;; offline, and `package-archives' stays nil at runtime, as on Nix.

(require 'package)

(defvar use-package-ensure-function)

(defconst dl-guix-archives
  '(("melpa" . "https://melpa.org/packages/")
    ("gnu" . "https://elpa.gnu.org/packages/")
    ("nongnu" . "https://elpa.nongnu.org/nongnu/"))
  "Archives to fetch from, bound only while installing.")

(defconst dl-guix-archive-packages
  '(australia-holidays breadcrumb buffer-terminator comment-dwim-2
    copy-as-format dired-toggle dogears flyover gptel-inline macher
    magit-filenotify markdown-preview-eww markdown-toc minuet
    molokai-theme nano-agenda nushell-ts-mode org-alert org-gcal org-mcp
    org-review org-srs popterm quick-sdcv ready-player slim-mode
    treesit-fold visual-regexp-steroids zoom-window)
  "Packages in ~/flakes/emacs/emacs.nix that Guix lacks.")

(defconst dl-guix-vc-packages
  '((hunk-notes :url "https://github.com/ArthurHeymans/emacs-hunk-notes")
    (org-timeblock :url "https://github.com/davidlee/org-timeblock"))
  "Package specs that no archive provides in the form this config uses.")

(defun dl-guix-system-p ()
  "Return non-nil when running on Guix System."
  (file-directory-p "/gnu/store"))

(defun dl-guix-configure-packages ()
  "Stop `:ensure' installing packages on Guix, where it can't see them."
  (when (dl-guix-system-p)
    (setq use-package-ensure-function #'ignore)))

(defun dl-guix-install-packages ()
  "Fetch the packages that Guix doesn't supply."
  (interactive)
  (unless (dl-guix-system-p)
    (user-error "Not on Guix: packages come from ~/flakes/emacs/emacs.nix"))
  (let ((package-archives dl-guix-archives))
    (package-refresh-contents)
    (mapc #'package-install dl-guix-archive-packages)
    (dolist (spec dl-guix-vc-packages)
      (unless (package-installed-p (car spec))
        (package-vc-install spec)))))

(provide 'dl-guix)
;;; dl-guix.el ends here
