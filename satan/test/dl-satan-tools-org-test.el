;;; dl-satan-tools-org-test.el --- ert tests for dl-satan-tools-org -*- lexical-binding: t; -*-

;; Run from CLI:
;;   emacs --batch \
;;     -L ~/.emacs.d/core -L ~/.emacs.d/satan -L ~/.emacs.d/satan/test \
;;     -l dl-satan-tools-org-test.el -f ert-run-tests-batch-and-exit

(require 'ert)
(require 'cl-lib)
(require 'dl-satan-tools)
(require 'dl-satan-tools-org)
(require 'dl-satan-mode)

(ert-deftest dl-satan-org/update-owned-block-rejects-motd-target ()
  "motd is no longer a writable target; satan_final.summary owns motd."
  (let ((res (dl-satan-tool-dispatch
              '(:type "tool_call" :id "u1" :name "org_update_owned_block"
                :args (:target "motd" :block "satan" :content "x"))
              '("org_update_owned_block")
              '(:capabilities (write-daily)))))
    (should (equal (plist-get res :ok) :false))
    (should (string-match-p "target" (plist-get res :error)))))

(ert-deftest dl-satan-org/update-owned-block-tool-not-in-motd-mode ()
  "motd mode's :tools list must not include org_update_owned_block."
  (let* ((mode (dl-satan-mode-resolve "motd"))
         (tools (plist-get mode :tools)))
    (should-not (member "org_update_owned_block" tools))))

(ert-deftest dl-satan-org/update-owned-block-only-listed-by-morning ()
  "Mode `:tools' allowlist gates org_update_owned_block: morning yes, motd no.
T4 dropped the documentary `:modes' field from tool specs; the
mode-spec is now the single source of truth, enforced at load by
`dl-satan-mode-check-tool-references'."
  (let ((morning-tools (plist-get (dl-satan-mode-resolve "morning") :tools))
        (motd-tools    (plist-get (dl-satan-mode-resolve "motd") :tools)))
    (should     (member "org_update_owned_block" morning-tools))
    (should-not (member "org_update_owned_block" motd-tools))))

(provide 'dl-satan-tools-org-test)
;;; dl-satan-tools-org-test.el ends here
