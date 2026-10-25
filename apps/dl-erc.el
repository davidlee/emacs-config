;;; dl-erc.el --- IRC via ERC -*- lexical-binding: t; -*-

(require 'erc)
(require 'erc-join)

(add-to-list 'erc-autojoin-channels-alist '(libera . ("#lobsters")))

(defun dl-erc-lobsters (nickname)
  "Connect to Libera.Chat over TLS as NICKNAME and join #lobsters."
  (interactive (list (read-string "IRC nickname: ")))
  (erc-tls :server "irc.libera.chat"
           :port 6697
           :nick nickname
           :id 'libera))

(provide 'dl-erc)
;;; dl-erc.el ends here
