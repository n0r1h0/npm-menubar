# CLAUDE.md

Guidance for Claude Code when working in this repository.

## Build & Version Workflow

This app cannot be verified by the user without a built `.app` bundle — always rebuild after
editing any file under `Sources/`.

- **While a feature/fix is unreleased:** do not bump `releaseVersion` in
  `Sources/NpmMenuBar/AppVersion.swift` or the version strings in `Scripts/build-app.sh`.
  Verify using `Scripts/build-dev-app.sh`, which produces a debug build at `NpmMenuBar-Dev.app`.
  Debug builds automatically show `<releaseVersion>-devXXXX` (random suffix) in the menu's version
  line, making it visually obvious the build is unreleased.
- **Only when actually cutting a release:** bump `releaseVersion` in `AppVersion.swift` and the
  matching `CFBundleVersion`/`CFBundleShortVersionString` in `Scripts/build-app.sh` together, then
  build with `Scripts/build-app.sh` to produce the release `NpmMenuBar.app`.
