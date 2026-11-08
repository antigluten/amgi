import ProjectDescription

public enum AmgiModule {
    public static let libraryDestinations = Destinations.iOS.union(Destinations.macOS)

    public static func target(
        _ name: String,
        package: String,
        dependencies: [TargetDependency] = [],
        resources: ResourceFileElements? = nil,
        tests: Bool = false,
        watchOS: Bool = false,
        cxx: Bool = false,
        unsafeBoundary: Bool = false
    ) -> Target {
        let sourceDirectory = tests ? "Tests" : "Sources"
        let sourcePath = "\(sourceDirectory)/\(name)/**/*.swift"

        return .target(
            name: name,
            destinations: watchOS ? libraryDestinations.union(Destinations.watchOS) : libraryDestinations,
            product: tests ? .unitTests : .staticFramework,
            bundleId: "com.amgiapp.\(name)",
            deploymentTargets: .multiplatform(iOS: "18.0", macOS: "15.0", watchOS: watchOS ? "11.0" : nil),
            sources: [.glob(.relativeToManifest(sourcePath))],
            resources: resources,
            dependencies: dependencies,
            settings: swiftSettings(package: package, cxx: cxx, unsafeBoundary: unsafeBoundary)
        )
    }
}
