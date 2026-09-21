# Package Browser

All of your Mac's package managers in one native macOS window.

Package Browser is a small SwiftUI app that scans every package manager on
your machine and shows everything you've installed in a single, searchable
list — no terminal required.

A **Dashboard** opens by default with your library at a glance: installed
total, pending updates, active managers, and a donut chart of how your
packages are composed across managers (click a slice's legend row to jump
to that manager's list).

## Supported package managers

| Manager  | What it shows                          |
| -------- | -------------------------------------- |
| Homebrew | Formulae and casks, incl. outdated state and dependency/requested |
| Bun      | Globally installed packages            |
| npm      | Globally installed packages            |
| Nix      | Profile packages (`nix profile list`)  |
| pkgx     | Packages cached under `~/.pkgx`        |
| pip      | Python packages (`pip3 list`)          |
| Cargo    | `cargo install` binaries               |
| RubyGems | Installed gems, incl. default gems     |

Managers that aren't installed are detected and greyed out — the app never
installs anything, it only reads.

## Install

1. Grab `Package-Browser-<version>.dmg` from `dist/` (or build it yourself,
   see below) and open it.
2. Drag **Package Browser** into the **Applications** folder.
3. First launch: right-click the app and choose **Open** once. The app is
   ad-hoc signed (no paid Apple developer certificate), so Gatekeeper asks
   for this one-time confirmation. Alternatively:
   `xattr -cr "/Applications/Package Browser.app"`.

## Build from source

Requirements: macOS 14+, Swift 5.9+ (Xcode or Command Line Tools).

```sh
git clone <this repo>
cd MacOS-Package-Browser
./scripts/build-app.sh        # → dist/Package Browser.app
./scripts/make-dmg.sh         # → dist/Package-Browser-<version>.dmg
```

Useful extras:

```sh
./scripts/make-icon.sh                       # regenerate Resources/AppIcon.icns
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```

(The `DEVELOPER_DIR` prefix is needed because plain Command Line Tools don't
ship XCTest.)

## How it works

- On launch the app sources your login shell's `PATH` (zsh `-il`, so
  `.zprofile` and `.zshrc` are read — where brew/nvm/bun setup usually
  lives) and adds well-known fallbacks like `/opt/homebrew/bin`. That's how
  it finds the same tools your terminal sees, even when launched from Finder.
- Each manager has a scanner that shells out to its native listing command
  (`brew info --json=v2 --installed`, `npm ls -g --json`, …) or reads its
  on-disk state (`~/.pkgx`) and normalizes the output into one package model.
- Scans run concurrently; per-source results, counts and errors update live.
  Rescan everything with ⌘R, a single source with ⇧⌘R or right-click.

## Project layout

```
Sources/PackageBrowserCore/    # scanning library (pure Foundation, unit-tested)
  Models.swift                 # InstalledPackage, PackageSourceID
  Shell.swift                  # subprocess runner + login-shell PATH
  PackageScanner.swift         # scanner protocol + registry
  Scanners/                    # one file per package manager
Sources/PackageBrowser/        # SwiftUI app (store + views)
Tests/PackageBrowserCoreTests/ # fixture-based parser tests + live smoke tests
scripts/                       # build-app, make-dmg, make-icon, render-icon
```

## Notes & limitations

- Scanning is read-only; install/uninstall actions are out of scope.
- pkgx has no `list` command, so its scan reflects the `~/.pkgx` cache
  (everything pkgx has ever fetched), not a curated install list.
- Homebrew descriptions require one `brew info` call (~0.5s); other managers
  scan in well under a second.
