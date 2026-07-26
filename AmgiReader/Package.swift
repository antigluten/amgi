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

// Lean tier (Cxx-interop target): race checks only, no body timers.
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

// Lean tier for the C-/Cxx-interop target. Drops StrictMemorySafety (the
// interop boundary is unsafe by nature and would flood warnings). Keeps
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
    name: "AmgiReader",
    // iOS 18 / macOS 15 because AmgiReaderDictionary pulls in hoshidicts,
    // which itself requires macOS 15. The base AmgiReader target is
    // pure-Swift and would happily run on lower minimums, but SPM
    // platform requirements are per-package, not per-target.
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "AmgiReader", targets: ["AmgiReader"]),
        .library(name: "AmgiReaderDictionary", targets: ["AmgiReaderDictionary"]),
        .library(name: "AmgiReaderEPUB", targets: ["AmgiReaderEPUB"]),
    ],
    dependencies: [
        // Vendored MIT-licensed EPUB parser. Path-relative so the package
        // resolves without network access. Kept off the base AmgiReader
        // target — only AmgiReaderEPUB depends on it, which keeps the
        // pure-Swift module zip/XML-free.
        .package(path: "../Libraries/EPUBKit"),
        // hoshidicts: Yomitan-compatible offline dictionary engine.
        // Pin matches DreamAfar's verified revision so we get the same
        // ABI / generated bindings. C++ interop ships in this dependency,
        // so its consumer (AmgiReaderDictionary below) needs Cxx mode.
        .package(
            url: "https://github.com/Manhhao/hoshidicts.git",
            revision: "e70589d33b6b346663278383b422e41f1ed05f3c"
        ),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.0.0"),
    ],
    targets: [
        // Pure-Swift domain types for the Reader/Dictionary feature.
        // Deliberately has no Anki dependency: a "book" / "chapter" /
        // "dictionary lookup entry" exists independently of how we happen
        // to source them today (Anki notes). Anki-bridged loaders live in
        // the AnkiBridge package and import this one for the types.
        .target(
            name: "AmgiReader",
            dependencies: [
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "DependenciesMacros", package: "swift-dependencies"),
            ],
            swiftSettings: sharedSwiftSettings
        ),
        // Cxx-mode wrapper around hoshidicts. Isolated from the type
        // module so importing AmgiReader (the common case) stays
        // Cxx-free. App code that wants dictionary lookup imports
        // AmgiReaderDictionary explicitly.
        .target(
            name: "AmgiReaderDictionary",
            dependencies: [
                "AmgiReader",
                .product(name: "CHoshiDicts", package: "hoshidicts"),
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "DependenciesMacros", package: "swift-dependencies"),
            ],
            swiftSettings: interopSwiftSettings + [
                .interoperabilityMode(.Cxx),
            ]
        ),
        // EPUB-source adapter. Sits between AmgiReader's pure domain
        // types and the vendored EPUBKit parser. No EPUBKit types ever
        // appear in AmgiReaderEPUB's public API — callers see only
        // ReaderBook / ReaderChapter values and the ParsedEPUBBook
        // wrapper defined locally here.
        .target(
            name: "AmgiReaderEPUB",
            dependencies: [
                "AmgiReader",
                .product(name: "EPUBKit", package: "EPUBKit"),
            ],
            swiftSettings: sharedSwiftSettings
        ),
    ],
    swiftLanguageModes: [.v6]
)
