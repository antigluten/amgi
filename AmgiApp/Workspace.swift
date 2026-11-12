import ProjectDescription

let app: TargetReference = .project(path: ".", target: "AmgiApp")

func tests(_ project: Path, _ names: String..., parallel: Bool = true) -> [TestableTarget] {
    names.map { .testableTarget(target: .project(path: project, target: $0), parallelization: parallel ? .enabled : .disabled) }
}

// The scheme lives here, not in Project.swift: a project scheme cannot list test targets from other projects.
let workspace = Workspace(
    name: "AmgiApp",
    projects: ["."],
    schemes: [
        .scheme(
            name: "AmgiApp",
            buildAction: .buildAction(targets: [app]),
            testAction: .targets(
                tests(".", "AmgiAppUITests", parallel: false)
                    + tests(".", "AmgiAppTests")
                    + tests("../AmgiReader", "ReaderTests", "ReaderDictionaryTests")
                    + tests("..", "AnkiKitTests", "AnkiProtoBridgeTests", "AmgiCardWebTests", "AnkiServicesTests", "AnkiClientsTests", "AnkiSyncTests")
                    + tests("../AmgiFeatures", "AppCoreTests", "StatsFeatureTests", "BrowseFeatureTests", "DecksFeatureTests", "SyncFeatureTests", "WidgetFeatureTests")
                    + tests("../AmgiFeatures", "AppSharedTests", "SettingsFeatureTests", parallel: false)
                    + tests("../AmgiUI", "ThemeTests", "UITests"),
                expandVariableFromTarget: app
            ),
            runAction: .runAction(configuration: .debug, executable: app),
            archiveAction: .archiveAction(configuration: .release),
            profileAction: .profileAction(configuration: .release, executable: app),
            analyzeAction: .analyzeAction(configuration: .debug)
        ),
    ]
)
