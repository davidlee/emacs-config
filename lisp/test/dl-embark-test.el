;;; dl-embark-test.el --- ert tests for dl-embark wiring -*- lexical-binding: t; -*-

;; Run: `just check' (dl-test scans lisp/test), or M-x ert RET dl-embark RET.

(require 'ert)
(require 'dl-embark)

(ert-deftest dl-embark/act-bound-globally ()
  "`C-,' reaches `embark-act', and the command can load on demand."
  (should (eq (keymap-lookup global-map "C-,") #'embark-act))
  (should (fboundp 'embark-act)))

(ert-deftest dl-embark/dwim-bound-globally ()
  "`M-.' runs `embark-dwim', which still reaches xref on identifiers."
  (should (eq (keymap-lookup global-map "M-.") #'embark-dwim)))

(ert-deftest dl-embark/act-wins-in-org ()
  "Org's own `C-,' (`org-cycle-agenda-files', also on `C-'') yields to embark."
  (require 'org)
  (should (eq (keymap-lookup org-mode-map "C-,") #'embark-act)))

(ert-deftest dl-embark/avy-dispatch-registered ()
  "After avy loads, `.' in avy's dispatch runs embark at the target."
  (require 'avy)
  (should (eq (alist-get ?. avy-dispatch-alist) #'dl-embark--avy-act)))

(provide 'dl-embark-test)
;;; dl-embark-test.el ends here
