;;; dl-session.el --- Restore buffers across daemon restarts -*- lexical-binding: t; -*-

;; The daemon dies with its compositor (PGTK) and the session target starts
;; a fresh one (IMP-032).  `desktop-save-mode' brings back file buffers,
;; not frames: those belonged to the dead display, and a daemon starts
;; without one.  Minibuffer history is savehist's (dl-completion.el).
;;
;; - A crash runs no `kill-emacs-hook', so the desktop saves on idle.
;; - A crash also leaves the lock behind; a daemon never loads a locked
;;   desktop under the default `ask', so `check-pid' loads it when the
;;   locking process is gone.
;; - Restore is lazy past the first few buffers, to keep daemon start fast.
;; - A frameless daemon skips the save: desktop's conflict question would
;;   go to the initial terminal (stdin /dev/null) and hang the daemon.
;; - Agenda files are left out: org-agenda reopens them anyway.
;; - Never in batch: test runs would overwrite the real desktop on exit.
;;
;; File: .emacs.desktop in `user-emacs-directory' (gitignored).

(require 'seq)

(defun dl-session--frameless-daemon-p (&rest _)
  "Return non-nil in a daemon with no frame but the initial one.
Nothing can answer a prompt there."
  (and (daemonp) (seq-every-p #'frame-initial-p (frame-list))))

(defun dl-session--save-buffer-p (filename &rest _)
  "Return non-nil unless FILENAME is an org agenda file.
For `desktop-buffers-not-to-save-function', which saves on non-nil.
Membership, not `org-agenda-file-p': that resolves truenames, about
5 ms a buffer on every save."
  (not (and filename
            (fboundp 'org-agenda-files)
            (member filename (org-agenda-files t)))))

(use-package desktop
  :ensure nil
  :demand t
  :custom
  (desktop-restore-frames nil)
  (desktop-restore-eager 5)
  (desktop-auto-save-timeout 30)
  (desktop-load-locked-desktop 'check-pid)
  (desktop-save t)
  :config
  ;; A defvar, not a defcustom: `:custom' would not set it.
  (setq desktop-buffers-not-to-save-function #'dl-session--save-buffer-p)
  (advice-add 'desktop-save :before-until #'dl-session--frameless-daemon-p)
  (unless noninteractive
    (desktop-save-mode 1)))

(provide 'dl-session)
;;; dl-session.el ends here
