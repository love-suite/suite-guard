# Suite Guard

Puts the system Dock, Finder's desktop and Spotlight's clipboard history back, and turns lid sleep back on,
should the app of Love Suite that changed them vanish (a crash, a forced quit, not started at login), so the Mac is never left without them.
An agent with no window, started only while something is hidden. Installed with Explorer, Desktop and Bar.

Development: `swift build`, `swift test`, `scripts/make-app.sh` (Swift 6.4.2, macOS 13 or later).
