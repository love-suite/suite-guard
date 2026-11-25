# Suite Guard: project brief

Suite Guard (`local.suite.guard`, an agent with no window) puts back what the suite's apps hide
should they vanish (a crash, a forced quit, not started at login): the system Dock, which Bar hides
while it shows, Finder's desktop, which Desktop hides while it shows its own, and Spotlight's clipboard
history (macOS 26, `com.apple.Spotlight`'s `PasteboardHistoryEnabled`), which Clipboard turns off while it
runs, and lid sleep, which Awake turns off during a closed-lid session (a Mac must never be left awake in a
bag). It was Dock Guard, inside Explorer.app, until 2026-11-22.

## Architecture

```
GuardCore      (library, no UI, unit-tested; exported by the three below)
    GuardRule (when to put back: hidden, and the app that hid it gone 15 seconds, 90 after login),
    RunningProcesses, GuardedApps (what is hidden, by which app, where it notes it), GuardAgent (the
    launch agent, loaded while something is hidden), PreferenceDomain, AppPreferenceDomain
DockGuard      (library) DockManager: hiding the system Dock through `com.apple.dock`'s public
               settings and putting the old values back; DockGuardRule
FinderGuard    (library) FinderManager: Finder's `CreateDesktop`, putting the desktop back; FinderGuardRule
SpotlightGuard (library) SpotlightHistoryManager: Spotlight's `PasteboardHistoryEnabled`, turning it off
               and back to what the user had; SpotlightGuardRule
ClamshellGuard (library) ClamshellSleepManager: lid sleep, turned off and back on through
               `IOPMrootDomain`'s user client, selector `kPMSetClamshellSleepState` (12, public header
               IOPMLibDefs.h, undocumented behaviour, no root; it outlives the process that set it);
               `RootDomainClamshellSwitch` (the real switch, `ClamshellSleepSwitch` for fakes); ClamshellGuardRule
SuiteGuard     (Suite Guard.app) the agent: every 5 seconds, applies the four rules, and updates itself
               quietly (`SuiteUpdater`, `suite-core`): launchd starts the new copy
```

The apps that hide something depend on its libraries: Desktop (repository `suite-desktop`) on
`FinderGuard`, Bar.app (repository `suite-bar`) on `DockGuard`, Clipboard (repository `suite-clipboard`) on
`SpotlightGuard`, Awake (repository `suite-awake`) on `ClamshellGuard`; Explorer reads `FinderGuard` too (`GuardedApps`, `RunningProcesses`, to keep Finder
quit). `GuardedApps` names which app hid what and where it keeps the setting from before: Bar's defaults
`DockSettingsBeforeHiding`, Desktop's `FinderDesktopBeforeHiding`, Clipboard's `SpotlightHistoryBefore`
("on", "off" or "none"), Awake's `ClamshellSleepDisabledByAwake` (true while lid sleep is off). Each calls `GuardAgent.update()`
after hiding or showing; the launch agent (`~/Library/LaunchAgents/local.suite.guard.plist`,
loaded with `launchctl`) runs Suite Guard.app's executable by its path, found through Launch Services.
Without Suite Guard.app installed nothing guards: the apps say so in their log.

Never touch the real Dock or lid sleep in tests (`DockManager` takes a `PreferenceDomain`,
`ClamshellSleepManager` a `ClamshellSleepSwitch`), and restart it as
rarely as possible: each Dock restart leaves Spaces, ⌘Tab and Mission Control unusable for a minute or two.

## Building and running

- `swift build` and `swift test` for development.
- `scripts/make-app.sh` builds `build/Suite Guard.app` (release), signs it with the "Suite Local Signing"
  certificate from the login keychain, so macOS permissions survive rebuilds (ad-hoc signing, the
  fallback, re-asks every build), and installs it as `~/Applications/Suite Guard.app`, the only copy Launch
  Services knows. It records the branch and commit in the Info.plist (`SuiteBuildBranch`,
  `SuiteBuildCommit`) and refuses to replace an installed copy built from another branch, or from an unknown
  one, unless `--force`: another session may be testing it. `INSTALL_DIR=` builds without installing. A
  running copy is relaunched from the new one.
- Never ask the user to open `build/Suite Guard.app` from a worktree.
- UI can't be checked by unit tests and screenshots of the user's screen are not available: check UI by
  rendering views offscreen (`cacheDisplay`) from a scratch package that compiles the sources.
- Releases: change `VERSION` (only `Z` is this repository's own), commit, push, then `scripts/publish.sh`
  pushes the tag; `.github/workflows/release.yml` builds, signs the app with "Suite Release Signing",
  signs `update.json` with the update key (both from the repository's `release` environment secrets),
  publishes the release and updates the cask in `love-suite/homebrew-tap`. The feed is
  `https://github.com/love-suite/suite-guard/releases/latest/download/update.json`
  (the GitHub repository it is built from). A change of `AA.Y` comes from the suite repository through
  `.github/workflows/sync-version.yml`. Until `Support/release-certificate.cer` and
  `Support/update-public-key.txt` exist, nothing can be released.

## The suite

This repository is part of Love Suite, one repository per app under `github.com/love-suite`:
`suite-core` (the shared library), `suite-files` (the file layer of the apps handling files),
`suite-guard`, `suite-desktop` (the desktop), `suite-explorer`, `suite-bar` (the Dock), `suite-viewer`,
`suite-clipboard`, `suite-settings` (the settings), `suite-awake` (keeping the Mac awake), `suite-launcher`, `suite-bindings`,
`suite-ai-organizer`; `homebrew-tap` (the tap `love-suite/tap`, one cask per app) and `suite` (the
front page, the suite's version, the scripts that act on every repository). Locally they sit side by side
in `~/GitHub/paul-amour/suite/`.

## Conventions (the same in every repository of the suite)

- The user writes in French and expects answers in French; everything in the code stays in English: code,
  comments, tests, docs, commit messages. Do not add co-author trailers.
- No "…" in menu items, buttons or messages: the user wants none, anywhere.
- Behaviour follows Windows unless Apple's design is asked for.
- Swift Package Manager, `swift-tools-version:5.9`, macOS 13+. Tests use Swift Testing (`import Testing`).
- Toolchain: swiftly, Swift 6.4.2 (`.swift-version`, git-ignored). If `swift test` complains about a
  missing toolchain: `swiftly use 6.4.2`.
- AppKit for windows that need fine control; SwiftUI is allowed for small panels (settings, pickers).
- No private APIs and no system modifications (SIP stays on).
- Git: one worktree per feature under `.worktrees/` (git-ignored), one branch per change
  (`feat/<feature>`, `fix/<area>/<what>`), merged into `main` one by one; `main` stays stable.
- Versions are `AA.Y`, then `AA.Y.Z` for a fix (`VERSION`, tag `vVERSION`: 27.1, then 27.1.1; SwiftPM reads
  `v27.1` as 27.1.0): `AA` is the latest macOS in production (27), `AA.Y` is the same in every repository of
  the suite so the apps work together, `Z` is this repository's own. A change of `AA.Y` is made in `suite`
  and reaches every repository. While a version is being prepared, `VERSION` doesn't move (27.1 now):
  development builds are `VERSION-dev.N`, N the commits since `VERSION` was set, merges aside, from 1 (`make-app.sh`),
  and a change another repository needs gets a development tag, `vVERSION-dev.N`, which releases nothing.
  Dependencies on other repositories of the suite (`suite-core`, `suite-files`, `suite-guard`, settings
  libraries) use
  `.upToNextMinor(from: "27.1.0-dev.1")` (the latest development tag, then the release);
  `Package.resolved` is committed. Tags are never moved once pushed. The build number (`CFBundleVersion`,
  which the updater compares) stays the number of commits.
- Changing two repositories at once: `swift package edit <Package> --path ../<repository>` points at the
  neighbour's working copy until its tag exists, `swift package unedit` goes back. Never committed.
- What two apps need lives in `suite-core` (file code in `suite-files`); an app's own code never goes into another app's repository, and
  an app exposes only its settings, as `<App>Settings`, for Suite Settings.
- Do not run commands that delete user data. Trash instead of delete.
- No code converting saved settings at launch. Before the first release nothing needs converting (the
  developer's own settings don't count): rename freely. Between released versions, a change to saved
  settings is a `SettingsMigration` (suite-core) for the version that brought it, given to the app's
  `SuiteUpdater`, which runs it once after the update.
