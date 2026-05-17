;;; dl-org-capture.el --- Org capture templates and helpers -*- lexical-binding: t; -*-

(require 'dl-notes-paths)

;; Capture-body helpers.  Each builder returns a 0-arg function that
;; assembles the body lazily, so templates read one line per list entry
;; instead of a single string speckled with `\n'.

(defun my/capture-body (&rest lines)
  "Return a 0-arg fn that joins LINES with newlines into a capture body."
  (lambda () (string-join lines "\n")))

(defun my/capture-entry (heading &rest body-lines)
  "Like `my/capture-body' but wraps HEADING with a standard properties drawer.
Result:
  HEADING
  :PROPERTIES:
  :CREATED: %U
  :END:
  BODY-LINES..."
  (apply #'my/capture-body
    heading
    ":PROPERTIES:"
    ":CREATED: %U"
    ":END:"
    body-lines))

(setq org-capture-templates
  `(("i" "Inbox" entry
      (file ,dl-notes-inbox-file)
      (function ,(my/capture-entry "* TODO %?")))

     ("f" "Fleeting note" entry
       (file ,dl-notes-inbox-file)
       (function ,(my/capture-entry "* %?")))

     ("j" "Journal entry" entry
       (file+datetree ,(my/notes-path "journal" "log.org"))
       "* %U %?\n")

     ("P" "Project task" entry
       (file ,dl-notes-inbox-file)
       (function ,(my/capture-entry "* TODO %?" ":project:")))

     ("r" "Reading note" entry
       (file ,dl-notes-inbox-file)
       (function ,(my/capture-entry "* Reading: %?")))

     ;; these last two are for https://github.com/sprig/org-capture-extension
     ("p" "Protocol" entry
       (file+headline ,(my/notes-path "protocol.org") "Inbox")
       (function ,(my/capture-body
                    "* %^{Title|%:description}"
                    "Source: %:link"
                    "Captured: %U"
                    ""
                    "#+BEGIN_QUOTE"
                    "%i"
                    "#+END_QUOTE"
                    ""
                    "%?%(progn (setq my/org-capture-delete-frame-on-finalize t) \"\")"))
       :empty-lines 1)

     ("L" "Protocol Link" entry
       (file+headline ,(my/notes-path "protocol.org") "Inbox")
       (function ,(my/capture-body
                    "* %? [[%:link][%(my/sanitize-link-description \"%:description\")]]"
                    "Captured: %U"
                    "%(progn (setq my/org-capture-delete-frame-on-finalize t) \"\")"))
       :empty-lines 1)))

;; Org-protocol helpers — sanitizing link descriptions and auto-closing
;; the emacsclient-spawned frame after the browser-driven capture finishes.

(defun my/sanitize-link-description (s)
  "Replace [ and ] in S with ( and ).
Page titles can contain square brackets (ArXiv is the canonical
offender), which break `[[link][description]]'."
  (replace-regexp-in-string   "\\]" ")"
    (replace-regexp-in-string "\\[" "(" s)))

(defvar my/org-capture-delete-frame-on-finalize nil
  "When non-nil, delete the current frame after the next capture finishes.
Set by Protocol templates so the emacsclient-spawned frame goes away
when the user finalizes or aborts.  Guarded to no-op unless the frame
was actually created by emacsclient, so local `\\[org-capture]' invocations
in the main frame are safe.")

(defun my/org-capture-delete-client-frame (&rest _)
  "Delete current frame iff a capture template asked for it."
  (when (and my/org-capture-delete-frame-on-finalize
          (frame-parameter nil 'client)
          (cdr (frame-list)))         ; never delete the last frame
    (setq my/org-capture-delete-frame-on-finalize nil)
    (delete-frame)))

;; `org-capture-refile' calls `org-capture-finalize' internally, so the
;; finalize advice covers refile too; only kill needs separate wiring.
(advice-add 'org-capture-finalize :after #'my/org-capture-delete-client-frame)
(advice-add 'org-capture-kill     :after #'my/org-capture-delete-client-frame)

(global-set-key (kbd "C-c c") #'org-capture)

(provide 'dl-org-capture)
;;; dl-org-capture.el ends here
