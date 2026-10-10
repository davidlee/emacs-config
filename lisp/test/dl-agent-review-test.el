;;; dl-agent-review-test.el --- Agent review integration tests -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)

(defun dl-agent-review-test--git (directory &rest args)
  (let ((default-directory directory))
    (unless (zerop (apply #'process-file "git" nil nil nil
                         "-c" "core.hooksPath=/dev/null" args))
      (error "Fixture git command failed: %S" args))))

(defmacro dl-agent-review-test--with-repo (&rest body)
  (declare (indent 0))
  `(progn
     (skip-unless (and (locate-library "magit")
                       (locate-library "magit-filenotify")
                       (locate-library "hunk-notes")))
     (require 'dl-agent-review)
     (require 'magit-filenotify)
     (require 'hunk-notes)
     (let* ((root (file-name-as-directory (make-temp-file "agent-review-" t)))
            (file (expand-file-name "example.txt" root))
            (hunk-notes-storage-directory (expand-file-name "reviews/" root))
            (magit-filenotify-instant-refresh-time 0)
            (magit-save-repository-buffers nil)
            (my/agent-review--status-buffer nil)
            (my/agent-review--diff-buffer nil)
            (my/agent-review--owns-watcher nil)
            (my/agent-review--pending nil)
            (my/agent-review--git-watches nil)
            (my/agent-review--git-timer nil)
            (my/agent-review--rewatch-git nil))
       (with-temp-file file (insert "alpha\n"))
       (dl-agent-review-test--git root "init" "-q")
       (dl-agent-review-test--git root "add" "example.txt")
       (dl-agent-review-test--git root "-c" "user.name=Test"
                                  "-c" "user.email=test@example.invalid"
                                  "commit" "-qm" "Fixture")
       (with-temp-file file (insert "beta\n"))
       (dl-agent-review-test--git root "add" "example.txt")
       (unwind-protect
           (progn ,@body)
         (my/agent-review-stop)
         (dolist (buffer (buffer-list))
           (when (with-current-buffer buffer
                   (and (derived-mode-p 'magit-mode)
                        (string-prefix-p root default-directory)))
             (kill-buffer buffer)))))))

(ert-deftest dl-agent-review-external-edit-comments-and-cleanup ()
  (dl-agent-review-test--with-repo
    (let* ((diff (my/agent-review-start root))
           (status my/agent-review--status-buffer)
           (watch-count (hash-table-count magit-filenotify-data)))
      ;; Revisiting status must not drop the review hook or duplicate watches.
      (magit-status-setup-buffer root)
      (should (= watch-count (hash-table-count magit-filenotify-data)))
      (with-current-buffer status (should magit-filenotify-mode))
      (with-current-buffer diff
        (should (derived-mode-p 'magit-diff-mode))
        ;; The initial edit is staged; the HEAD diff must still include it.
        (goto-char (point-min))
        (search-forward "+beta")
        (hunk-notes-comment-dwim "Please explain this change")
        (should (file-exists-p (hunk-notes-storage-file))))
      ;; Force the next genuine inotify event onto the immediate path, so
      ;; this test does not depend on idle timers in noninteractive Emacs.
      (puthash status (time-subtract (current-time) (seconds-to-time 5))
               magit-filenotify--last-event-times)
      (should (zerop (call-process "python3" nil nil nil "-c"
                                   "import pathlib,sys; pathlib.Path(sys.argv[1]).write_text('gamma\\n')"
                                   file)))
      (let ((deadline (+ (float-time) 5)))
        (while (and (< (float-time) deadline)
                    (not (with-current-buffer diff
                           (save-excursion
                             (goto-char (point-min))
                             (search-forward "+gamma" nil t)))))
          (read-event nil nil 0.05)))
      (with-current-buffer diff
        (goto-char (point-min))
        (should (search-forward "+gamma" nil t))
        (should (= 1 (length hunk-notes-comments)))
        (should hunk-notes--overlays)
        (hunk-notes-copy-prompt)
        (should (string-match-p "Please explain this change" (current-kill 0)))
        (should (string-match-p "gamma" (current-kill 0))))
      ;; A commit can change only Git metadata.  The live HEAD comparison
      ;; must drop the committed edit even without another worktree write.
      (dl-agent-review-test--git root "add" "example.txt")
      (dl-agent-review-test--git root "-c" "user.name=Test"
                                 "-c" "user.email=test@example.invalid"
                                 "commit" "-qm" "Agent commit")
      (let ((deadline (+ (float-time) 3)))
        (while (and (< (float-time) deadline)
                    (with-current-buffer diff
                      (save-excursion
                        (goto-char (point-min))
                        (search-forward "+gamma" nil t))))
          (read-event nil nil 0.05)))
      (with-current-buffer diff
        (goto-char (point-min))
        (should-not (search-forward "+gamma" nil t)))
      (my/agent-review-start root)
      (should (= watch-count (hash-table-count magit-filenotify-data)))
      (kill-buffer my/agent-review--diff-buffer)
      (should-not my/agent-review--status-buffer)
      (should-not my/agent-review--git-watches)
      (should-not my/agent-review--git-timer)
      (with-current-buffer status (should-not magit-filenotify-mode))
      (should (= 0 (hash-table-count magit-filenotify-data))))))

(ert-deftest dl-agent-review-defers-refresh-during-comment-entry ()
  (dl-agent-review-test--with-repo
    (let ((diff (my/agent-review-start root)))
      (with-temp-file file (insert "gamma\n"))
      (cl-letf (((symbol-function 'my/agent-review--editing-p) (lambda () t)))
        (with-current-buffer my/agent-review--status-buffer (magit-refresh-buffer)))
      (should my/agent-review--pending)
      (with-current-buffer diff
        (goto-char (point-min))
        (should (search-forward "+beta" nil t)))
      (cl-letf (((symbol-function 'my/agent-review--editing-p) (lambda () nil)))
        (my/agent-review--flush))
      (should-not my/agent-review--pending)
      (with-current-buffer diff
        (goto-char (point-min))
        (should (search-forward "+gamma" nil t)))
      (should-not (memq #'my/agent-review--flush post-command-hook)))))

(ert-deftest dl-agent-review-preserves-an-existing-watcher ()
  (dl-agent-review-test--with-repo
    (let ((status (magit-status-setup-buffer root)))
      (with-current-buffer status (magit-filenotify-mode 1))
      (unwind-protect
          (progn
            (my/agent-review-start root)
            (my/agent-review-stop)
            (with-current-buffer status (should magit-filenotify-mode)))
        (with-current-buffer status (magit-filenotify-mode -1))))))

(provide 'dl-agent-review-test)
;;; dl-agent-review-test.el ends here
