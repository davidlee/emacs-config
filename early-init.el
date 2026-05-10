(with-eval-after-load 'package
  (add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/") t))

(setq package-enable-at-startup t)

;; Startup speed, annoyance suppression
;(setq bedrock--initial-gc-threshold gc-cons-threshold)
(setq gc-cons-threshold 10000000)
(setq byte-compile-warnings '(not obsolete))
(setq warning-suppress-log-types '((comp) (bytecomp)))
(setq native-comp-async-report-warnings-errors 'silent)

;; Silence stupid startup message
(setq inhibit-startup-echo-area-message (user-login-name))

;; indent
(setq standard-indent 2)

;; Default frame / UI configuration
(setq frame-resize-pixelwise t)
(setq tool-bar-mode nil)
(setq inhibit-startup-message t)
(setq inhibit-startup-echo-area-message t)
(setq tooltip-use-echo-area t)
(setq use-short-answers t)
(setq use-dialog-box nil)
(setq confirm-nonexistent-file-or-buffer nil)
(setq default-frame-alist '((fullscreen . maximized)
(setq inhibit-splash-screen t)
(setq use-file-dialog nil)

                            ;; You can turn off scroll bars by uncommenting these lines:
                            ;; (vertical-scroll-bars . nil)
                            ;; (horizontal-scroll-bars . nil)

                            ;; Setting the face in here prevents flashes of
                            ;; color as the theme gets activated
                            (background-color . "#000000")
                            (foreground-color . "#ffffff")
                            (ns-appearance . dark)
                            (ns-transparent-titlebar . t)))

