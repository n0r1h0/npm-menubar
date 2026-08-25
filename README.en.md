# npm-menubar

*[日本語](README.md)*

A menu bar app that watches your npm global packages (`npm install -g`) and
npm itself, and lets you upgrade them with one click from the macOS status
bar.

It's a standalone macOS app built with SwiftUI's `MenuBarExtra`
(`NpmMenuBar.app`) — no external menu bar runner (e.g. SwiftBar) is
required. It works with major version managers (Volta, nvm, fnm, ...).

## Download

If you'd rather not build it yourself, grab the latest `NpmMenuBar-*.zip`
from the [Releases](https://github.com/n0r1h0/npm-menubar/releases) page,
unzip it, and move `NpmMenuBar.app` into `/Applications`.

The release isn't notarized by Apple, so Gatekeeper may say it "can't be
opened because the developer cannot be verified" on first launch. If that
happens, right-click the app in Finder and choose "Open", or clear the
quarantine attribute from Terminal:

```sh
xattr -cr /Applications/NpmMenuBar.app
```

## Usage

Click the menu bar icon (📦) to see:

- The update status of npm itself and your global packages, with
  per-package upgrade or a combined "Upgrade All".
- "Hold at This Version" for packages you don't want to upgrade yet. Held
  packages move to "On Hold", which you can also manage from Preferences.
- With Volta, a "Node-bundled" submenu for npm/packages bundled inside the
  Node.js install itself (most people never need this).
- "Check Now", "Preferences...", and "Quit".

The status bar icon is 📦 when everything's current, 📦! when npm itself
has an update, or shows a count when global packages are outdated. It
fades in and out while checking. A notification only fires when the
pending count goes from 0 to N.

## Preferences

Open it from the menu's "Preferences...".

- **General**: launch at login, and display language (Follow System / 日本語 / English)
- **npm Core / Global Packages**: independently set the check frequency
  (15 min – 24h) and whether to auto-upgrade (OFF = notify only)
- **On Hold**: the list of packages pinned at their current version, with a
  way to remove the hold

Default check frequency is 3 hours; auto-upgrade is OFF by default.

## Build & run

Prerequisite: the `swift` command (Xcode Command Line Tools) must be
available, and `npm` must be resolvable on your login shell's PATH
(check with e.g. `zsh -l -c "which npm"`).

```sh
cd npm-menubar
./Scripts/build-app.sh
open NpmMenuBar.app
```

For regular use, move `NpmMenuBar.app` into `/Applications`. The app
doesn't show a Dock icon — it lives in the menu bar only.

## Known limitations

- On first launch, macOS asks for notification permission. This can fail
  unless the app lives in `/Applications` (the status bar icon still works
  fine either way).
- Every check spawns a login shell, so on machines with heavy `.zshrc`
  init logic this can add a few hundred ms to a few seconds per check.
- If npm can't be found, the menu shows a warning but doesn't attempt to
  install npm itself.
- If an upgrade fails (e.g. a version-manager-specific constraint), you'll
  see the error via a notification and in the menu.

## Uninstall

```sh
# If you registered it as a login item, turn that off in Preferences first, or:
osascript -e 'tell application "System Events" to delete login item "NpmMenuBar"' 2>/dev/null

rm -rf "/Applications/NpmMenuBar.app"   # if it's in /Applications
defaults delete com.local.npmmenubar 2>/dev/null
```
