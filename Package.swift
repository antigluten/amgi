// swift-tools-version: 6.2

import PackageDescription

// Opt-in debug diagnostics, off by default. ANY use of unsafeFlags opts a
// target out of explicit-module compilation caching (commit 8fc0fa7), so these
// are gated behind an env var instead of always-on. Turn on deliberately:
//   AMGI_DIAGNOSTICS=1 xcodebuild ...   (or `swift build`)
let diagnosticsEnabled = Context.environment["AMGI_DIAGNOSTICS"] != nil

// Full tier (pure-Swift targets): actor data-race checks + type-check/body timers.
let fullDiagnosticFlags: [SwiftSetting] = diagnosticsEnabled
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

// Lean tier (generated / interop targets): race checks only, no body timers
// (generated decode loops would trip them with no actionable fix).
let leanDiagnosticFlags: [SwiftSetting] = diagnosticsEnabled
    ? [.unsafeFlags(
        ["-enable-actor-data-race-checks", "-warn-implicit-overrides"],
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
] + fullDiagnosticFlags

// Lean tier for generated / C-FFI targets (AnkiProto, AnkiBackend). Drops
// StrictMemorySafety — the C bridge traffics in raw pointers and AnkiProto is
// machine-generated, so it would only emit unfixable noise. Keeps
// NonisolatedNonsendingByDefault so async function-type mangling stays
// consistent across the package ↔ app link boundary.
let interopSwiftSettings: [SwiftSetting] = [
    .enableExperimentalFeature("IsolatedAny"),
    .enableUpcomingFeature("ExistentialAny"),
    .enableUpcomingFeature("InternalImportsByDefault"),
    .enableUpcomingFeature("MemberImportVisibility"),
    .enableUpcomingFeature("FullTypedThrows"),
    .enableUpcomingFeature("InferIsolatedConformances"),
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
    .enableExperimentalFeature("AccessLevelOnImport"),
    .enableExperimentalFeature("StrictSendableMetatypes"),
] + leanDiagnosticFlags

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
            swiftSettings: interopSwiftSettings
        ),
        .target(
            name: "AnkiBackend",
            dependencies: [
                "AnkiRustLib",
                "AnkiProto",
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "DependenciesMacros", package: "swift-dependencies"),
            ],
            swiftSettings: interopSwiftSettings
        ),
        .target(
            name: "AnkiProtoBridge",
            dependencies: [
                "AnkiKit",
                "AnkiBackend",
                "AnkiProto",
                .product(name: "SwiftProtobuf", package: "swift-protobuf"),
            ],
            swiftSettings: sharedSwiftSettings
        ),
        .testTarget(
            name: "AnkiProtoBridgeTests",
            dependencies: ["AnkiProtoBridge", "AnkiProto"],
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
                "AnkiProtoBridge",
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
                .product(name: "AmgiReaderEPUB", package: "AmgiReader"),
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
        .testTarget(
            name: "AnkiKitTests",
            dependencies: ["AnkiKit"],
            swiftSettings: sharedSwiftSettings
        ),
    ],
    swiftLanguageModes: [.v6]
)
