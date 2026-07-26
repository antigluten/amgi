// swift-tools-version: 6.2

import PackageDescription

// Opt-in debug diagnostics, off by default. ANY use of unsafeFlags opts a
// target out of explicit-module compilation caching (commit 8fc0fa7), so these
// are gated behind an env var instead of always-on. Turn on deliberately:
//   AMGI_DIAGNOSTICS=1 xcodebuild ...   (or `swift build`)
let diagnosticFlags: [SwiftSetting] = Context.environment["AMGI_DIAGNOSTICS"] != nil
    ? [.unsafeFlags(
        [
            "-enable-actor-data-race-checks",
            "-warn-implicit-overrides",
            "-Xfrontend", "-warn-long-function-bodies=200",
            "-Xfrontend", "-warn-long-expression-type-checking=200",
        ],
        .when(configuration: .debug)
    )]
    : []

// StrictConcurrency dropped: it's the implicit default under .v6 language mode.
let sharedSwiftSettings: [SwiftSetting] = [
    .enableExperimentalFeature("IsolatedAny"),
    .enableUpcomingFeature("ExistentialAny"),
    .enableUpcomingFeature("InternalImportsByDefault"),
    .enableUpcomingFeature("MemberImportVisibility"),
    .enableUpcomingFeature("FullTypedThrows"),
    .enableUpcomingFeature("InferIsolatedConformances"),
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
    .enableExperimentalFeature("AccessLevelOnImport"),
    .enableExperimentalFeature("StrictMemorySafety"),
    .enableExperimentalFeature("StrictSendableMetatypes"),
] + diagnosticFlags

let package = Package(
    name: "AmgiUI",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "AmgiTheme", targets: ["AmgiTheme"]),
        .library(name: "AmgiUI", targets: ["AmgiUI"]),
    ],
    targets: [
        .target(
            name: "AmgiTheme",
            resources: [.process("Resources")],
            swiftSettings: sharedSwiftSettings
        ),
        .testTarget(
            name: "AmgiThemeTests",
            dependencies: ["AmgiTheme"],
            swiftSettings: sharedSwiftSettings
        ),
        .target(
            name: "AmgiUI",
            dependencies: ["AmgiTheme"],
            swiftSettings: sharedSwiftSettings
        ),
        .testTarget(
            name: "AmgiUITests",
            dependencies: ["AmgiUI"],
            swiftSettings: sharedSwiftSettings
        ),
    ],
    swiftLanguageModes: [.v6]
)
