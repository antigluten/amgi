import ProjectDescription

let app: TargetReference = .project(path: ".", target: "AmgiApp")

let testGroups: [(project: Path, parallel: Bool, names: [String])] = [
    (".", false, ["AmgiAppUITests"]),
    (".", true, ["AmgiAppTests"]),
    ("../AmgiReader", true, ["ReaderTests", "ReaderDictionaryTests"]),
    ("..", true, ["AnkiKitTests", "AnkiProtoBridgeTests", "AmgiCardWebTests", "AnkiServicesTests", "AnkiClientsTests", "AnkiSyncTests"]),
    ("../AmgiFeatures", true, ["AppCoreTests", "StatsFeatureTests", "BrowseFeatureTests", "DecksFeatureTests", "SyncFeatureTests", "WidgetFeatureTests"]),
    ("../AmgiFeatures", false, ["AppSharedTests", "SettingsFeatureTests"]),
    ("../AmgiUI", true, ["ThemeTests", "UITests"]),
]

let testTargets: [TestableTarget] = testGroups.flatMap { group in
    group.names.map { name in
        TestableTarget.testableTarget(
            target: .project(path: group.project, target: name),
            parallelization: group.parallel ? .enabled : .disabled
        )
    }
}

// The scheme lives here, not in Project.swift: a project scheme cannot list test targets from other projects.
let workspace = Workspace(
    name: "AmgiApp",
    projects: ["."],
    schemes: [
        .scheme(
            name: "AmgiApp",
            buildAction: .buildAction(targets: [app]),
            testAction: .targets(testTargets, expandVariableFromTarget: app),
            runAction: .runAction(configuration: .debug, executable: app),
            archiveAction: .archiveAction(configuration: .release),
            profileAction: .profileAction(configuration: .release, executable: app),
            analyzeAction: .analyzeAction(configuration: .debug)
        ),
    ]
)
