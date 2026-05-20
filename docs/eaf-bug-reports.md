# EAF bug reports

Two upstream issues found while getting `eaf-browser` to run on NixOS + Sway
+ `emacs-unstable-pgtk`. Each is independent; both need fixing to make EAF
work on Wayland-native Emacs out of the box.

---

## 1. EAF: refcount bug in `reinput/main.c` causes SIGSEGV on startup

**Repo:** `emacs-eaf/emacs-application-framework`
**File:** `reinput/main.c`, function `get_kbd_device`
**Symptom:** `reinput` segfaults immediately on launch on any system. EAF
masks this by ignoring `reinput`'s exit; the first focus change then writes
to its closed stdin and python aborts with `BrokenPipeError` → `qAbort()` →
SIGABRT. Visible to users as "EAF process aborted (core dumped)" after a
click.

**Cause:** `libinput_event_get_device()` returns a *non-owning* pointer.
`reinput` calls `libinput_device_unref(dev)` on it, dropping the refcount
below zero. When `libinput_unref(li)` later tears the context down,
`evdev_device_remove` walks freed memory and dereferences NULL.

Backtrace (gdb):

```
#0 evdev_device_remove ()       libinput.so.10
#1 udev_input_disable ()        libinput.so.10
#2 libinput_unref ()            libinput.so.10
#3 main ()                      reinput
```

**Fix:** delete one line.

```diff
--- a/reinput/main.c
+++ b/reinput/main.c
@@ -75,7 +75,6 @@ static void get_kbd_device(void)
                        udev_device_unref(udev_device);
                }

-               libinput_device_unref(dev);
                libinput_event_destroy(ev);
                libinput_dispatch(li);
        }
```

`libinput_event_get_device()` per upstream docs:
> The device is not refcounted and may not be used after the event has been
> destroyed.

So no unref is needed (and none is correct).

**Reproduction:** any Linux box.

```
git clone https://github.com/emacs-eaf/emacs-application-framework
cd emacs-application-framework/reinput
cc -O2 -o reinput main.c $(pkg-config --cflags --libs libinput libevdev libudev) -lpthread
./reinput 9999 </dev/null   # exit 139 (SIGSEGV)
```

After patch: stays in scanf loop indefinitely (correct behaviour).

---

## 2. nixpkgs: `emacs-application-framework` derivation never builds/ships `reinput`

**Repo:** `NixOS/nixpkgs`
**File:** `pkgs/applications/editors/emacs/elisp-packages/manual-packages/emacs-application-framework/package.nix`
**Symptom:** On Sway/Hyprland with `emacs-unstable-pgtk`, the EAF python
process aborts on startup:

```
sh: line 1: …/eaf-XXX/reinput/reinput: No such file or directory
BrokenPipeError: [Errno 32] Broken pipe   (core/view.py: reinput.stdin.flush)
Process *eaf* aborted (core dumped)
```

**Cause:** `core/view.py` unconditionally `Popen`s `reinput/reinput` when
`current_desktop in ["sway", "Hyprland"]` and Emacs is running in
Wayland-native (pgtk) mode. The nixpkgs derivation:

- doesn't list `reinput` in its `files` whitelist, so even if it were
  pre-built it wouldn't be installed;
- has no build step compiling `reinput/main.c`;
- doesn't declare `libinput`/`libevdev`/`libudev` as build inputs.

Result: EAF is unusable on the most common Wayland compositors when paired
with the pgtk Emacs builds that nixpkgs ships.

**Fix sketch:**

```nix
nativeBuildInputs = [ pkg-config ];
buildInputs = [ libinput libevdev udev ];   # libudev via systemd alias

preBuild = ''
  cc -O2 -o reinput/reinput reinput/main.c \
    $(pkg-config --cflags --libs libinput libevdev libudev) \
    -lpthread
'';

files = ''
  ("*.el" "*.py" "applications.json" "core" "extension"
   ("reinput" "reinput/reinput"))
'';
```

(or copy `reinput/reinput` explicitly in `postInstall` if MELPA's `files`
recipe form doesn't tolerate a single-binary nested entry).

**Workaround** (currently in this repo at
`flakes/modules/home/emacs.nix`): override `emacs-application-framework`
locally with the same `preBuild`/`postInstall` and a `substituteInPlace`
that applies bug 1's patch until upstream merges.

**Verification:** after both fixes, `M-x eaf-open-browser` works on Sway +
pgtk Emacs, including focus changes (click in/out of the EAF buffer).
