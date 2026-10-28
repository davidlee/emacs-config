;;; dl-umbriel.el --- Focus server frames under umbriel -*- lexical-binding: t; -*-

;; Wayland gives focus only to a client holding an activation token, and
;; emacsclient brings none: when it reuses a frame, the server's
;; `select-frame-set-input-focus' leaves that frame behind the terminal.
;; Ask umbriel, the compositor, to focus the frame's window instead: the
;; window this process owns that bears the frame's title.

(require 'seq)

(defun dl-umbriel-window-id (windows pid title)
  "Id of the window in WINDOWS that PID owns and that bears TITLE.
WINDOWS is the parsed output of `umbriel windows --json'."
  (alist-get 'id (seq-find (lambda (window)
                             (and (eql (alist-get 'pid window) pid)
                                  (equal (alist-get 'title window) title)))
                           windows)))

(defun dl-umbriel--windows ()
  "Umbriel's windows, or nil when umbriel is not running."
  (with-temp-buffer
    (and (eql 0 (ignore-errors
                  (call-process "umbriel" nil '(t nil) nil "windows" "--json")))
         (progn (goto-char (point-min))
                (json-parse-buffer :object-type 'alist :array-type 'list)))))

(defun dl-umbriel-focus-frame (&optional frame)
  "Ask umbriel to focus FRAME's window; FRAME defaults to the selected one."
  (let ((frame (or frame (selected-frame))))
    (when-let* (((eq (framep frame) 'pgtk))
                (id (dl-umbriel-window-id (dl-umbriel--windows) (emacs-pid)
                                          (frame-parameter frame 'name))))
      (call-process "umbriel" nil 0 nil "msg" (concat "window-focus:" id)))))

;; Runs once the server has selected the frame showing the client's file.
(add-hook 'server-switch-hook #'dl-umbriel-focus-frame)

(provide 'dl-umbriel)
;;; dl-umbriel.el ends here
