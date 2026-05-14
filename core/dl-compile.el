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
  :config
  ;; Set `compile-angel-verbose' to nil to disable compile-angel messages.
  ;; (When set to nil, compile-angel won't show which file is being compiled.)
  (setq compile-angel-verbose t)

  ;; Uncomment the line below to compile automatically when an Elisp file is saved
  (add-hook 'emacs-lisp-mode-hook #'compile-angel-on-save-local-mode)

  ;; The following directive prevents compile-angel from compiling your init
  ;; files. If you choose to remove this push to `compile-angel-excluded-files'
  ;; and compile your pre/post-init files, ensure you understand the
  ;; implications and thoroughly test your code. For example, if you're using
  ;; the `use-package' macro, you'll need to explicitly add:
  ;; (eval-when-compile (require 'use-package))
  ;; at the top of your init file.
  (push "/init.el" compile-angel-excluded-files)
  (push "/early-init.el" compile-angel-excluded-files)

  ;; A global mode that compiles .el files before they are loaded
  ;; using `load' or `require'.
  (compile-angel-on-load-mode 1))

(provide 'dl-compile)
;;; dl-compile.el ends here
