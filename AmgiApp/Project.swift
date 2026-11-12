import ProjectDescription
import ProjectDescriptionHelpers

// Keep these flags on both the app and its hosted tests: Swift's dependency
// scanner needs the C++ flag as well as the build setting for CHoshiDicts.
let cxxSettings: SettingsDictionary = [
    "SWIFT_CXX_INTEROPERABILITY_MODE": "default",
    "CLANG_CXX_LANGUAGE_STANDARD": "c++20",
    "CLANG_CXX_LIBRARY": "libc++",
    "OTHER_SWIFT_FLAGS": "$(inherited) -cxx-interoperability-mode=default",
]

let project = Project(
    name: "AmgiApp",
    options: .options(
        automaticSchemesOptions: .disabled,
        disableSynthesizedResourceAccessors: true
    ),
    settings: AmgiModule.settings,
    targets: [
        .target(
            name: "AmgiApp",
            destinations: .iOS,
            product: .app,
            bundleId: "com.amgiapp.AmgiApp",
            deploymentTargets: .iOS("18.0"),
            infoPlist: .file(path: "Info.plist"),
            sources: [.glob("Sources/**", excluding: ["Sources/Widgets/**", "Sources/Watch/**"])],
            resources: [
                "Resources/Assets.xcassets",
                "Resources/AppIcons/**",
                .folderReference(path: "Resources/mathjax"),
                .folderReference(path: "Resources/Review"),
                .folderReference(path: "Resources/Fonts"),
                .folderReference(path: "Resources/EPUBReader"),
            ],
            entitlements: .file(path: "AmgiApp.entitlements"),
            dependencies: [
                .project(target: "RootFeature", path: .relativeToRoot("AmgiFeatures")),
                .project(target: "IntentsFeature", path: .relativeToRoot("AmgiFeatures")),
                .sdk(name: "WidgetKit", type: .framework),
                .target(name: "AmgiWidget"),
            ],
            settings: .settings(base: cxxSettings.merging([
                "ASSETCATALOG_COMPILER_APPICON_NAME": "Dojang",
                "ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES[sdk=iphone*]": "Handwritten DeepTeal Midnight Celadon Persimmon",
            ]) { _, value in value })
        ),
        .target(
            name: "AmgiWidget",
            destinations: .iOS,
            product: .appExtension,
            bundleId: "com.amgiapp.AmgiApp.widget",
            deploymentTargets: .iOS("18.0"),
            infoPlist: .file(path: "Sources/Widgets/Info.plist"),
            sources: ["Sources/Widgets/**"],
            entitlements: .file(path: "AmgiWidget.entitlements"),
            dependencies: [
                .project(target: "WidgetFeature", path: .relativeToRoot("AmgiFeatures")),
                .sdk(name: "WidgetKit", type: .framework),
                .sdk(name: "SwiftUI", type: .framework),
            ]
        ),
        .target(
            name: "AmgiWatchApp",
            destinations: [.appleWatch],
            product: .app,
            bundleId: "com.amgiapp.AmgiApp.watch",
            deploymentTargets: .watchOS("11.0"),
            infoPlist: .extendingDefault(with: [
                "CFBundleShortVersionString": "$(MARKETING_VERSION)",
                "CFBundleVersion": "$(CURRENT_PROJECT_VERSION)",
                "WKCompanionAppBundleIdentifier": "com.amgiapp.AmgiApp",
            ]),
            sources: ["Sources/Watch/**"],
            dependencies: [
                .project(target: "AnkiKit", path: .relativeToRoot(".")),
                .project(target: "Theme", path: .relativeToRoot("AmgiUI")),
                .project(target: "UI", path: .relativeToRoot("AmgiUI")),
                .project(target: "AnkiServices", path: .relativeToRoot(".")),
                .project(target: "AnkiClients", path: .relativeToRoot(".")),
                .project(target: "AnkiSync", path: .relativeToRoot(".")),
                .project(target: "AnkiBackend", path: .relativeToRoot(".")),
                .project(target: "AmgiCardWeb", path: .relativeToRoot(".")),
                .project(target: "AppCore", path: .relativeToRoot("AmgiFeatures")),
                .project(target: "StatsCharts", path: .relativeToRoot("AmgiFeatures")),
                .project(target: "ReviewCore", path: .relativeToRoot("AmgiFeatures")),
                .project(target: "WatchFeature", path: .relativeToRoot("AmgiFeatures")),
                .external(name: "SwiftNavigation"),
                .external(name: "Sharing"),
            ],
            settings: .settings(base: [
                "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
                "SKIP_INSTALL": "YES",
            ])
        ),
        .target(
            name: "AmgiAppTests",
            destinations: .iOS,
            product: .unitTests,
            bundleId: "com.amgiapp.AmgiAppTests",
            deploymentTargets: .iOS("18.0"),
            sources: ["Tests/AmgiAppTests/**"],
            resources: ["Tests/AmgiAppTests/*.mp3", "Tests/AmgiAppTests/*.zip"],
            dependencies: [.target(name: "AmgiApp")],
            settings: .settings(base: cxxSettings)
        ),
        .target(
            name: "AmgiAppUITests",
            destinations: .iOS,
            product: .uiTests,
            bundleId: "com.amgiapp.AmgiAppUITests",
            deploymentTargets: .iOS("18.0"),
            sources: ["Tests/AmgiAppUITests/**"],
            dependencies: [.target(name: "AmgiApp")]
        ),
    ],
    schemes: [
        .scheme(
            name: "AmgiWatchApp",
            buildAction: .buildAction(targets: ["AmgiWatchApp"]),
            runAction: .runAction(configuration: .debug),
            archiveAction: .archiveAction(configuration: .release),
            profileAction: .profileAction(configuration: .release),
            analyzeAction: .analyzeAction(configuration: .debug)
        ),
    ],
    resourceSynthesizers: []
)
