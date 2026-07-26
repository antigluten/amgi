import AnkiBackend
import AnkiProtoBridge
public import AnkiKit
public import Dependencies
import DependenciesMacros

@DependencyClient
public struct ImportExportService: Sendable {
    public var importAnkiPackage: @Sendable (_ path: String) throws -> String
    public var exportCollectionPackage: @Sendable (_ outPath: String, _ includeMedia: Bool) throws -> Void
    public var exportDeckPackage: @Sendable (
        _ deckId: DeckID,
        _ outPath: String,
        _ withScheduling: Bool,
        _ withDeckConfigs: Bool,
        _ withMedia: Bool,
        _ legacy: Bool
    ) throws -> UInt32
}

extension ImportExportService: DependencyKey {
    public static let liveValue: Self = {
        @Dependency(\.ankiBackend) var backend
        return Self(
            importAnkiPackage: { path in
                let log = try backend.invoke(.importAnkiPackage(path: path))
                return "Imported: \(log.newCount) new, \(log.updatedCount) updated, \(log.duplicateCount) duplicates"
            },
            exportCollectionPackage: { outPath, includeMedia in
                try backend.invoke(.exportCollectionPackage(outPath: outPath, includeMedia: includeMedia))
            },
            exportDeckPackage: { deckId, outPath, withScheduling, withDeckConfigs, withMedia, legacy in
                try backend.invoke(.exportAnkiPackage(
                    deckId: deckId,
                    outPath: outPath,
                    withScheduling: withScheduling,
                    withDeckConfigs: withDeckConfigs,
                    withMedia: withMedia,
                    legacy: legacy
                ))
            }
        )
    }()
}

extension ImportExportService: TestDependencyKey {
    public static let testValue = ImportExportService()
}

extension DependencyValues {
    public var importExportService: ImportExportService {
        get { self[ImportExportService.self] }
        set { self[ImportExportService.self] = newValue }
    }
}
