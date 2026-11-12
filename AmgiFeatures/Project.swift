import ProjectDescription
import ProjectDescriptionHelpers

let project = AmgiModule.project(
    "AmgiFeatures",
    targets: [
        AmgiModule.target(
            "AppCore",
            package: "AmgiFeatures",
            dependencies: [
                .project(target: "AnkiKit", path: .relativeToRoot(".")),
                .external(name: "Sharing"),
            ],
            watchOS: true
        ),
        AmgiModule.target(
            "AppCoreTests",
            package: "AmgiFeatures",
            dependencies: [
                .target(name: "AppCore"),
            ],
            tests: true
        ),
        AmgiModule.target(
            "AppShared",
            package: "AmgiFeatures",
            dependencies: [
                .target(name: "AppCore"),
                .project(target: "AnkiKit", path: .relativeToRoot(".")),
                .project(target: "AnkiClients", path: .relativeToRoot(".")),
                .project(target: "AnkiServices", path: .relativeToRoot(".")),
                .project(target: "AmgiCardWeb", path: .relativeToRoot(".")),
                .project(target: "Theme", path: .relativeToRoot("AmgiUI")),
                .project(target: "UI", path: .relativeToRoot("AmgiUI")),
                .external(name: "Dependencies"),
                .external(name: "DependenciesMacros"),
            ]
        ),
        AmgiModule.target(
            "AppSharedTests",
            package: "AmgiFeatures",
            dependencies: [
                .target(name: "AppShared"),
            ],
            tests: true
        ),
        AmgiModule.target(
            "StatsCharts",
            package: "AmgiFeatures",
            dependencies: [
                .project(target: "AnkiKit", path: .relativeToRoot(".")),
                .project(target: "Theme", path: .relativeToRoot("AmgiUI")),
                .project(target: "UI", path: .relativeToRoot("AmgiUI")),
            ],
            watchOS: true
        ),
        AmgiModule.target(
            "TemplatesFeature",
            package: "AmgiFeatures",
            dependencies: [
                .target(name: "AppCore"),
                .project(target: "AnkiKit", path: .relativeToRoot(".")),
                .project(target: "AnkiClients", path: .relativeToRoot(".")),
                .project(target: "AnkiServices", path: .relativeToRoot(".")),
                .project(target: "Theme", path: .relativeToRoot("AmgiUI")),
                .project(target: "UI", path: .relativeToRoot("AmgiUI")),
                .external(name: "Dependencies"),
                .external(name: "Sharing"),
                .external(name: "SwiftUINavigation"),
                .external(name: "CasePaths"),
            ]
        ),
        AmgiModule.target(
            "StatsFeature",
            package: "AmgiFeatures",
            dependencies: [
                .target(name: "AppCore"),
                .target(name: "StatsCharts"),
                .project(target: "AnkiKit", path: .relativeToRoot(".")),
                .project(target: "AnkiClients", path: .relativeToRoot(".")),
                .project(target: "Theme", path: .relativeToRoot("AmgiUI")),
                .project(target: "UI", path: .relativeToRoot("AmgiUI")),
                .external(name: "Dependencies"),
            ]
        ),
        AmgiModule.target(
            "DecksFeatureTests",
            package: "AmgiFeatures",
            dependencies: [
                .target(name: "DecksFeature"),
                .target(name: "AppShared"),
                .project(target: "UI", path: .relativeToRoot("AmgiUI")),
                .project(target: "AnkiKit", path: .relativeToRoot(".")),
                .project(target: "AnkiClients", path: .relativeToRoot(".")),
                .external(name: "Dependencies"),
            ],
            tests: true
        ),
        AmgiModule.target(
            "StatsFeatureTests",
            package: "AmgiFeatures",
            dependencies: [
                .target(name: "StatsFeature"),
                .target(name: "StatsCharts"),
                .project(target: "Theme", path: .relativeToRoot("AmgiUI")),
                .project(target: "AnkiKit", path: .relativeToRoot(".")),
                .project(target: "AnkiClients", path: .relativeToRoot(".")),
                .external(name: "Dependencies"),
            ],
            tests: true
        ),
        AmgiModule.target(
            "BrowseFeature",
            package: "AmgiFeatures",
            dependencies: [
                .target(name: "AppShared"),
                .project(target: "AnkiKit", path: .relativeToRoot(".")),
                .project(target: "AnkiClients", path: .relativeToRoot(".")),
                .project(target: "AnkiServices", path: .relativeToRoot(".")),
                .project(target: "Theme", path: .relativeToRoot("AmgiUI")),
                .project(target: "UI", path: .relativeToRoot("AmgiUI")),
                .external(name: "Dependencies"),
                .external(name: "SwiftUINavigation"),
                .external(name: "CasePaths"),
            ]
        ),
        AmgiModule.target(
            "BrowseFeatureTests",
            package: "AmgiFeatures",
            dependencies: [
                .target(name: "BrowseFeature"),
                .project(target: "AnkiClients", path: .relativeToRoot(".")),
                .project(target: "AnkiServices", path: .relativeToRoot(".")),
            ],
            tests: true
        ),
        AmgiModule.target(
            "ReviewCore",
            package: "AmgiFeatures",
            dependencies: [
                .target(name: "AppCore"),
                .project(target: "AnkiKit", path: .relativeToRoot(".")),
                .project(target: "AnkiClients", path: .relativeToRoot(".")),
                .project(target: "AnkiServices", path: .relativeToRoot(".")),
                .project(target: "AmgiCardWeb", path: .relativeToRoot(".")),
                .external(name: "Dependencies"),
            ],
            watchOS: true
        ),
        AmgiModule.target(
            "DecksFeature",
            package: "AmgiFeatures",
            dependencies: [
                .target(name: "AppCore"),
                .target(name: "AppShared"),
                .target(name: "BrowseFeature"),
                .target(name: "ReviewFeature"),
                .project(target: "AnkiKit", path: .relativeToRoot(".")),
                .project(target: "AnkiClients", path: .relativeToRoot(".")),
                .project(target: "Theme", path: .relativeToRoot("AmgiUI")),
                .project(target: "UI", path: .relativeToRoot("AmgiUI")),
                .external(name: "Dependencies"),
                .external(name: "SwiftUINavigation"),
                .external(name: "CasePaths"),
            ]
        ),
        AmgiModule.target(
            "ReviewFeature",
            package: "AmgiFeatures",
            dependencies: [
                .target(name: "AppCore"),
                .target(name: "AppShared"),
                .target(name: "ReviewCore"),
                .target(name: "BrowseFeature"),
                .target(name: "TemplatesFeature"),
                .project(target: "Reader", path: .relativeToRoot("AmgiReader")),
                .project(target: "AnkiKit", path: .relativeToRoot(".")),
                .project(target: "AnkiClients", path: .relativeToRoot(".")),
                .project(target: "AmgiCardWeb", path: .relativeToRoot(".")),
                .project(target: "Theme", path: .relativeToRoot("AmgiUI")),
                .project(target: "UI", path: .relativeToRoot("AmgiUI")),
                .external(name: "Dependencies"),
                .external(name: "Sharing"),
                .external(name: "SwiftUINavigation"),
                .external(name: "CasePaths"),
            ]
        ),
        AmgiModule.target(
            "ReaderFeature",
            package: "AmgiFeatures",
            dependencies: [
                .target(name: "AppCore"),
                .target(name: "AppShared"),
                .target(name: "BrowseFeature"),
                .project(target: "Reader", path: .relativeToRoot("AmgiReader")),
                .project(target: "ReaderDictionary", path: .relativeToRoot("AmgiReader")),
                .project(target: "AnkiKit", path: .relativeToRoot(".")),
                .project(target: "AnkiClients", path: .relativeToRoot(".")),
                .project(target: "Theme", path: .relativeToRoot("AmgiUI")),
                .project(target: "UI", path: .relativeToRoot("AmgiUI")),
                .external(name: "Dependencies"),
                .external(name: "Sharing"),
            ],
            cxx: true
        ),
        AmgiModule.target(
            "SyncFeature",
            package: "AmgiFeatures",
            dependencies: [
                .target(name: "AppCore"),
                .target(name: "AppShared"),
                .project(target: "AnkiKit", path: .relativeToRoot(".")),
                .project(target: "AnkiClients", path: .relativeToRoot(".")),
                .project(target: "AnkiSync", path: .relativeToRoot(".")),
                .project(target: "Theme", path: .relativeToRoot("AmgiUI")),
                .project(target: "UI", path: .relativeToRoot("AmgiUI")),
                .external(name: "Dependencies"),
                .external(name: "Sharing"),
            ]
        ),
        AmgiModule.target(
            "SyncFeatureTests",
            package: "AmgiFeatures",
            dependencies: [
                .target(name: "SyncFeature"),
                .target(name: "AppCore"),
                .project(target: "AnkiKit", path: .relativeToRoot(".")),
                .project(target: "AnkiClients", path: .relativeToRoot(".")),
                .external(name: "Sharing"),
            ],
            tests: true
        ),
        AmgiModule.target(
            "WidgetFeature",
            package: "AmgiFeatures",
            dependencies: [
                .target(name: "AppCore"),
                .project(target: "Theme", path: .relativeToRoot("AmgiUI")),
            ]
        ),
        AmgiModule.target(
            "WidgetFeatureTests",
            package: "AmgiFeatures",
            dependencies: [
                .target(name: "WidgetFeature"),
                .target(name: "AppCore"),
            ],
            tests: true
        ),
        AmgiModule.target(
            "SettingsFeature",
            package: "AmgiFeatures",
            dependencies: [
                .target(name: "AppCore"),
                .target(name: "AppShared"),
                .target(name: "ReviewCore"),
                .target(name: "BrowseFeature"),
                .target(name: "ReviewFeature"),
                .target(name: "SyncFeature"),
                .target(name: "TemplatesFeature"),
                .project(target: "AnkiKit", path: .relativeToRoot(".")),
                .project(target: "AnkiBackend", path: .relativeToRoot(".")),
                .project(target: "AnkiClients", path: .relativeToRoot(".")),
                .project(target: "AnkiServices", path: .relativeToRoot(".")),
                .project(target: "AnkiSync", path: .relativeToRoot(".")),
                .project(target: "AmgiCardWeb", path: .relativeToRoot(".")),
                .project(target: "Theme", path: .relativeToRoot("AmgiUI")),
                .project(target: "UI", path: .relativeToRoot("AmgiUI")),
                .external(name: "Dependencies"),
                .external(name: "Sharing"),
                .external(name: "SwiftNavigation"),
                .external(name: "SwiftUINavigation"),
                .external(name: "CasePaths"),
            ],
            resources: [
                .glob(pattern: .relativeToManifest("Sources/SettingsFeature/Resources/**")),
            ]
        ),
        AmgiModule.target(
            "SettingsFeatureTests",
            package: "AmgiFeatures",
            dependencies: [
                .target(name: "SettingsFeature"),
                .target(name: "AppCore"),
                .target(name: "AppShared"),
                .project(target: "AnkiClients", path: .relativeToRoot(".")),
                .project(target: "AnkiKit", path: .relativeToRoot(".")),
                .project(target: "AnkiServices", path: .relativeToRoot(".")),
                .external(name: "Dependencies"),
            ],
            tests: true
        ),
        AmgiModule.target(
            "WatchFeature",
            package: "AmgiFeatures",
            dependencies: [
                .target(name: "StatsCharts"),
                .target(name: "ReviewCore"),
                .project(target: "AnkiKit", path: .relativeToRoot(".")),
                .project(target: "AnkiBackend", path: .relativeToRoot(".")),
                .project(target: "AnkiClients", path: .relativeToRoot(".")),
                .project(target: "AnkiSync", path: .relativeToRoot(".")),
                .project(target: "AmgiCardWeb", path: .relativeToRoot(".")),
                .project(target: "Theme", path: .relativeToRoot("AmgiUI")),
                .external(name: "Dependencies"),
            ],
            watchOS: true
        ),
        AmgiModule.target(
            "IntentsFeature",
            package: "AmgiFeatures",
            dependencies: [
                .target(name: "AppCore"),
                .target(name: "AppShared"),
                .project(target: "AnkiKit", path: .relativeToRoot(".")),
                .project(target: "AnkiClients", path: .relativeToRoot(".")),
                .external(name: "Dependencies"),
            ]
        ),
        AmgiModule.target(
            "RootFeature",
            package: "AmgiFeatures",
            dependencies: [
                .target(name: "AppCore"),
                .target(name: "AppShared"),
                .target(name: "DecksFeature"),
                .target(name: "ReaderFeature"),
                .target(name: "ReviewFeature"),
                .target(name: "SettingsFeature"),
                .target(name: "StatsFeature"),
                .target(name: "SyncFeature"),
                .project(target: "AnkiKit", path: .relativeToRoot(".")),
                .project(target: "AnkiBackend", path: .relativeToRoot(".")),
                .project(target: "AnkiClients", path: .relativeToRoot(".")),
                .project(target: "AnkiSync", path: .relativeToRoot(".")),
                .project(target: "Reader", path: .relativeToRoot("AmgiReader")),
                .project(target: "Theme", path: .relativeToRoot("AmgiUI")),
                .project(target: "UI", path: .relativeToRoot("AmgiUI")),
                .external(name: "Dependencies"),
                .external(name: "Sharing"),
            ],
            cxx: true
        ),
    ]
)
