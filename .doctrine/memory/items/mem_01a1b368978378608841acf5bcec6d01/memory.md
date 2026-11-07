Batch ERT cannot see pixels. To check faces or layout, render the real frame and read the image:

```elisp
(with-temp-file "/path/frame.png"   ; a scratch path
  (set-buffer-multibyte nil)
  (insert (x-export-frames (window-frame (get-buffer-window "*umbriel*" t)) 'png)))
```

- Run it via `emacsclient --eval` on a `load`ed file; quoting a long form inline is fragile.
- Call `(redisplay t)` first when you have just repainted.
- This caught missing `:align-to` gaps that every batch test passed.
- Don't use `make-frame` to probe a live session: the frame inherits the `client` parameter and is easy to leak.
