import ProjectDescription
import ProjectDescriptionHelpers

let project = AmgiModule.project(
    "AmgiReader",
    targets: [
        AmgiModule.target(
            "Reader",
            package: "AmgiReader",
            dependencies: [
                .external(name: "Dependencies"),
                .external(name: "DependenciesMacros"),
            ],
            resources: [
                .glob(pattern: .relativeToManifest("Sources/Reader/Resources/LookupExtraction.js")),
            ],
            watchOS: true
        ),
        AmgiModule.target(
            "ReaderTests",
            package: "AmgiReader",
            dependencies: [
                .target(name: "Reader"),
            ],
            tests: true
        ),
        AmgiModule.target(
            "ReaderDictionary",
            package: "AmgiReader",
            dependencies: [
                .target(name: "Reader"),
                .external(name: "CHoshiDicts"),
                .external(name: "Dependencies"),
                .external(name: "DependenciesMacros"),
            ],
            cxx: true,
            unsafeBoundary: true
        ),
        AmgiModule.target(
            "ReaderDictionaryTests",
            package: "AmgiReader",
            dependencies: [
                .target(name: "ReaderDictionary"),
                .target(name: "Reader"),
            ],
            resources: [
                .folderReference(path: .relativeToManifest("Tests/ReaderDictionaryTests/Fixtures")),
            ],
            tests: true,
            cxx: true,
            unsafeBoundary: true
        ),
        AmgiModule.target(
            "ReaderEPUB",
            package: "AmgiReader",
            dependencies: [
                .target(name: "Reader"),
                .project(target: "EPUBKit", path: .relativeToRoot("Libraries/EPUBKit")),
            ],
            watchOS: true
        ),
    ]
)
