;;; dl-erc.el --- IRC via ERC -*- lexical-binding: t; -*-

(require 'erc)
(require 'erc-join)

(add-to-list 'erc-autojoin-channels-alist '(libera . ("#lobsters"
                                                       "#emacs"
                                                       "#emacs-social"
                                                       "##rust"
                                                       "#rust-offtopic"
                                                       "##programming"
                                                       ;; "#postgresql"
                                                       ;; "#haskell"
                                                       "#zig"
                                                       "##llm")))

(defun dl-erc-libera (nickname)
  "Connect to Libera.Chat over TLS as NICKNAME.
ERC then joins the `libera' channels in `erc-autojoin-channels-alist'."
  (interactive (list (read-string "IRC nickname: ")))
  (erc-tls :server "irc.libera.chat"
    :port 6697
    :nick nickname
    :id 'libera))

(provide 'dl-erc)
;;; dl-erc.el ends here
