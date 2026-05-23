;;; dl-satan-tools-sway.el --- sway window-border tools -*- lexical-binding: t; -*-

;; Two tools for ephemeral sway styling.  Runtime-only: no file writes;
;; `swaymsg reload' returns to the declarations in `~/.config/sway/config'.
;; Keybindings, exec lines, and other config entries are unreachable by
;; construction — the tool grammar admits only `client.<class>' commands
;; whose argument list is six-tuples of validated hex colours.

(require 'cl-lib)
(require 'dl-satan-tools)

(defconst dl-satan-sway-classes
  '("focused" "focused_inactive" "focused_tab_title"
    "unfocused" "urgent" "placeholder")
  "Sway client classes that take five-colour records.
`background' is intentionally excluded — it takes a single colour and
needs a different shape.")

(defconst dl-satan-sway-hex-pattern
  "\\`#[0-9a-fA-F]\\{6\\}\\'"
  "Strict #RRGGBB matcher.  Anchored on both ends.")

(defcustom dl-satan-sway-swaymsg-program
  (or (executable-find "swaymsg") "swaymsg")
  "Path to the `swaymsg' binary."
  :type 'string :group 'dl-satan)

(defun dl-satan-sway--swaymsg (&rest args)
  "Invoke `swaymsg' with ARGS via `call-process'.  No shell.
Return (ok . OUTPUT) on success, (error . MSG) on non-zero exit."
  (with-temp-buffer
    (let ((status (apply #'call-process
                         dl-satan-sway-swaymsg-program nil t nil args)))
      (if (and (integerp status) (zerop status))
          (cons 'ok (string-trim (buffer-string)))
        (cons 'error
              (format "swaymsg exit %s: %s"
                      status (string-trim (buffer-string))))))))

(defun dl-satan-sway--class-args (record)
  "Return the positional colour argv for sway's `client.<class>' command.
RECORD is a plist with :border, :background, :text, optionally
:indicator and :child_border.  Schema validation has already
enforced types and hex format; this fn only enforces sway's grammar:
border, background, text are required; indicator and child_border
are optional but child_border requires indicator."
  (let ((border (plist-get record :border))
        (bg     (plist-get record :background))
        (text   (plist-get record :text))
        (ind    (plist-get record :indicator))
        (child  (plist-get record :child_border)))
    (cond
     ((not (and border bg text))
      (cons 'error "each class requires border, background, text"))
     ((and child (null ind))
      (cons 'error "child_border requires indicator"))
     (t
      (cons 'ok (delq nil (list border bg text ind child)))))))

(defun dl-satan-tool/sway-border-set (args _ctx)
  "Batched border setter.  Issues one swaymsg per declared class.
ARGS: (:classes (:CLASS (:border ... :background ... :text ...
        [:indicator ...] [:child_border ...]) ...)).
At least one class must be declared.  Returns
  (ok :applied (CLASS ...))
or
  (error MSG)
on first failure; classes already applied stay applied (sway has
no atomic transaction).  The error includes which class failed."
  (let ((classes (plist-get args :classes)))
    (cond
     ((not (and (listp classes) classes))
      (cons 'error "classes must be a non-empty object"))
     (t
      (let ((applied nil)
            (err nil)
            (cursor classes))
        (while (and cursor (null err))
          (let* ((key (car cursor))
                 (record (cadr cursor))
                 (class-name (substring (symbol-name key) 1)))
            (cond
             ((not (member class-name dl-satan-sway-classes))
              (setq err (format "unknown class: %s" class-name)))
             ((null record)
              (setq err (format "class %s: empty record" class-name)))
             (t
              (let ((argv (dl-satan-sway--class-args record)))
                (if (eq (car argv) 'error)
                    (setq err (format "class %s: %s" class-name (cdr argv)))
                  (let ((res (apply #'dl-satan-sway--swaymsg
                                    (concat "client." class-name)
                                    (cdr argv))))
                    (if (eq (car res) 'error)
                        (setq err (format "class %s: %s" class-name (cdr res)))
                      (push class-name applied))))))))
          (setq cursor (cddr cursor)))
        (if err
            (cons 'error err)
          (cons 'ok (list :applied (nreverse applied)))))))))

(defun dl-satan-tool/sway-border-reset (_args _ctx)
  "Re-read `~/.config/sway/config' via `swaymsg reload'.
Reverts every border declaration to its sway.conf value."
  (let ((res (dl-satan-sway--swaymsg "reload")))
    (if (eq (car res) 'ok)
        (cons 'ok (list :reloaded t))
      res)))

(let ((colour-field
       (list :type 'string
             :required t
             :pattern dl-satan-sway-hex-pattern))
      (colour-field-optional
       (list :type 'string
             :required nil
             :pattern dl-satan-sway-hex-pattern)))
  (let* ((class-shape
          (list 'border       colour-field
                'background   colour-field
                'text         colour-field
                'indicator    colour-field-optional
                'child_border colour-field-optional))
         (classes-shape
          (apply #'append
                 (mapcar (lambda (cls)
                           (list (intern cls)
                                 (list :type 'object
                                       :required nil
                                       :shape class-shape)))
                         dl-satan-sway-classes))))
    (dl-satan-tool-register
     (list :name "sway_border_set"
           :risk 'medium
           :args-schema (list 'classes
                              (list :type 'object
                                    :required t
                                    :shape classes-shape))
           :handler 'dl-satan-tool/sway-border-set))))

(dl-satan-tool-register
 (list :name "sway_border_reset"
       :risk 'medium
       :args-schema nil
       :handler 'dl-satan-tool/sway-border-reset))

(provide 'dl-satan-tools-sway)
;;; dl-satan-tools-sway.el ends here
