// swift-tools-version: 6.2

import PackageDescription

let sharedSwiftSettings: [SwiftSetting] = [
    .enableExperimentalFeature("StrictConcurrency"),
    .enableExperimentalFeature("IsolatedAny"),
    .enableUpcomingFeature("ExistentialAny"),
    .enableUpcomingFeature("InternalImportsByDefault"),
    .enableUpcomingFeature("MemberImportVisibility"),
    .enableUpcomingFeature("FullTypedThrows"),
]

let package = Package(
    name: "AmgiUI",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "AmgiTheme", targets: ["AmgiTheme"]),
    ],
    targets: [
        .target(
            name: "AmgiTheme",
            swiftSettings: sharedSwiftSettings
        ),
        .testTarget(
            name: "AmgiThemeTests",
            dependencies: ["AmgiTheme"],
            swiftSettings: sharedSwiftSettings
        ),
    ],
    swiftLanguageModes: [.v6]
)
