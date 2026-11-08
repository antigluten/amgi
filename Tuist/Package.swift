// swift-tools-version: 6.2
import PackageDescription

// Local modules have their own Project.swift; only remote dependencies live here.
let package = Package(
    name: "AmgiDependencies",
    dependencies: [
        .package(url: "https://github.com/tadija/AEXML", from: "4.7.0"),
        .package(url: "https://github.com/ZipArchive/ZipArchive", from: "2.6.0"),
        .package(url: "https://github.com/Manhhao/hoshidicts.git", revision: "e70589d33b6b346663278383b422e41f1ed05f3c"),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.0.0"),
        .package(url: "https://github.com/pointfreeco/swift-navigation", from: "2.0.0"),
        .package(url: "https://github.com/pointfreeco/swift-sharing", from: "2.0.0"),
        .package(url: "https://github.com/pointfreeco/swift-case-paths", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-protobuf.git", from: "1.28.0"),
    ]
)
