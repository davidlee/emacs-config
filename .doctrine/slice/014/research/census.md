# SL-014 research — keymap-write census (2026-10-08)

Disposable static census (scratch script, not committed): reads every
config `.el` under `core lisp org editing completion apps lang dev` and
`init.el` without loading packages, and records literal keymap writes.
Raw output below; design.md § Migration groups it.

Live cross-checks (running Emacs, `emacsclient`):

- `C-:` → `avy-goto-char`, ``C-M-` `` → `popterm-toggle` (later loader wins).
- `personal-keybindings` already records ``C-M-` `` popterm-toggle *was*
  popper-toggle-type.
- `my-policy-lint-scan` reports `C-c i` (`my-org-iw-map` missing from the
  family list).
- `global-text-scale-adjust` (face-remap.el, Emacs 31.1) takes direction
  from `last-command-event`: wrappers are redundant, behaviour correct.

```
READERR core/dl-theme.el (wrong-type-argument listp :config) line 3
records 371
== by form
((keymap-set . 5) (my/bind . 214) (global-unset-key . 1) (define-key . 23) (keymap-global-set . 8) (global-set-key . 41) (:bind . 79))
== to migrate (non-:bind, non-my/bind, excluding dl-keymap C-c family prefixes)
  global-map                   C-M-<left>           #'windmove-left                global-set-key   core/dl-keybind.el:8
  global-map                   C-M-<up>             #'windmove-up                  global-set-key   core/dl-keybind.el:8
  global-map                   C-M-<down>           #'windmove-down                global-set-key   core/dl-keybind.el:8
  global-map                   C-M-<right>          #'windmove-right               global-set-key   core/dl-keybind.el:8
  global-map                   C-<prior>            'tab-bar-switch-to-prev-tab    keymap-global-set core/dl-keybind.el:24
  global-map                   C-<next>             'tab-bar-switch-to-next-tab    keymap-global-set core/dl-keybind.el:25
  global-map                   M-<prior>            'tab-bar-switch-to-prev-tab    keymap-global-set core/dl-keybind.el:26
  global-map                   M-<next>             'tab-bar-switch-to-next-tab    keymap-global-set core/dl-keybind.el:27
  global-map                   C-M-<prior>          'tab-line-switch-to-prev-tab   keymap-global-set core/dl-keybind.el:28
  global-map                   C-M-<next>           'tab-line-switch-to-next-tab   keymap-global-set core/dl-keybind.el:29
  global-map                   s-{                  'tab-bar-switch-to-prev-tab    keymap-global-set core/dl-keybind.el:30
  global-map                   s-}                  'tab-bar-switch-to-next-tab    keymap-global-set core/dl-keybind.el:31
  global-map                   M-/                  'hippie-expand                 global-set-key   core/dl-keybind.el:33
  global-map                   C-;                  'iedit-mode                    global-set-key   core/dl-keybind.el:34
  global-map                   M-z                  'zap-up-to-char                global-set-key   core/dl-keybind.el:35
  global-map                   C-x K                'kill-current-buffer           global-set-key   core/dl-keybind.el:36
  global-map                   C-x C-b              'ibuffer                       global-set-key   core/dl-keybind.el:37
  global-map                   C-x C-z              'zoom-window-zoom              global-set-key   core/dl-keybind.el:38
  comint-mode-map              C-p                  #'comint-previous-input        define-key       core/dl-keybind.el:40
  comint-mode-map              C-n                  #'comint-next-input            define-key       core/dl-keybind.el:41
  comint-mode-map              C-w                  #'backward-kill-word           define-key       core/dl-keybind.el:42
  global-map                   C-x 2                'split-and-follow-horizontally global-set-key   core/dl-keybind.el:44
  global-map                   C-x 3                'split-and-follow-vertically   global-set-key   core/dl-keybind.el:45
  global-map                   C-v                  #'View-scroll-half-page-forward global-set-key   core/dl-keybind.el:49
  global-map                   M-v                  #'View-scroll-half-page-backward global-set-key   core/dl-keybind.el:50
  global-map                   C-+                  #'text-scale-increase          global-set-key   core/dl-keybind.el:55
  global-map                   C-_                  #'text-scale-decrease          global-set-key   core/dl-keybind.el:56
  global-map                   C-0                  #'text-scale-adjust            global-set-key   core/dl-keybind.el:57
  global-map                   C-M-=                #'my/global-text-scale-increase global-set-key   core/dl-keybind.el:60
  global-map                   C-M-+                #'my/global-text-scale-increase global-set-key   core/dl-keybind.el:61
  global-map                   C-M--                #'my/global-text-scale-increase global-set-key   core/dl-keybind.el:62
  global-map                   C-S-0                #'my/global-text-scale-reset   global-set-key   core/dl-keybind.el:63
  global-map                   C-z                  nil                            global-unset-key core/dl-keybind.el:65
  global-map                   C-z                  'undo-fu-only-undo             global-set-key   core/dl-keybind.el:66
  global-map                   C-S-z                'undo-fu-only-redo             global-set-key   core/dl-keybind.el:67
  global-map                   C-S-g                #'exit-minibuffer              global-set-key   core/dl-keybind.el:69
  global-map                   <f9>                 'toggle-maximize-buffer        global-set-key   core/dl-keybind.el:123
  global-map                   <f1>                 #'my/journal-quick-capture     global-set-key   core/dl-keybind.el:128
  global-map                   <f5>                 #'deadgrep                     global-set-key   core/dl-keybind.el:132
  global-map                   C-x C-j              #'dired-jump                   global-set-key   core/dl-keymap.el:103
  global-map                   C-x C-n              #'dirvish-side                 global-set-key   core/dl-keymap.el:104
  meow-normal-state-keymap     C-\                  'repeat-fu-execute             define-key       core/dl-meow.el:37
  meow-insert-state-keymap     C-\                  'repeat-fu-execute             define-key       core/dl-meow.el:37
  global-map                   M-Q                  #'my/unfill-paragraph          global-set-key   core/dl-prose.el:88
  global-map                   C-c a                #'org-agenda                   global-set-key   org/dl-org-agenda.el:100
  global-map                   C-c c                #'org-capture                  global-set-key   org/dl-org-capture.el:171
  global-map                   C-c l                #'org-store-link               global-set-key   org/dl-org-links.el:7
  org-timeblock-mode-map       <remap> <meow-prev>  #'org-timeblock-backward-block define-key       org/dl-org.el:104
  org-timeblock-mode-map       <remap> <meow-next>  #'org-timeblock-forward-block  define-key       org/dl-org.el:104
  org-timeblock-list-mode-map  <remap> <meow-prev>  #'org-timeblock-list-previous-line define-key       org/dl-org.el:104
  org-timeblock-list-mode-map  <remap> <meow-next>  #'org-timeblock-list-next-line define-key       org/dl-org.el:104
  global-map                   <remap> <move-beginning-of-line> #'crux-move-beginning-of-line  global-set-key   editing/dl-crux.el:3
  global-map                   S-<return>           #'crux-smart-open-line         global-set-key   editing/dl-crux.el:3
  global-map                   C-M-j                #'crux-top-join-line           global-set-key   editing/dl-crux.el:3
  global-map                   C-<backspace>        #'crux-kill-line-backward      global-set-key   editing/dl-crux.el:3
  global-map                   <remap> <keyboard-quit> #'crux-keyboard-quit-dwim      global-set-key   editing/dl-crux.el:3
  org-mode-map                 C-,                  #'embark-act                   keymap-set       completion/dl-embark.el:23
  vertico-map                  M-?                  #'minibuffer-completion-help   keymap-set       completion/dl-vertico.el:22
  vertico-map                  M-RET                #'minibuffer-force-complete-and-exit keymap-set       completion/dl-vertico.el:23
  vertico-map                  C-M-i                #'minibuffer-complete          keymap-set       completion/dl-vertico.el:24
  eshell-mode-map              C-r                  'consult-history               keymap-set       apps/dl-term.el:13
  global-map                   s-C-<return>         'eshell-other-window           global-set-key   apps/dl-term.el:31
  global-map                   C-<f1>               #'my/ghostel-toggle            global-set-key   apps/dl-term.el:63
  global-map                   C-<f2>               #'my/ghostel-here              global-set-key   apps/dl-term.el:64
== collisions
  (global-map . "C-z")
      nil global-unset-key core/dl-keybind.el:65
      'undo-fu-only-undo global-set-key core/dl-keybind.el:66
  (global-map . "C-M-`")
      popper-toggle-type :bind core/dl-popups.el:8
      popterm-toggle :bind apps/dl-ghostel.el:54
  (global-map . "C-:")
      jinx-correct :bind core/dl-prose.el:41
      avy-goto-char :bind editing/dl-motion.el:12
```
