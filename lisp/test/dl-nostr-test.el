;;; dl-nostr-test.el --- ert tests for nostr's 1Password key source -*- lexical-binding: t; -*-

;; Run: `just check' (dl-test scans lisp/test), or M-x ert RET dl-nostr RET.
;;
;; No test calls the real `op': `my/op-read' is stubbed.

(require 'ert)
(require 'cl-lib)
(require 'dl-nostr)

(defmacro dl-nostr-test--with-stub-op-read (calls-var &rest body)
  "Run BODY with `my/op-read' stubbed to return \"nsec1test\".
CALLS-VAR is bound to a list of (REF . CONTEXT), newest first."
  (declare (indent 1))
  `(let (,calls-var)
     (cl-letf (((symbol-function 'my/op-read)
                 (lambda (ref &optional _refresh)
                   (push (cons ref my/op-read-context) ,calls-var)
                   "nsec1test")))
       ,@body)))

(ert-deftest dl-nostr/secret-comes-from-1password ()
  "The key is `dl-nostr-secret-ref' resolved by `my/op-read', labelled nostr."
  (dl-nostr-test--with-stub-op-read calls
    (should (equal (dl-nostr--load-secret) "nsec1test"))
    (should (equal calls `((,dl-nostr-secret-ref . "nostr"))))))

(ert-deftest dl-nostr/nostr-reads-key-without-a-key-file ()
  "Both of nostr's key readers use 1Password; no GPG file need exist."
  (skip-unless (require 'nostr-setup nil t))
  (let ((nostr-private-key-path "/nonexistent/nostr-private.gpg"))
    (dl-nostr-test--with-stub-op-read calls
      (should (equal (nostr-backend-load-secret) "nsec1test"))
      (should (equal (nostr-setup--load-secret) "nsec1test"))
      (should (= (length calls) 2)))))

(ert-deftest dl-nostr/timeline-keys-beat-meow-motion ()
  "Search (`/') and open-identifier (`o') work in the timeline under meow.
Meow's motion map otherwise takes them; its arrows stay.
The map is registered as `meow-global-mode' does, ahead of minor modes."
  (skip-unless (require 'nostr-timeline nil t))
  (require 'meow)
  (require 'dl-keymap)
  (meow-setup)
  (let ((emulation-mode-map-alists
          (cons `((meow-motion-mode . ,meow-motion-state-keymap))
            emulation-mode-map-alists)))
    (with-temp-buffer
      (use-local-map nostr-timeline-mode-map)
      (meow-motion-mode)
      (run-hooks 'nostr-timeline-mode-hook)
      (should (eq (key-binding "/") #'nostr-search-open))
      (should (eq (key-binding "o") #'nostr-open-identifier))
      (should (eq (key-binding (kbd "<down>")) #'meow-next)))))

(provide 'dl-nostr-test)
;;; dl-nostr-test.el ends here
