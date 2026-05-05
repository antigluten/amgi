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
    name: "AnkiBridge",
    // Pinned to iOS 18 / macOS 15 because the sibling AmgiReader package
    // depends on hoshidicts, which requires macOS 15+. The app target
    // already deploys iOS 18 so this is a no-op for users.
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "AnkiKit", targets: ["AnkiKit"]),
        .library(name: "AnkiProto", targets: ["AnkiProto"]),
        .library(name: "AnkiBackend", targets: ["AnkiBackend"]),
        .library(name: "AnkiServices", targets: ["AnkiServices"]),
        .library(name: "AnkiClients", targets: ["AnkiClients"]),
        .library(name: "AnkiSync", targets: ["AnkiSync"]),
        .library(name: "AmgiCardWeb", targets: ["AmgiCardWeb"]),
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-protobuf.git", from: "1.28.0"),
        // Reader/Dictionary domain types live in a sibling package so the
        // book/chapter/lookup model isn't entangled with Anki primitives.
        // The Anki-bridged loader (ReaderBookClient) lives in AnkiClients
        // and imports this package for its types.
        .package(path: "AmgiReader"),
    ],
    targets: [
        // MARK: - Rust Bridge
        .binaryTarget(
            name: "AnkiRustLib",
            path: "AnkiRust.xcframework"
        ),
        .target(
            name: "AnkiProto",
            dependencies: [
                .product(name: "SwiftProtobuf", package: "swift-protobuf"),
            ],
            swiftSettings: sharedSwiftSettings
        ),
        .target(
            name: "AnkiBackend",
            dependencies: [
                "AnkiRustLib",
                "AnkiProto",
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "DependenciesMacros", package: "swift-dependencies"),
            ],
            swiftSettings: sharedSwiftSettings
        ),
        // MARK: - Libraries
        .target(
            name: "AnkiKit",
            swiftSettings: sharedSwiftSettings
        ),
        .target(
            name: "AnkiServices",
            dependencies: [
                "AnkiKit",
                "AnkiBackend",
                "AnkiProto",
                "AnkiSync",
                .product(name: "SwiftProtobuf", package: "swift-protobuf"),
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "DependenciesMacros", package: "swift-dependencies"),
                .product(name: "Logging", package: "swift-log"),
            ],
            swiftSettings: sharedSwiftSettings
        ),
        .target(
            name: "AnkiClients",
            dependencies: [
                "AnkiKit",
                "AnkiBackend",
                "AnkiProto",
                "AnkiServices",
                "AnkiSync",
                .product(name: "AmgiReader", package: "AmgiReader"),
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "DependenciesMacros", package: "swift-dependencies"),
                .product(name: "Logging", package: "swift-log"),
            ],
            swiftSettings: sharedSwiftSettings
        ),
        .target(
            name: "AnkiSync",
            dependencies: [
                "AnkiKit",
            ],
            swiftSettings: sharedSwiftSettings
        ),
        .target(
            name: "AmgiCardWeb",
            swiftSettings: sharedSwiftSettings
        ),
        .testTarget(
            name: "AmgiCardWebTests",
            dependencies: ["AmgiCardWeb"],
            swiftSettings: sharedSwiftSettings
        ),
    ],
    swiftLanguageModes: [.v6]
)
