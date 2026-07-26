// swift-tools-version:6.0

import PackageDescription

let package = Package(
    name: "EPUBKit",
    
    platforms: [
        .macOS(.v10_15),
        .iOS(.v16),
        .tvOS(.v16)
    ],
    
    products: [
        .library(name: "EPUBKit", targets: ["EPUBKit"]),
    ],
    
    dependencies: [
        .package(
            url: "https://github.com/tadija/AEXML",
            from: "4.7.0"
        ),
        .package(
            url: "https://github.com/ZipArchive/ZipArchive",
            from: "2.6.0"
        )
    ],
    
    targets: [
        .target(
            name: "EPUBKit",
            dependencies: ["AEXML", "ZipArchive"]
        )
    ]
)
