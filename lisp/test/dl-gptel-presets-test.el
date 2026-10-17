;;; dl-gptel-presets-test.el --- ert tests for gptel presets -*- lexical-binding: t; -*-

;; Run: `just check' (dl-test scans lisp/test), or M-x ert RET dl-gptel-presets RET.

;;; Code:

(require 'ert)
(require 'gptel-openai)
(require 'gptel-openai-extras)
(require 'dl-gptel-presets)
(require 'dl-gptel-shape)

(defconst dl-gptel-presets-test--tools
  '(("Glob") ("Grep") ("Read") ("Insert") ("Edit") ("Write") ("Mkdir")
    ("Eval") ("Bash") ("WebSearch") ("WebFetch")
    ("describe_symbol" . "introspection")
    ("org-read" . "mcp-org-mcp"))
  "Stand-ins for the tools the presets name: (NAME . CATEGORY).")

(defconst dl-gptel-presets-test--backends
  '(("openai-sub" gptel-make-openai "api.openai.com")
    ("deepseek" gptel-make-deepseek "127.0.0.1:4000")
    ("openrouter" gptel-make-openai "openrouter.ai")
    ("fireworks" gptel-make-openai "api.fireworks.ai"))
  "Stand-ins for the backends the presets name: (NAME CONSTRUCTOR HOST).
CONSTRUCTOR gives the backend its real class, which request shaping
dispatches on.  The host picks gptel's API dialect: Responses for
OpenAI, else chat completions.")

(defmacro dl-gptel-presets-test--sandbox (&rest body)
  "Run BODY against fake tools and backends, with gptel's options isolated.
Prompts are read from a fresh directory holding lib.org, and org-mcp is
not connected."
  `(let ((gptel--known-tools nil)
         (gptel--known-backends nil)
         (gptel-tools nil)
         (gptel-backend nil)
         (gptel-model nil)
         (gptel-system-prompt nil)
         (gptel-context nil)
         (gptel--request-params nil)
         (gptel--preset nil)
         (dl-gptel-prompt-dir (make-temp-file "dl-gptel-presets-test" t)))
     (unwind-protect
         (cl-letf (((symbol-function 'dl-gptel-mcp-org-connect) #'ignore))
           (pcase-dolist (`(,name . ,category) dl-gptel-presets-test--tools)
             (gptel-make-tool :name name :function #'ignore :args nil
                              :description name
                              :category (or category "test")))
           (pcase-dolist (`(,name ,make ,host) dl-gptel-presets-test--backends)
             (funcall make name :key "test" :host host))
           (write-region "#+title: lib\n\nFile notes.\n" nil
                         (expand-file-name "lib.org" dl-gptel-prompt-dir))
           ,@body)
       (delete-directory dl-gptel-prompt-dir t))))

(defun dl-gptel-presets-test--request (&rest presets)
  "Apply PRESETS in order, then return the request body gptel would send."
  (mapc #'gptel--apply-preset presets)
  (gptel--request-data gptel-backend (list '(:role "user" :content "hi"))))

(defun dl-gptel-presets-test--effort-in-both-orders (model effort)
  "Apply presets MODEL and EFFORT in both orders; return what each sends.
One (ORDER REASONING-EFFORT NESTED) per order, NESTED being the
:reasoning entry of the request body, or nil if there is none."
  (mapcar (lambda (order)
            (let ((data (apply #'dl-gptel-presets-test--request order)))
              (list order
                    (plist-get data :reasoning_effort)
                    (plist-member data :reasoning))))
          (list (list model effort) (list effort model))))

(defun dl-gptel-presets-test--tool-names ()
  "Return the names of the active tools, sorted."
  (sort (mapcar #'gptel-tool-name gptel-tools) #'string<))

(ert-deftest dl-gptel-presets/every-preset-applies ()
  "Each preset names only tools, backends and prompts that exist."
  (dl-gptel-presets-test--sandbox
   (dolist (preset dl-gptel-presets)
     (should (progn (gptel--apply-preset (car preset)) t)))))

(ert-deftest dl-gptel-presets/prompt-drops-org-keywords ()
  "A prompt file's #+keyword lines are front matter, not prompt."
  (dl-gptel-presets-test--sandbox
   (should (equal (dl-gptel-prompt "lib") "File notes."))))

(ert-deftest dl-gptel-presets/missing-prompt-is-a-user-error ()
  (dl-gptel-presets-test--sandbox
   (should-error (dl-gptel-prompt "nope") :type 'user-error)))

(ert-deftest dl-gptel-presets/ro-drops-tools-that-write ()
  "@ro keeps reading tools and drops anything that writes or executes."
  (dl-gptel-presets-test--sandbox
   (gptel--apply-preset 'default)
   (gptel--apply-preset 'ro)
   (should (equal (dl-gptel-presets-test--tool-names)
                  '("Glob" "Grep" "Read" "describe_symbol")))))

(ert-deftest dl-gptel-presets/lib-reads-notes-and-writes-only-through-org ()
  "@lib: its own prompt, reading tools and org-mcp, no file or shell writes."
  (dl-gptel-presets-test--sandbox
   (gptel--apply-preset 'lib)
   (should (equal gptel-system-prompt "File notes."))
   (should (equal (dl-gptel-presets-test--tool-names)
                  '("Glob" "Grep" "Read" "describe_symbol" "org-read")))))

(ert-deftest dl-gptel-presets/mixins-keep-the-role ()
  "Model, effort and tool mixins leave the role's prompt alone."
  (dl-gptel-presets-test--sandbox
   (gptel--apply-preset 'lib)
   (dolist (mixin '(deep think web see))
     (gptel--apply-preset mixin))
   (should (equal gptel-system-prompt "File notes."))
   (should (equal (gptel-backend-name gptel-backend) "deepseek"))
   (should (member "WebFetch" (dl-gptel-presets-test--tool-names)))))

(ert-deftest dl-gptel-presets/deep-is-deepseek-flash-on-the-gateway ()
  "@deep picks DeepSeek flash on the deepseek backend, which is the gateway."
  (dl-gptel-presets-test--sandbox
   (gptel--apply-preset 'deep)
   (should (equal (gptel-backend-name gptel-backend) "deepseek"))
   (should (eq gptel-model 'deepseek-flash))))

(ert-deftest dl-gptel-presets/effort-merges-and-last-wins ()
  "Effort presets merge into the request params; the later one wins."
  (dl-gptel-presets-test--sandbox
   (setq gptel--request-params '(:store :json-false))
   (gptel--apply-preset 'quick)
   (gptel--apply-preset 'think)
   (should (equal (plist-get gptel--request-params :store) :json-false))
   (should (equal (plist-get gptel--request-params :reasoning)
                  '(:effort "high")))))

(ert-deftest dl-gptel-presets/effort-reaches-fireworks-flat-in-any-order ()
  "Fireworks gets effort as reasoning_effort, whichever cookie comes first."
  (dl-gptel-presets-test--sandbox
   (dolist (order '((nemo think) (think nemo)))
     (let ((data (apply #'dl-gptel-presets-test--request order)))
       (should (equal (plist-get data :reasoning_effort) "high"))
       (should-not (plist-member data :reasoning))))))

(ert-deftest dl-gptel-presets/quick-turns-deepseek-thinking-off-in-any-order ()
  "@quick on DeepSeek sends effort \"none\", whichever cookie comes first.
The control is plain flattening: it sends \"low\", which the gateway
turns into thinking on, since DeepSeek's thinking is only on or off."
  (dl-gptel-presets-test--sandbox
   (should (equal (dl-gptel-presets-test--effort-in-both-orders 'deep 'quick)
                  '(((deep quick) "none" nil) ((quick deep) "none" nil))))))

(ert-deftest dl-gptel-presets/think-reaches-deepseek-flat-in-any-order ()
  "@think on DeepSeek sends effort \"high\" flat, whichever cookie comes first."
  (dl-gptel-presets-test--sandbox
   (should (equal (dl-gptel-presets-test--effort-in-both-orders 'deep 'think)
                  '(((deep think) "high" nil) ((think deep) "high" nil))))))

(ert-deftest dl-gptel-presets/effort-reaches-openrouter-nested ()
  "Backends without a shaper get the effort presets' request params as is."
  (dl-gptel-presets-test--sandbox
   (let ((data (dl-gptel-presets-test--request 'gem 'quick)))
     (should (equal (plist-get data :reasoning) '(:effort "low")))
     (should-not (plist-member data :reasoning_effort)))))

(ert-deftest dl-gptel-presets/see-adds-visible-buffers-but-not-chats ()
  "@see adds the buffers on screen to the context, leaving out gptel chats."
  (dl-gptel-presets-test--sandbox
   (let ((note (generate-new-buffer "note"))
         (chat (generate-new-buffer "chat")))
     (unwind-protect
         (save-window-excursion
           (delete-other-windows)
           (switch-to-buffer note)
           (with-current-buffer chat (setq-local gptel-mode t))
           (set-window-buffer (split-window) chat)
           (gptel--apply-preset 'see)
           (should (equal gptel-context (list note))))
       (kill-buffer note)
       (kill-buffer chat)))))

(provide 'dl-gptel-presets-test)
;;; dl-gptel-presets-test.el ends here
