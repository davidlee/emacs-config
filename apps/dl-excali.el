;;; dl-excali.el --- Excalidraw drawings on Emacs Canvas -*- lexical-binding: t; -*-

;; excali-mode opens, edits and saves .excalidraw scenes; its C module
;; draws them with Cairo/Pango into Emacs 32's `canvas' image type.  The
;; elisp and module come from ~/flakes/emacs (excali-mode input), built
;; against this Emacs.  Absent elsewhere (darwin's macport is not 32), so
;; everything here is lazy and guarded by the canvas image type.
;;
;; Commands: `excali-open' (a .excalidraw, or a PNG/SVG with an embedded
;; scene), `excali-new'.  `.excalidsl' text sources get `excali-dsl-mode'
;; (C-c C-c previews).  Excalidraw's fonts ship with the package.

(when (and (fboundp 'canvas-refresh)
           (image-type-available-p 'canvas)
           (locate-library "excali"))
  (use-package excali
    :ensure nil
    :commands (excali-open excali-new))

  (use-package excali-dsl
    :ensure nil
    :mode ("\\.excalidsl\\'" . excali-dsl-mode)))

(provide 'dl-excali)
;;; dl-excali.el ends here
