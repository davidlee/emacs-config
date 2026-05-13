;; https://github.com/xenodium/dwim-shell-command
;; https://github.com/xenodium/dwim-shell-command/blob/main/dwim-shell-commands.el
(use-package dwim-shell-command
  :bind (([remap shell-command] . dwim-shell-command)
          :map dired-mode-map
          ([remap dired-do-async-shell-command] . dwim-shell-command)
          ([remap dired-do-shell-command] . dwim-shell-command)
          ([remap dired-smart-shell-command] . dwim-shell-command))
  :config
  ;; (defun my/dwim-shell-command-convert-to-gif ()
  ;;   "Convert all marked videos to optimized gif(s)."
  ;;   (interactive)
  ;;   (dwim-shell-command-on-marked-files
  ;;    "Convert to gif"
  ;;    "ffmpeg -loglevel quiet -stats -y -i '<<f>>' -pix_fmt rgb24 -r 15 '<<fne>>.gif'"
  ;;    :utils "ffmpeg"))
  )

(provide 'dl-dwim)
