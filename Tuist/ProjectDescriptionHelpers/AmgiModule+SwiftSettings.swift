import Foundation
import ProjectDescription

extension AmgiModule {
    static func swiftSettings(package: String, cxx: Bool, unsafeBoundary: Bool) -> Settings {
        var flags = swiftLanguageFlags(package: package, unsafeBoundary: unsafeBoundary)
        var base: SettingsDictionary = ["SWIFT_VERSION": "6.0"]

        if cxx {
            flags += " -cxx-interoperability-mode=default"
            base["SWIFT_CXX_INTEROPERABILITY_MODE"] = "default"
            base["CLANG_CXX_LANGUAGE_STANDARD"] = "c++20"
            base["CLANG_CXX_LIBRARY"] = "libc++"
        }
        base["OTHER_SWIFT_FLAGS"] = .string(flags)

        return .settings(
            base: base,
            debug: debugDiagnosticSettings(swiftFlags: flags, unsafeBoundary: unsafeBoundary)
        )
    }

    private static func swiftLanguageFlags(package: String, unsafeBoundary: Bool) -> String {
        var experimentalFeatures = [
            "IsolatedAny",
            "AccessLevelOnImport",
            "StrictSendableMetatypes",
        ]
        // Interop boundaries intentionally contain unsafe operations.
        if !unsafeBoundary {
            experimentalFeatures.append("StrictMemorySafety")
        }
        let upcomingFeatures = [
            "ExistentialAny",
            "InternalImportsByDefault",
            "MemberImportVisibility",
            "FullTypedThrows",
            "InferIsolatedConformances",
            "NonisolatedNonsendingByDefault",
        ]

        // Preserve the former Swift package visibility boundary.
        var flags = "$(inherited) -package-name \(package)"
        for feature in experimentalFeatures {
            flags += " -enable-experimental-feature \(feature)"
        }
        for feature in upcomingFeatures {
            flags += " -enable-upcoming-feature \(feature)"
        }
        return flags
    }

    private static func debugDiagnosticSettings(swiftFlags: String, unsafeBoundary: Bool) -> SettingsDictionary {
        guard ProcessInfo.processInfo.environment["AMGI_DIAGNOSTICS"] != nil else {
            return [:]
        }

        var flags = [swiftFlags, "-enable-actor-data-race-checks", "-warn-implicit-overrides"]
        if !unsafeBoundary {
            flags += [
                "-Xfrontend -warn-long-function-bodies=200",
                "-Xfrontend -warn-long-expression-type-checking=200",
            ]
        }
        return ["OTHER_SWIFT_FLAGS": .string(flags.joined(separator: " "))]
    }
}
