import ProjectDescription
import ProjectDescriptionHelpers

let project = AmgiModule.project(
    "AnkiBridge",
    targets: [
        AmgiModule.target(
            "AnkiProto",
            package: "AnkiBridge",
            dependencies: [
                .external(name: "SwiftProtobuf"),
            ],
            watchOS: true,
            unsafeBoundary: true
        ),
        AmgiModule.target(
            "AnkiBackend",
            package: "AnkiBridge",
            dependencies: [
                .xcframework(path: .relativeToRoot("AnkiRustLib.xcframework")),
                .target(name: "AnkiProto"),
                .external(name: "Dependencies"),
                .external(name: "DependenciesMacros"),
            ],
            watchOS: true,
            unsafeBoundary: true
        ),
        AmgiModule.target(
            "AnkiProtoBridge",
            package: "AnkiBridge",
            dependencies: [
                .target(name: "AnkiKit"),
                .target(name: "AnkiBackend"),
                .target(name: "AnkiProto"),
                .external(name: "SwiftProtobuf"),
            ],
            watchOS: true
        ),
        AmgiModule.target(
            "AnkiProtoBridgeTests",
            package: "AnkiBridge",
            dependencies: [
                .target(name: "AnkiProtoBridge"),
                .target(name: "AnkiProto"),
            ],
            tests: true
        ),
        AmgiModule.target(
            "AnkiKit",
            package: "AnkiBridge",
            watchOS: true
        ),
        AmgiModule.target(
            "AnkiServices",
            package: "AnkiBridge",
            dependencies: [
                .target(name: "AnkiKit"),
                .target(name: "AnkiBackend"),
                .target(name: "AnkiProtoBridge"),
                .target(name: "AnkiSync"),
                .external(name: "SwiftProtobuf"),
                .external(name: "Dependencies"),
                .external(name: "DependenciesMacros"),
                .external(name: "Logging"),
            ],
            watchOS: true
        ),
        AmgiModule.target(
            "AnkiClients",
            package: "AnkiBridge",
            dependencies: [
                .target(name: "AnkiKit"),
                .target(name: "AnkiBackend"),
                .target(name: "AnkiServices"),
                .target(name: "AnkiSync"),
                .project(target: "Reader", path: .relativeToRoot("AmgiReader")),
                .project(target: "ReaderEPUB", path: .relativeToRoot("AmgiReader")),
                .external(name: "Dependencies"),
                .external(name: "DependenciesMacros"),
                .external(name: "Logging"),
            ],
            watchOS: true
        ),
        AmgiModule.target(
            "AnkiSync",
            package: "AnkiBridge",
            dependencies: [
                .target(name: "AnkiKit"),
            ],
            watchOS: true
        ),
        AmgiModule.target(
            "AmgiCardWeb",
            package: "AnkiBridge",
            watchOS: true
        ),
        AmgiModule.target(
            "AmgiCardWebTests",
            package: "AnkiBridge",
            dependencies: [
                .target(name: "AmgiCardWeb"),
            ],
            tests: true
        ),
        AmgiModule.target(
            "AnkiSyncTests",
            package: "AnkiBridge",
            dependencies: [
                .target(name: "AnkiSync"),
            ],
            tests: true
        ),
        AmgiModule.target(
            "AnkiKitTests",
            package: "AnkiBridge",
            dependencies: [
                .target(name: "AnkiKit"),
            ],
            tests: true
        ),
        AmgiModule.target(
            "AnkiServicesTests",
            package: "AnkiBridge",
            dependencies: [
                .target(name: "AnkiServices"),
                .target(name: "AnkiBackend"),
                .target(name: "AnkiProtoBridge"),
                .target(name: "AnkiKit"),
                .external(name: "Dependencies"),
            ],
            tests: true
        ),
        AmgiModule.target(
            "AnkiClientsTests",
            package: "AnkiBridge",
            dependencies: [
                .target(name: "AnkiClients"),
                .target(name: "AnkiKit"),
                .project(target: "Reader", path: .relativeToRoot("AmgiReader")),
            ],
            tests: true
        ),
    ]
)
