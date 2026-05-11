;;; dl-completion.el --- Built-in completion setup -*- lexical-binding: t; -*-

;; For help, see: https://www.masteringemacs.org/article/understanding-minibuffer-completion

(use-package emacs
  :ensure nil
  :custom
  ;; Allow commands in minibuffer prompts.
  (enable-recursive-minibuffers t)

  ;; TAB complete else indent
  (tab-always-indent 'complete)

  ;; Hide commands irrelevant to the current mode from M-x.
  (read-extended-command-predicate
    #'command-completion-default-include-p)

  ;; Matching behavior.
  (completion-styles '(basic partial-completion substring))
  (completion-category-defaults nil)
  (completion-category-overrides
    '((file (styles basic partial-completion))
       (buffer (styles basic substring))
       (command (styles basic substring initials))
       (variable (styles basic substring initials))
       (symbol (styles basic substring initials))))

  ;; Candidate display.
  (completions-detailed t)
  (completions-format 'one-column)
  (completions-group t)
  (completions-header-format nil)
  (completions-max-height 20)

  ;; Completion interaction.
  (completion-auto-help 'always)
  (completion-auto-select 'second-tab) ; See `C-h v completion-auto-select' for more
  (completion-cycle-threshold 3)
  (completion-auto-wrap t)
  (completion-cycle-threshold 1)  ; TAB cycles candidates

  ;; halp
  (completion-auto-help 'always) ; or 'lazy

  ;; TAB acts more like how it does in the shell
  (keymap-set minibuffer-mode-map "TAB" 'minibuffer-complete))

;; Persist minibuffer history.
(use-package savehist
  :ensure nil
  :init
  (savehist-mode 1)
  :custom
  (history-length 1000)
  (savehist-save-minibuffer-history t))

;; Remember recent files.
(use-package recentf
  :ensure nil
  :init
  (recentf-mode 1)
  :custom
  (recentf-max-saved-items 200)
  (recentf-auto-cleanup 'never))

;; Show minibuffer recursion depth if you use recursive minibuffers.
(use-package mb-depth
  :ensure nil
  :init
  (minibuffer-depth-indicate-mode 1))

;; Emacs 30+: inline in-buffer completion previews.
(when (fboundp 'global-completion-preview-mode)
  (global-completion-preview-mode 1))

(provide 'dl-completion)
