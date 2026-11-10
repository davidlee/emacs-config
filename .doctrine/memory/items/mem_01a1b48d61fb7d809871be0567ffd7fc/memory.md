`window-move-to-scratchpad` picks its window with `FocusSource::Workspace`: the remembered focus of the active workspace on the pointer's output, whatever holds the keyboard (umbriel `src/server/actions.cpp`, `placementTarget`, `actionMoveToScratchpad`). Read from source at 675306d9, not run live.

So `window-focus ROW` first does not aim it when ROW is a pad window, or on another output (`window-focus` leaves the pointer unless `input.cursor.follows_focus` is set; it is off here). It then sends a different window, often the Emacs frame. `window-move-to-workspace[-silent]` differs: it uses the scratchpad focus, then the most recent window, so `m` is not affected.

It also never moves a window between pads: `ScratchpadManager::admit` returns false for an interactive move of a member, and the IPC reply is still ok because no error string is set.

`umbriel-send-to-pad` (`P`) refuses those rows through `pointer-window` addressing (IMP-031).