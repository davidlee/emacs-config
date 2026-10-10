;;; dl-agent-review.el --- Follow and annotate an agent's Git diff -*- lexical-binding: t; -*-

;;; Code:

(require 'cl-lib)
(require 'filenotify)
(require 'use-package)

(use-package magit-filenotify
  :commands magit-filenotify-mode)

(use-package hunk-notes
  :commands (hunk-notes-start hunk-notes-comment-dwim hunk-notes-copy-prompt)
  :custom
  (hunk-notes-storage-directory
   (expand-file-name "~/.local/state/emacs-hunk-notes/reviews/"))
  (hunk-notes-render-style 'overlay)
  (hunk-notes-default-agent 'copy))

(defvar my/agent-review--diff-buffer nil)
(defvar my/agent-review--status-buffer nil)
(defvar my/agent-review--owns-watcher nil)
(defvar my/agent-review--pending nil)
(defvar my/agent-review--git-watches nil)
(defvar my/agent-review--git-timer nil)
(defvar my/agent-review--rewatch-git nil)

(declare-function magit-toplevel "magit-git")
(declare-function magit-gitdir "magit-git")
(declare-function magit-get-current-branch "magit-git")
(declare-function magit-status-setup-buffer "magit-status")
(declare-function magit-get-mode-buffer "magit-mode")
(declare-function magit-diff-setup-buffer "magit-diff")
(declare-function magit-refresh-buffer "magit-mode")
(declare-function magit-filenotify-mode "magit-filenotify")
(declare-function hunk-notes-start "hunk-notes")
(declare-function hunk-notes-render-comments "hunk-notes-overlays")
(defvar magit-filenotify-mode)
(defvar magit-refresh-buffer-hook)

(defun my/agent-review--clear-git-watches ()
  "Release watches for Git metadata."
  (mapc #'file-notify-rm-watch my/agent-review--git-watches)
  (setq my/agent-review--git-watches nil))

(defun my/agent-review--watch-git ()
  "Watch index, HEAD and branch metadata, including linked worktrees."
  (my/agent-review--clear-git-watches)
  (with-current-buffer my/agent-review--status-buffer
    (let* ((common (magit-gitdir nil t))
           (branch (magit-get-current-branch))
           (ref-directory (file-name-directory
                           (expand-file-name
                            (concat "refs/heads/" (or branch "")) common))))
      (dolist (directory (delete-dups
                         (list (magit-gitdir) common ref-directory)))
        (when (file-directory-p directory)
          (push (file-notify-add-watch directory '(change)
                                       #'my/agent-review--git-event)
                my/agent-review--git-watches))))))

(defun my/agent-review--refresh-git-status ()
  "Refresh after a debounced Git metadata change."
  (setq my/agent-review--git-timer nil)
  (when (buffer-live-p my/agent-review--status-buffer)
    (when my/agent-review--rewatch-git
      (setq my/agent-review--rewatch-git nil)
      (my/agent-review--watch-git))
    (with-current-buffer my/agent-review--status-buffer
      (magit-refresh-buffer))))

(defun my/agent-review--git-event (event)
  "Schedule a status refresh for Git metadata EVENT."
  (when (and (buffer-live-p my/agent-review--status-buffer)
             (memq (cadr event) '(created deleted changed attribute-changed renamed))
             ;; Ignore temporary lockfiles and watches stopping during cleanup.
             (cl-some (lambda (path)
                        (and (stringp path)
                             (not (string-suffix-p ".lock" path))))
                      (cddr event)))
    (when (cl-some (lambda (path)
                    (and (stringp path)
                         (equal (file-name-nondirectory path) "HEAD")))
                  (cddr event))
      (setq my/agent-review--rewatch-git t))
    (when my/agent-review--git-timer
      (cancel-timer my/agent-review--git-timer))
    (setq my/agent-review--git-timer
          (run-at-time 0.2 nil #'my/agent-review--refresh-git-status))))

(defun my/agent-review--editing-p ()
  "Whether a minibuffer or hunk comment editor is in use."
  (or (active-minibuffer-window)
      (cl-some (lambda (buffer)
                 (with-current-buffer buffer
                   (derived-mode-p 'hunk-notes-comment-edit-mode)))
               (buffer-list))))

(defun my/agent-review--render-comments ()
  "Redraw review annotations after Magit rebuilds the diff."
  (when (bound-and-true-p hunk-notes-mode)
    (hunk-notes-render-comments)))

(defun my/agent-review--flush ()
  "Refresh a pending review when comment entry has finished."
  (when (and my/agent-review--pending
             (not (my/agent-review--editing-p)))
    (setq my/agent-review--pending nil)
    (remove-hook 'post-command-hook #'my/agent-review--flush)
    (when (buffer-live-p my/agent-review--diff-buffer)
      (with-current-buffer my/agent-review--diff-buffer
        (magit-refresh-buffer)))))

(defun my/agent-review--status-refreshed ()
  "Follow this review's status refresh without refreshing other diffs."
  (when (and (eq (current-buffer) my/agent-review--status-buffer)
             (buffer-live-p my/agent-review--diff-buffer))
    (setq my/agent-review--pending t)
    (if (my/agent-review--editing-p)
        (add-hook 'post-command-hook #'my/agent-review--flush)
      (my/agent-review--flush))))

(defun my/agent-review--status-setup ()
  "Restore review hooks when Magit sets up the active status buffer again."
  (when (eq (current-buffer) my/agent-review--status-buffer)
    ;; Magit's setup can reset minor modes and local hooks.  Rebuild an
    ;; owned watcher rather than accumulating stale descriptors.
    (when my/agent-review--owns-watcher
      (magit-filenotify-mode -1)
      (magit-filenotify-mode 1))
    (add-hook 'magit-refresh-buffer-hook
              #'my/agent-review--status-refreshed nil t)
    (add-hook 'kill-buffer-hook #'my/agent-review-stop nil t)))

(with-eval-after-load 'magit-status
  (add-hook 'magit-status-mode-hook #'my/agent-review--status-setup))

;;;###autoload
(defun my/agent-review-stop ()
  "Stop the active review's filesystem watcher; keep its saved comments."
  (interactive)
  (when my/agent-review--git-timer
    (cancel-timer my/agent-review--git-timer))
  (my/agent-review--clear-git-watches)
  (when (buffer-live-p my/agent-review--status-buffer)
    (with-current-buffer my/agent-review--status-buffer
      (remove-hook 'magit-refresh-buffer-hook
                   #'my/agent-review--status-refreshed t)
      (remove-hook 'kill-buffer-hook #'my/agent-review-stop t)
      (when my/agent-review--owns-watcher
        (magit-filenotify-mode -1))))
  (when (buffer-live-p my/agent-review--diff-buffer)
    (with-current-buffer my/agent-review--diff-buffer
      (remove-hook 'kill-buffer-hook #'my/agent-review-stop t)))
  (remove-hook 'post-command-hook #'my/agent-review--flush)
  (setq my/agent-review--diff-buffer nil
        my/agent-review--status-buffer nil
        my/agent-review--owns-watcher nil
        my/agent-review--pending nil
        my/agent-review--git-timer nil
        my/agent-review--rewatch-git nil)
  (when (called-interactively-p 'interactive)
    (message "Agent review watching stopped; comments are preserved")))

;;;###autoload
(defun my/agent-review-start (directory)
  "Watch DIRECTORY's Git repository and annotate its uncommitted diff.
One repository is followed at a time.  The locked diff compares the working
tree with HEAD, including staged changes.  Untracked files remain in status.
Use `hunk-notes-comment-dwim' to comment and `hunk-notes-copy-prompt' to export.
Closing either review buffer stops watching.  Existing independent watchers
are left enabled when the review stops."
  (interactive (list (read-directory-name "Review repository: " default-directory)))
  (require 'magit)
  (require 'magit-filenotify)
  (require 'hunk-notes)
  (when (file-remote-p directory)
    (user-error "Agent review requires a local repository"))
  (let* ((default-directory (file-name-as-directory (expand-file-name directory)))
         (root (or (magit-toplevel) (user-error "Not in a Git repository"))))
    ;; Stop before reusing the same buffers, so hooks and watch descriptors
    ;; cannot accumulate over repeated starts.
    (my/agent-review-stop)
    (condition-case err
        (progn
          (setq my/agent-review--status-buffer
                (let ((default-directory root))
                  (or (magit-get-mode-buffer 'magit-status-mode)
                      (magit-status-setup-buffer root))))
          (with-current-buffer my/agent-review--status-buffer
            (setq my/agent-review--owns-watcher (not magit-filenotify-mode))
            (when my/agent-review--owns-watcher
              (magit-filenotify-mode 1))
            (add-hook 'kill-buffer-hook #'my/agent-review-stop nil t))
          (let ((default-directory root))
            (setq my/agent-review--diff-buffer
                  (magit-diff-setup-buffer "HEAD" nil nil nil 'committed t)))
          (with-current-buffer my/agent-review--diff-buffer
            (hunk-notes-start :repo-root root :backend 'git
                              :base-revision "HEAD" :target-revision "working-tree"
                              :diff-id "agent-review" :preserve-major-mode t)
            (add-hook 'magit-refresh-buffer-hook
                      #'my/agent-review--render-comments nil t)
            (add-hook 'kill-buffer-hook #'my/agent-review-stop nil t))
          (with-current-buffer my/agent-review--status-buffer
            (add-hook 'magit-refresh-buffer-hook
                      #'my/agent-review--status-refreshed nil t))
          (my/agent-review--watch-git)
          (pop-to-buffer my/agent-review--diff-buffer)
          (message "Watching %s; C-c , c comments, C-c , y copies the prompt" root)
          my/agent-review--diff-buffer)
      (error
       (my/agent-review-stop)
       (signal (car err) (cdr err))))))

(provide 'dl-agent-review)
;;; dl-agent-review.el ends here
