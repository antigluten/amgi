import AnkiBackend
import AnkiProto
public import Dependencies
import DependenciesMacros
public import Foundation

@DependencyClient
public struct ImportExportService: Sendable {
    public var importAnkiPackage: @Sendable (_ path: String) throws -> String
    public var exportCollectionPackage: @Sendable (_ outPath: String, _ includeMedia: Bool) throws -> Void

    /// Export the entire current collection as an .apkg suitable for the merge
    /// flow (re-importable into another collection). Always includes media,
    /// scheduling, and deck configs.
    public var exportApkgForMerge: @Sendable (_ outPath: String) throws -> Void

    /// Import an .apkg into the current collection using merge-friendly
    /// options: merge_notetypes=true, with_scheduling=true, with_deck_configs=true,
    /// update_notes=IF_NEWER, update_notetypes=IF_NEWER. Returns the import log
    /// summary string.
    public var importApkgForMerge: @Sendable (_ path: String) throws -> String
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
            exportApkgForMerge: { outPath in
                var options = Anki_ImportExport_ExportAnkiPackageOptions()
                options.withScheduling = true
                options.withDeckConfigs = true
                options.withMedia = true
                options.legacy = false

                var limit = Anki_ImportExport_ExportLimit()
                limit.limit = .wholeCollection(Anki_Generic_Empty())

                var req = Anki_ImportExport_ExportAnkiPackageRequest()
                req.outPath = outPath
                req.options = options
                req.limit = limit

                _ = try backend.call(
                    service: AnkiBackend.Service.importExport,
                    method: AnkiBackend.ImportExportMethod.exportAnkiPackage,
                    request: req
                )
            },
            importApkgForMerge: { path in
                var options = Anki_ImportExport_ImportAnkiPackageOptions()
                options.mergeNotetypes = true
                options.withScheduling = true
                options.withDeckConfigs = true
                options.updateNotes = .ifNewer
                options.updateNotetypes = .ifNewer

                var req = Anki_ImportExport_ImportAnkiPackageRequest()
                req.packagePath = path
                req.options = options

                let response: Anki_ImportExport_ImportResponse = try backend.invoke(
                    service: AnkiBackend.Service.importExport,
                    method: AnkiBackend.ImportExportMethod.importAnkiPackage,
                    request: req
                )
                let log = response.log
                return "Merged: \(log.new.count) new, \(log.updated.count) updated, \(log.duplicate.count) duplicates"
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
