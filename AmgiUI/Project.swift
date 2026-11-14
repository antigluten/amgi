import ProjectDescription
import ProjectDescriptionHelpers

let project = AmgiModule.project(
    "AmgiUI",
    targets: [
        AmgiModule.target(
            "Theme",
            package: "AmgiUI",
            resources: [
                .glob(pattern: .relativeToManifest("Sources/Theme/Resources/**")),
            ],
            watchOS: true
        ),
        AmgiModule.target(
            "ThemeTests",
            package: "AmgiUI",
            dependencies: [
                .target(name: "Theme"),
            ],
            tests: true
        ),
        AmgiModule.target(
            "UI",
            package: "AmgiUI",
            dependencies: [
                .target(name: "Theme"),
            ],
            resources: [
                .glob(pattern: .relativeToManifest("Sources/UI/Resources/Localizable.xcstrings")),
            ],
            watchOS: true
        ),
        AmgiModule.target(
            "UITests",
            package: "AmgiUI",
            dependencies: [
                .target(name: "UI"),
            ],
            tests: true
        ),
    ]
)
