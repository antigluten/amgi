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
    name: "AmgiFeatures",
    platforms: [.iOS(.v18), .macOS(.v15), .watchOS(.v11)],
    products: [
        .library(name: "AppCore", targets: ["AppCore"]),
        .library(name: "AppShared", targets: ["AppShared"]),
        .library(name: "StatsCharts", targets: ["StatsCharts"]),
        .library(name: "TemplatesFeature", targets: ["TemplatesFeature"]),
        .library(name: "StatsFeature", targets: ["StatsFeature"]),
        .library(name: "BrowseFeature", targets: ["BrowseFeature"]),
        .library(name: "SyncFeature", targets: ["SyncFeature"]),
        .library(name: "ReaderFeature", targets: ["ReaderFeature"]),
        .library(name: "ReviewCore", targets: ["ReviewCore"]),
        .library(name: "ReviewFeature", targets: ["ReviewFeature"]),
        .library(name: "DecksFeature", targets: ["DecksFeature"]),
        .library(name: "WidgetFeature", targets: ["WidgetFeature"]),
        .library(name: "SettingsFeature", targets: ["SettingsFeature"]),
        .library(name: "WatchFeature", targets: ["WatchFeature"]),
        .library(name: "IntentsFeature", targets: ["IntentsFeature"]),
        .library(name: "RootFeature", targets: ["RootFeature"]),
    ],
    dependencies: [
        .package(path: ".."),
        .package(path: "../AmgiUI"),
        .package(path: "../AmgiReader"),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.0.0"),
        .package(url: "https://github.com/pointfreeco/swift-sharing", from: "2.0.0"),
        .package(url: "https://github.com/pointfreeco/swift-navigation", from: "2.0.0"),
        .package(url: "https://github.com/pointfreeco/swift-case-paths", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "AppCore",
            dependencies: [
                .product(name: "AnkiKit", package: "amgi"),
                .product(name: "Sharing", package: "swift-sharing"),
            ],
            swiftSettings: sharedSwiftSettings
        ),
        .testTarget(
            name: "AppCoreTests",
            dependencies: ["AppCore"],
            swiftSettings: sharedSwiftSettings
        ),
        .target(
            name: "AppShared",
            dependencies: [
                "AppCore",
                .product(name: "AnkiKit", package: "amgi"),
                .product(name: "AnkiClients", package: "amgi"),
                .product(name: "AnkiServices", package: "amgi"),
                .product(name: "Theme", package: "AmgiUI"),
                .product(name: "UI", package: "AmgiUI"),
                .product(name: "Dependencies", package: "swift-dependencies"),
            ],
            swiftSettings: sharedSwiftSettings
        ),
        .testTarget(
            name: "AppSharedTests",
            dependencies: ["AppShared"],
            swiftSettings: sharedSwiftSettings
        ),
        .target(
            name: "StatsCharts",
            dependencies: [
                .product(name: "AnkiKit", package: "amgi"),
                .product(name: "Theme", package: "AmgiUI"),
                .product(name: "UI", package: "AmgiUI"),
            ],
            swiftSettings: sharedSwiftSettings
        ),
        .target(
            name: "TemplatesFeature",
            dependencies: [
                "AppCore",
                .product(name: "AnkiKit", package: "amgi"),
                .product(name: "AnkiClients", package: "amgi"),
                .product(name: "AnkiServices", package: "amgi"),
                .product(name: "Theme", package: "AmgiUI"),
                .product(name: "UI", package: "AmgiUI"),
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "Sharing", package: "swift-sharing"),
                .product(name: "SwiftUINavigation", package: "swift-navigation"),
                .product(name: "CasePaths", package: "swift-case-paths"),
            ],
            swiftSettings: sharedSwiftSettings
        ),
        .target(
            name: "StatsFeature",
            dependencies: [
                "AppCore",
                "StatsCharts",
                .product(name: "AnkiKit", package: "amgi"),
                .product(name: "AnkiClients", package: "amgi"),
                .product(name: "Theme", package: "AmgiUI"),
                .product(name: "UI", package: "AmgiUI"),
                .product(name: "Dependencies", package: "swift-dependencies"),
            ],
            swiftSettings: sharedSwiftSettings
        ),
        .testTarget(
            name: "DecksFeatureTests",
            dependencies: [
                "DecksFeature",
                "AppShared",
                .product(name: "UI", package: "AmgiUI"),
                .product(name: "AnkiKit", package: "amgi"),
                .product(name: "AnkiClients", package: "amgi"),
                .product(name: "Dependencies", package: "swift-dependencies"),
            ],
            swiftSettings: sharedSwiftSettings
        ),
        .testTarget(
            name: "StatsFeatureTests",
            dependencies: [
                "StatsFeature",
                .product(name: "AnkiKit", package: "amgi"),
                .product(name: "AnkiClients", package: "amgi"),
                .product(name: "Dependencies", package: "swift-dependencies"),
            ],
            swiftSettings: sharedSwiftSettings
        ),
        .target(
            name: "BrowseFeature",
            dependencies: [
                "AppShared",
                .product(name: "AnkiKit", package: "amgi"),
                .product(name: "AnkiClients", package: "amgi"),
                .product(name: "AnkiServices", package: "amgi"),
                .product(name: "Theme", package: "AmgiUI"),
                .product(name: "UI", package: "AmgiUI"),
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "SwiftUINavigation", package: "swift-navigation"),
                .product(name: "CasePaths", package: "swift-case-paths"),
            ],
            swiftSettings: sharedSwiftSettings
        ),
        .testTarget(
            name: "BrowseFeatureTests",
            dependencies: [
                "BrowseFeature",
                .product(name: "AnkiClients", package: "amgi"),
                .product(name: "AnkiServices", package: "amgi"),
            ],
            swiftSettings: sharedSwiftSettings
        ),
        // The review state machine + template render-engine overrides, shared
        // by the iOS review screen and AmgiWatchApp. Exists ONLY because both
        // need it: before 2026-08-15 project.yml cherry-picked these files
        // into the watch target by path, compiling them twice into two
        // distinct types. Same role StatsCharts plays for the stats views.
        //
        // Must stay watchOS-clean — no AppShared (UIKit/WidgetKit
        // unguarded), no UI. Guard any UIKit use with #if canImport(UIKit).
        .target(
            name: "ReviewCore",
            dependencies: [
                "AppCore",
                .product(name: "AnkiKit", package: "amgi"),
                .product(name: "AnkiClients", package: "amgi"),
                .product(name: "AnkiServices", package: "amgi"),
                .product(name: "AmgiCardWeb", package: "amgi"),
                .product(name: "Dependencies", package: "swift-dependencies"),
            ],
            swiftSettings: sharedSwiftSettings
        ),
        // Deck list, deck detail, deck config + the FSRS simulator, and the
        // profile picker. Depends on ReviewFeature only to present ReviewView
        // off a deck row.
        //
        // No .interoperabilityMode(.Cxx). This target used to need it purely
        // transitively — DecksFeature -> ReviewFeature -> ReaderFeature ->
        // ReaderDictionary put the CHoshiDicts modulemap in its Clang
        // scan. That edge was inverted on 2026-08-15 (the app injects the
        // lookup popup via EnvironmentValues.lookupPopup), so the Cxx chain is
        // ReaderFeature and the app target only. Importing any Cxx-mode module
        // under this target brings the setting — and the loss of compilation
        // caching — straight back.
        .target(
            name: "DecksFeature",
            dependencies: [
                "AppCore",
                "AppShared",
                "BrowseFeature",
                "ReviewFeature",
                .product(name: "AnkiKit", package: "amgi"),
                .product(name: "AnkiClients", package: "amgi"),
                .product(name: "Theme", package: "AmgiUI"),
                .product(name: "UI", package: "AmgiUI"),
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "SwiftUINavigation", package: "swift-navigation"),
                .product(name: "CasePaths", package: "swift-case-paths"),
            ],
            swiftSettings: sharedSwiftSettings
        ),
        // The review screen: WebKit card host, flip chrome, rating bar,
        // native renderer, render-mode UI. The session state machine itself is
        // ReviewCore, which the watch also links — keep engine logic there
        // and presentation here.
        //
        // Depends on BrowseFeature/TemplatesFeature for note editing and
        // template editing off the card.
        //
        // It deliberately does NOT depend on ReaderFeature. It used to, for
        // LookupPopupView (the dictionary popup is shared with the reader),
        // and that single edge forced .interoperabilityMode(.Cxx) here and on
        // DecksFeature behind it — Cxx interop is transitive, so importing a
        // Cxx-mode module drags the CHoshiDicts modulemap into the Clang
        // dependency scan, and any target in that chain drops out of explicit
        // modules and compilation caching (rdar://122829880).
        //
        // Inverted on 2026-08-15: the app root supplies the popup through
        // EnvironmentValues.lookupPopup (AppShared), so ReviewView renders
        // it without knowing what it is. Do not re-add the import.
        .target(
            name: "ReviewFeature",
            dependencies: [
                "AppCore",
                "AppShared",
                "ReviewCore",
                "BrowseFeature",
                "TemplatesFeature",
                // Reader (not ReaderDictionary) is pure Swift — no Cxx mode —
                // and carries LookupExtraction.js, the tap-to-lookup extractor
                // the card web view injects.
                .product(name: "Reader", package: "AmgiReader"),
                .product(name: "AnkiKit", package: "amgi"),
                .product(name: "AnkiClients", package: "amgi"),
                .product(name: "AmgiCardWeb", package: "amgi"),
                .product(name: "Theme", package: "AmgiUI"),
                .product(name: "UI", package: "AmgiUI"),
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "Sharing", package: "swift-sharing"),
                .product(name: "SwiftUINavigation", package: "swift-navigation"),
                .product(name: "CasePaths", package: "swift-case-paths"),
            ],
            swiftSettings: sharedSwiftSettings
        ),
        // The EPUB reader, its dictionary lookup UI, and the study landing
        // screen. The only target that touches ReaderDictionary, which is
        // built in Cxx-interop mode for the hoshidicts bridge — hence the
        // .interoperabilityMode below. SPM passes that to the dependency
        // scanner natively, so unlike the Xcode app target this needs no
        // OTHER_SWIFT_FLAGS duplication (see AmgiApp/project.yml).
        //
        // Keeping the Cxx chain contained here is the point: any target in it
        // loses explicit modules and therefore compilation caching
        // (rdar://122829880), so it must not spread back into the app.
        .target(
            name: "ReaderFeature",
            dependencies: [
                "AppCore",
                "AppShared",
                "BrowseFeature",
                .product(name: "Reader", package: "AmgiReader"),
                .product(name: "ReaderDictionary", package: "AmgiReader"),
                .product(name: "AnkiKit", package: "amgi"),
                .product(name: "AnkiClients", package: "amgi"),
                .product(name: "Theme", package: "AmgiUI"),
                .product(name: "UI", package: "AmgiUI"),
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "Sharing", package: "swift-sharing"),
            ],
            swiftSettings: sharedSwiftSettings + [.interoperabilityMode(.Cxx)]
        ),
        .target(
            name: "SyncFeature",
            dependencies: [
                "AppCore",
                "AppShared",
                .product(name: "AnkiKit", package: "amgi"),
                .product(name: "AnkiClients", package: "amgi"),
                .product(name: "AnkiSync", package: "amgi"),
                .product(name: "Theme", package: "AmgiUI"),
                .product(name: "UI", package: "AmgiUI"),
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "Sharing", package: "swift-sharing"),
            ],
            swiftSettings: sharedSwiftSettings
        ),
        .testTarget(
            name: "SyncFeatureTests",
            dependencies: [
                "SyncFeature",
                "AppCore",
                .product(name: "AnkiKit", package: "amgi"),
                .product(name: "AnkiClients", package: "amgi"),
                .product(name: "Sharing", package: "swift-sharing"),
            ],
            swiftSettings: sharedSwiftSettings
        ),
        // The iOS widget extension's entire body: the Widget, its AppIntent
        // configuration, the timeline provider, and the three family views.
        // Only @main AmgiWidgetBundle stays behind in the AmgiWidget target.
        //
        // Same hard rule as AppCore, for a sharper reason: the widget is a
        // separate process that reads the app group via WidgetSnapshotStore.
        // It must NEVER gain AnkiClients — it has no business being able to
        // reach the Rust engine at all.
        //
        // AnkiKit is deliberately absent: no widget source imports it. The
        // AmgiWidget target used to list it, which was vestigial.
        .target(
            name: "WidgetFeature",
            dependencies: [
                "AppCore",
                .product(name: "Theme", package: "AmgiUI"),
            ],
            swiftSettings: sharedSwiftSettings
        ),
        // The settings aggregator: the Settings root plus every screen it
        // pushes to (appearance, accounts, sync, review, card rendering,
        // reader, code editor, template overrides, maintenance, empty cards,
        // media check, backups, about) and the shared row/control chrome.
        //
        // It is the app's fan-in point, so it depends on nearly every other
        // feature — that is inherent to what a settings screen is, not a
        // layering smell. Public surface is SettingsView alone.
        //
        // It is NOT in the Cxx chain, and must not re-enter it. It used to be:
        // it imported ReaderFeature for three things — ReaderFontOption and
        // ReaderThemeColor (plain data, now in AppCore/AppShared) and
        // ReaderDictionarySettingsView (one screen, now injected through
        // EnvironmentValues.dictionarySettings by the app root, exactly like
        // LookupPopupView was for ReviewFeature). Importing any Cxx-mode
        // module here brings back .interoperabilityMode(.Cxx) and the loss of
        // explicit modules and compilation caching (rdar://122829880) on the
        // app's largest fan-in target.
        //
        // One consequence of the fan-in is deliberate:
        //   - It imports AnkiBackend directly, for MaintenanceModel's
        //     closeCollection() in "Reset Everything". No other *Feature does;
        //     AnkiClients already links it, so this costs no new linkage.
        //
        // switchProfile(to:) stays in AmgiAppApp.swift (it closes/reopens the
        // collection, cancels sync, flips the keychain anchor), so
        // SettingsView takes it as onSwitchProfile — same shape as
        // DeckListView.
        .target(
            name: "SettingsFeature",
            dependencies: [
                "AppCore",
                "AppShared",
                "ReviewCore",
                "BrowseFeature",
                "ReviewFeature",
                "SyncFeature",
                "TemplatesFeature",
                .product(name: "AnkiKit", package: "amgi"),
                .product(name: "AnkiBackend", package: "amgi"),
                .product(name: "AnkiClients", package: "amgi"),
                .product(name: "AnkiServices", package: "amgi"),
                .product(name: "AnkiSync", package: "amgi"),
                .product(name: "AmgiCardWeb", package: "amgi"),
                .product(name: "Theme", package: "AmgiUI"),
                .product(name: "UI", package: "AmgiUI"),
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "Sharing", package: "swift-sharing"),
                .product(name: "SwiftNavigation", package: "swift-navigation"),
                .product(name: "SwiftUINavigation", package: "swift-navigation"),
                .product(name: "CasePaths", package: "swift-case-paths"),
            ],
            swiftSettings: sharedSwiftSettings
        ),
        // Everything the watchOS app renders: its content root, deck list,
        // deck detail, review, stats and login screens. Only @main WatchApp
        // stays in the AmgiWatchApp target, holding the backend/collection
        // bootstrap — same split as WidgetFeature.
        //
        // watchOS-only in practice, so it must stay watchOS-clean: no
        // AppShared (it imports UIKit/WidgetKit unguarded), no
        // iOS-only API. Public surface is WatchContentView + WatchLoginView.
        .target(
            name: "WatchFeature",
            dependencies: [
                "StatsCharts",
                "ReviewCore",
                .product(name: "AnkiKit", package: "amgi"),
                .product(name: "AnkiBackend", package: "amgi"),
                .product(name: "AnkiClients", package: "amgi"),
                .product(name: "AnkiSync", package: "amgi"),
                .product(name: "AmgiCardWeb", package: "amgi"),
                .product(name: "Theme", package: "AmgiUI"),
                .product(name: "Dependencies", package: "swift-dependencies"),
            ],
            swiftSettings: sharedSwiftSettings
        ),
        .target(
            name: "IntentsFeature",
            dependencies: [
                "AppCore",
                "AppShared",
                .product(name: "AnkiKit", package: "amgi"),
                .product(name: "AnkiClients", package: "amgi"),
                .product(name: "Dependencies", package: "swift-dependencies"),
            ],
            swiftSettings: sharedSwiftSettings
        ),
        // The app's composition root: view composition (RootView, MainTabView,
        // StartupErrorView) and dependency bootstrap (AmgiRoot.bootstrap,
        // openCollection, switchProfile). The AmgiApp target holds only @main —
        // same split as WidgetFeature/WatchFeature, and what lets every other
        // feature module drop from public to package.
        //
        // In the Cxx chain, via ReaderFeature: without
        // .interoperabilityMode(.Cxx) the build fails with "module
        // 'CHoshiDicts' requires feature 'cplusplus'". AmgiReader is here for
        // the \.dictionaryConfigStore dependency key and AnkiClients for
        // AnkiBackedDictionaryConfigStore, both used by the bootstrap.
        .target(
            name: "RootFeature",
            dependencies: [
                "AppCore",
                "AppShared",
                "DecksFeature",
                "ReaderFeature",
                "ReviewFeature",
                "SettingsFeature",
                "StatsFeature",
                "SyncFeature",
                .product(name: "AnkiKit", package: "amgi"),
                .product(name: "AnkiBackend", package: "amgi"),
                .product(name: "AnkiClients", package: "amgi"),
                .product(name: "AnkiSync", package: "amgi"),
                .product(name: "Reader", package: "AmgiReader"),
                .product(name: "Theme", package: "AmgiUI"),
                .product(name: "UI", package: "AmgiUI"),
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "Sharing", package: "swift-sharing"),
            ],
            swiftSettings: sharedSwiftSettings + [.interoperabilityMode(.Cxx)]
        ),
    ],
    swiftLanguageModes: [.v6]
)
