import AnkiBackend
import AnkiProto
public import Dependencies
import DependenciesMacros
public import Foundation

@DependencyClient
public struct ImportExportService: Sendable {
    public var importAnkiPackage: @Sendable (_ path: String) throws -> String
    public var exportCollectionPackage: @Sendable (_ outPath: String, _ includeMedia: Bool) throws -> Void
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
