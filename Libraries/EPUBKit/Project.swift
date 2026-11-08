import ProjectDescription

let project = Project(
    name: "EPUBKit",
    options: .options(automaticSchemesOptions: .disabled),
    targets: [
        .target(
            name: "EPUBKit",
            destinations: [.iPhone, .iPad, .mac, .appleWatch],
            product: .staticFramework,
            bundleId: "com.amgiapp.EPUBKit",
            deploymentTargets: .multiplatform(iOS: "17.0", macOS: "12.0", watchOS: "9.0"),
            sources: ["Sources/EPUBKit/**/*.swift"],
            dependencies: [
                .external(name: "AEXML"),
                .external(name: "ZipArchive"),
            ],
            settings: .settings(base: [
                "SWIFT_VERSION": "6.0",
                "OTHER_SWIFT_FLAGS": "$(inherited) -package-name EPUBKit",
            ])
        ),
    ],
    resourceSynthesizers: []
)
