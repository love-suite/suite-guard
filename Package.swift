// swift-tools-version:5.9
import PackageDescription

// The GitHub organization of the suite's repositories: the one name to change should it be renamed (the
// suite repository's scripts/rename-organization.sh does it in every repository).
let organization = "love-suite"

// Suite Guard: puts back what the suite's apps hide should they vanish: the system Dock (hidden while our
// Dock shows), Finder's desktop (hidden while Desktop shows), Spotlight's clipboard history (off while
// Clipboard runs) and lid sleep (off during Awake's closed-lid sessions). The apps hide and put back through its
// libraries, and load its agent while something is hidden.
let package = Package(
    name: "SuiteGuard",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "DockGuard", targets: ["DockGuard"]),
        .library(name: "FinderGuard", targets: ["FinderGuard"]),
        .library(name: "SpotlightGuard", targets: ["SpotlightGuard"]),
        .library(name: "ClamshellGuard", targets: ["ClamshellGuard"]),
    ],
    dependencies: [
        .package(url: "https://github.com/\(organization)/suite-core", .upToNextMinor(from: "27.1.0-dev.1")),
    ],
    targets: [
        // When to put things back, what is hidden and by whom, the agent's registration.
        .target(name: "GuardCore", linkerSettings: [.linkedFramework("ServiceManagement")]),
        // The system Dock: hiding it and putting it back (`DockManager`), `DockGuardRule`.
        .target(name: "DockGuard", dependencies: ["GuardCore"]),
        // Finder's desktop: turning it off and back on (`FinderManager`), `FinderGuardRule`.
        .target(name: "FinderGuard", dependencies: ["GuardCore"]),
        // Spotlight's clipboard history: turning it off and back on (`SpotlightHistoryManager`),
        // `SpotlightGuardRule`.
        .target(name: "SpotlightGuard", dependencies: ["GuardCore"]),
        // Lid sleep: turning it off and back on (`ClamshellSleepManager`, through IOPMrootDomain),
        // `ClamshellGuardRule`.
        .target(name: "ClamshellGuard", dependencies: ["GuardCore"], linkerSettings: [.linkedFramework("IOKit")]),
        .executableTarget(name: "SuiteGuard", dependencies: [
            "DockGuard", "FinderGuard", "SpotlightGuard", "ClamshellGuard",
            .product(name: "SuiteCore", package: "suite-core"),
        ]),
        .testTarget(name: "GuardTests", dependencies: ["GuardCore", "DockGuard", "FinderGuard", "SpotlightGuard",
                                                                 "ClamshellGuard"]),
    ]
)
