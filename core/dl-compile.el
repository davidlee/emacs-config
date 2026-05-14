;;; dl-compile.el --- Bytecode / Native Compilation -*- lexical-binding: t; -*-

;; Ensure Emacs loads the most recent byte-compiled files.
(setq load-prefer-newer t)

;; https://www.jamescherti.com/compiling-emacs/
;; NOTE: `native-comp-driver-options` is preloaded by the Nix emacs build with
;; -B flags pointing at libgccjit, glibc, gcc-libgcc, and binutils. Overwriting
;; it with `setq` breaks linking (Scrt1.o / crti.o / -lgcc_s not found). Append.
(require 'comp)
(setq native-comp-compiler-options
  (append native-comp-compiler-options
    '("-O2"
       "-g0"
       "-fno-omit-frame-pointer"
       "-fno-finite-math-only")))

(setq native-comp-driver-options
  (append native-comp-driver-options
    '("-Wl,-O2"
       "-Wl,--as-needed")))

(use-package compile-angel
  :demand t
  :custom
  (compile-angel-verbose nil)
  :config
  (add-hook 'emacs-lisp-mode-hook #'compile-angel-on-save-local-mode)

  (push "/init.el" compile-angel-excluded-files)
  (push "/early-init.el" compile-angel-excluded-files)

  ;; (compile-angel-on-load-mode 1))
  (compile-angel-on-save-mode 1))

(provide 'dl-compile)
;;; dl-compile.el ends here
