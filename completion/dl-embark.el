;;; dl-embark.el --- EMBARK -*- lexical-binding: t; -*-

(use-package embark
  :bind (("C-." . embark-act)
         ("C-;" . embark-dwim)
         ("C-h B" . embark-bindings)))

(use-package embark-consult
  :after (embark consult))

(provide 'dl-embark)
