import AnkiBackend
import AnkiProto
public import Dependencies
import DependenciesMacros
public import Foundation

@DependencyClient
public struct ImportExportService: Sendable {
    public var importAnkiPackage: @Sendable (_ path: String) throws -> String
    public var exportCollectionPackage: @Sendable (_ outPath: String, _ includeMedia: Bool) throws -> Void
    public var exportDeckPackage: @Sendable (
        _ deckId: Int64,
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
                var req = Anki_ImportExport_ImportAnkiPackageRequest()
                req.packagePath = path
                let response: Anki_ImportExport_ImportResponse = try backend.invoke(
                    service: AnkiBackend.Service.importExport,
                    method: AnkiBackend.ImportExportMethod.importAnkiPackage,
                    request: req
                )
                let log = response.log
                return "Imported: \(log.new.count) new, \(log.updated.count) updated, \(log.duplicate.count) duplicates"
            },
            exportCollectionPackage: { outPath, includeMedia in
                var req = Anki_ImportExport_ExportCollectionPackageRequest()
                req.outPath = outPath
                req.includeMedia = includeMedia
                req.legacy = false
                try backend.callVoid(
                    service: AnkiBackend.Service.importExport,
                    method: AnkiBackend.ImportExportMethod.exportCollectionPackage,
                    request: req
                )
            },
            exportDeckPackage: { deckId, outPath, withScheduling, withDeckConfigs, withMedia, legacy in
                var req = Anki_ImportExport_ExportAnkiPackageRequest()
                req.outPath = outPath
                var options = Anki_ImportExport_ExportAnkiPackageOptions()
                options.withScheduling = withScheduling
                options.withDeckConfigs = withDeckConfigs
                options.withMedia = withMedia
                options.legacy = legacy
                req.options = options
                var limit = Anki_ImportExport_ExportLimit()
                limit.deckID = deckId
                req.limit = limit
                let response: Anki_Generic_UInt32 = try backend.invoke(
                    service: AnkiBackend.Service.importExport,
                    method: AnkiBackend.ImportExportMethod.exportAnkiPackage,
                    request: req
                )
                return response.val
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
