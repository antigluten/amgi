import ProjectDescription

extension AmgiModule {
    public static let settings: Settings = .settings(
        base: [
            "SWIFT_VERSION": "6.0",
            "MARKETING_VERSION": "0.2.0",
            "CURRENT_PROJECT_VERSION": "7",
            "SWIFT_STRICT_CONCURRENCY": "complete",
            // Keep async function mangling consistent between the app and local modules.
            "OTHER_SWIFT_FLAGS": "$(inherited) -enable-upcoming-feature NonisolatedNonsendingByDefault",
            "ENABLE_USER_SCRIPT_SANDBOXING": "YES",
            "ENABLE_ENHANCED_SECURITY": "YES",
            // The Rust XCFramework has no arm64e slice, including on watchOS.
            "ENABLE_POINTER_AUTHENTICATION": "NO",
            "LOCALIZED_STRING_SWIFTUI_SUPPORT": "YES",
            "STRING_CATALOG_GENERATE_SYMBOLS": "YES",
            // Keep CAS caching on; the libcxxshim warning is cosmetic (agents/known-issues.md).
            "COMPILATION_CACHE_ENABLE_CACHING": "YES",
        ],
        debug: ["EAGER_LINKING": "YES"],
        release: [
            "GCC_OPTIMIZATION_LEVEL": "s",
            "ONLY_ACTIVE_ARCH": "NO",
            "ENABLE_TESTABILITY": "NO",
        ]
    )

    public static func project(_ name: String, targets: [Target]) -> Project {
        Project(
            name: name,
            options: .options(
                automaticSchemesOptions: .disabled,
                disableSynthesizedResourceAccessors: true
            ),
            settings: settings,
            targets: targets,
            resourceSynthesizers: []
        )
    }
}
