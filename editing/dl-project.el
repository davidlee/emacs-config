;;; dl-project.el --- projects / QOL  -*- lexical-binding: t; -*-
;;; Commentary: none

;; Auto parenthesis matching in code buffers.
(add-hook 'prog-mode-hook #'electric-pair-mode)

(use-package project
  :ensure nil
  :custom
  ;; Stop the root climb at a marker so a dir inside ~/.git isn't the
  ;; whole home repo, while keeping the VC backend (git ls-files). A
  ;; non-VC fallback lists via `find -L', which crawls symlinked
  ;; .direnv flake inputs and hangs.
  (project-vc-extra-root-markers
   '(".project" ".projectile" "flake.nix" "package.json" "go.mod" "Cargo.toml"))
  (project-mode-line t))           ; show project name in modeline


;; project-x keeps a layout (window state + open files) per project root.
;; When to save is ours: its interval timer saved whichever project was
;; current, so at startup the fresh layout overwrote the saved one.
;; Instead, save each otpp tab's project as the tab is left, and the
;; current one at exit — but never over a layout saved by an earlier
;; session that this one has not restored.

(declare-function project-x--project-root-key "project-x")
(declare-function project-x--session-has-window-state-p "project-x")
(declare-function project-x-window-state-save "project-x")
(declare-function project-x-try-local "project-x")
(declare-function otpp-get-tab-root-dir "otpp")

(defvar dl-project--owned-layouts nil
  "Roots whose saved layout this session restored or wrote.")

(defun dl-project--own-layout (root)
  "Record that this session owns ROOT's saved layout."
  (cl-pushnew (project-x--project-root-key root) dl-project--owned-layouts
    :test #'equal))

(defun dl-project--note-restore (restore dir)
  "Call RESTORE on DIR; when it restores a layout, own it."
  (when (funcall restore dir)
    (dl-project--own-layout dir)
    t))

(defun dl-project--save-layout (root)
  "Save the frame's layout as ROOT's, unless it would lose an unrestored one."
  (when (or (member (project-x--project-root-key root) dl-project--owned-layouts)
          (not (project-x--session-has-window-state-p root)))
    (let ((default-directory root)
          (inhibit-message t)
          (message-log-max nil))
      (project-x-window-state-save))
    (dl-project--own-layout root)))

(defun dl-project--save-tab-layout (&rest _)
  "Save the current otpp tab's project layout, if the tab has a project."
  (when-let* ((root (otpp-get-tab-root-dir)))
    (dl-project--save-layout root)))

(defun dl-project--setup-project-x ()
  "Save layouts per tab instead of on project-x's timer.
Drop its project detector: `project-vc-extra-root-markers' finds the
same roots, so one place defines them."
  (remove-hook 'project-find-functions #'project-x-try-local)
  (advice-add 'project-x--window-state-restore :around #'dl-project--note-restore)
  (advice-add 'tab-bar-select-tab :before #'dl-project--save-tab-layout)
  (advice-add 'tab-bar-new-tab-to :before #'dl-project--save-tab-layout)
  (add-hook 'kill-emacs-hook #'dl-project--save-tab-layout -10))

(use-package project-x
  :ensure nil
  :vc (:url "https://github.com/vmargb/project-x.git")
  :after project
  :config
  (project-x-mode 1)
  (dl-project--setup-project-x))

(use-package otpp
  :ensure nil
  :vc (:url "https://github.com/abougouffa/one-tab-per-project.git")
  :after project
  :custom
  ;; `find-file' on another project's file switches to (or opens) its tab.
  (otpp-find-file-integration t)
  :config
  ;; Enable `otpp-mode` globally
  (otpp-mode 1)
  ;; If you want to advice the commands in `otpp-override-commands`
  ;; to be run in the current's tab (so, current project's) root directory
  (otpp-override-mode 1))

(provide 'dl-project)
;;; dl-project.el ends here
