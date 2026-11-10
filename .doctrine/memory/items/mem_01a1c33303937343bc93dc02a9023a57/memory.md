# Firefox Developer Edition wiring

Verified 2026-11-10 (IDE-005).

- **Why Dev Edition:** foxmacs' extensions are unsigned; release Firefox
  enforces signing. Home-manager `programs.firefox` in ~/flakes
  `features/web.nix` sets `firefox-devedition.override { extraPrefs }`
  (`xpinstall.signatures.required=false`) and force-installs the extensions
  via `globalExtensions` (each needs `passthru.addonId`).
- **Profile trap:** the nixpkgs wrapper sets `MOZ_LEGACY_PROFILES=1`, yet Dev
  Edition still opens the profile *named* `dev-edition-default`. To share the
  main profile, `~/.config/mozilla/firefox/profiles.ini` (not Nix-managed)
  names `ez06zp0k.default` `dev-edition-default` (still `Default=1`); the old
  Dev Edition profile is `dev-edition-old`. Backup:
  `profiles.ini.bak-2026-11-10`. Recreating profiles.ini loses this.
- **Name trap:** the binary and desktop file are `firefox-devedition`, so the
  release build's `firefox` command and `firefox.desktop` (what
  mimeapps.list's http/https defaults name) vanish. web.nix adds a `firefox`
  symlink and an `xdg.dataFile` firefox.desktop renamed "Firefox", and
  shadows firefox-devedition.desktop with `NoDisplay=true`. Anything matching
  the process name (1Password's `custom_allowed_browsers`) needs
  `firefox-devedition` too.
