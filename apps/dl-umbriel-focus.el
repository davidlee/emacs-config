;;; dl-umbriel-focus.el --- Focus server frames under umbriel -*- lexical-binding: t; -*-

;; Wayland gives focus only to a client holding an activation token, and
;; emacsclient brings none: when it reuses a frame, the server's
;; `select-frame-set-input-focus' leaves that frame behind the terminal.
;; Ask umbriel, the compositor, to focus the frame's window instead: the
;; window this process owns that bears the frame's title.
;;
;; Titles are not unique — two frames showing one buffer share one — so
;; the first match wins.

(require 'seq)
(require 'dl-umbriel)

(defun dl-umbriel-window-id (windows pid title)
  "Id of the window in WINDOWS that PID owns and that bears TITLE.
WINDOWS is the reply to umbriel's `windows' query."
  (alist-get 'id (seq-find (lambda (window)
                             (and (eql (alist-get 'pid window) pid)
                                  (equal (alist-get 'title window) title)))
                           windows)))

(defun dl-umbriel-focus-frame (&optional frame)
  "Ask umbriel to focus FRAME's window; FRAME defaults to the selected one."
  (interactive)
  (let ((frame (or frame (selected-frame))))
    (when (eq (framep frame) 'pgtk)
      (let ((title (frame-parameter frame 'name)))
        (dl-umbriel-send
         (dl-umbriel-query "windows")
         (lambda (result)
           (pcase result
             (`(:ok ,windows)
              (when-let* ((id (dl-umbriel-window-id windows (emacs-pid) title)))
                (dl-umbriel-send (dl-umbriel-action "window-focus" `((window . ,id)))
                                 #'dl-umbriel-echo-failure)))
             (_ (dl-umbriel-echo-failure result)))))))))

;; Runs once the server has selected the frame showing the client's file.
(add-hook 'server-switch-hook #'dl-umbriel-focus-frame)

(provide 'dl-umbriel-focus)
;;; dl-umbriel-focus.el ends here
