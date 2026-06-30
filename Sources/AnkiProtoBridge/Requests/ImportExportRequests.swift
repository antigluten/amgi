import Foundation
public import AnkiBackend
public import AnkiKit
import AnkiProto
import SwiftProtobuf

// MARK: - importAnkiPackage

extension Request where Response == ImportLogSummary {
    /// Imports an .apkg at `path` and returns a summary of how many
    /// notes were created, updated, and skipped as duplicates.
    public static func importAnkiPackage(path: String) -> Self {
        Self(
            serviceId: ServiceID.importExport,
            methodId: ImportExportMethod.importAnkiPackage,
            encode: {
                var proto = Anki_ImportExport_ImportAnkiPackageRequest()
                proto.packagePath = path
                return try proto.serializedData()
            },
            decode: { bytes in
                let resp = try Anki_ImportExport_ImportResponse(serializedBytes: bytes)
                return ImportLogSummary(
                    newCount: resp.log.new.count,
                    updatedCount: resp.log.updated.count,
                    duplicateCount: resp.log.duplicate.count
                )
            }
        )
    }
}

// MARK: - importAnkiPackageForMerge

extension Request where Response == ImportLogSummary {
    /// Imports an .apkg using merge-friendly options: notetypes are merged
    /// and notes/notetypes update when the incoming copy is newer. Used by
    /// the sync merge flow to fold a local backup into a freshly-downloaded
    /// server collection.
    public static func importAnkiPackageForMerge(path: String) -> Self {
        Self(
            serviceId: ServiceID.importExport,
            methodId: ImportExportMethod.importAnkiPackage,
            encode: {
                var proto = Anki_ImportExport_ImportAnkiPackageRequest()
                proto.packagePath = path

                var options = Anki_ImportExport_ImportAnkiPackageOptions()
                options.mergeNotetypes = true
                options.withScheduling = true
                options.withDeckConfigs = true
                options.updateNotes = .ifNewer
                options.updateNotetypes = .ifNewer
                proto.options = options

                return try proto.serializedData()
            },
            decode: { bytes in
                let resp = try Anki_ImportExport_ImportResponse(serializedBytes: bytes)
                return ImportLogSummary(
                    newCount: resp.log.new.count,
                    updatedCount: resp.log.updated.count,
                    duplicateCount: resp.log.duplicate.count
                )
            }
        )
    }
}

// MARK: - exportAnkiPackageForMerge (whole collection)

extension Request where Response == Void {
    /// Exports the entire collection as an .apkg suitable for the sync merge
    /// flow (re-importable into another collection). Always includes media,
    /// scheduling, and deck configs.
    public static func exportAnkiPackageForMerge(outPath: String) -> Self {
        Self(
            serviceId: ServiceID.importExport,
            methodId: ImportExportMethod.exportAnkiPackage,
            encode: {
                var proto = Anki_ImportExport_ExportAnkiPackageRequest()
                proto.outPath = outPath

                var options = Anki_ImportExport_ExportAnkiPackageOptions()
                options.withScheduling = true
                options.withDeckConfigs = true
                options.withMedia = true
                options.legacy = false
                proto.options = options

                var limit = Anki_ImportExport_ExportLimit()
                limit.limit = .wholeCollection(Anki_Generic_Empty())
                proto.limit = limit

                return try proto.serializedData()
            },
            decode: { _ in () }
        )
    }
}

// MARK: - exportCollectionPackage

extension Request where Response == Void {
    /// Writes a full collection .colpkg to `outPath`. `includeMedia`
    /// controls whether media files are bundled.
    public static func exportCollectionPackage(outPath: String, includeMedia: Bool) -> Self {
        Self(
            serviceId: ServiceID.importExport,
            methodId: ImportExportMethod.exportCollectionPackage,
            encode: {
                var proto = Anki_ImportExport_ExportCollectionPackageRequest()
                proto.outPath = outPath
                proto.includeMedia = includeMedia
                proto.legacy = false
                return try proto.serializedData()
            },
            decode: { _ in () }
        )
    }
}

// MARK: - exportAnkiPackage (single deck)

extension Request where Response == UInt32 {
    /// Exports a single deck to an .apkg at `outPath`. Returns the
    /// number of notes exported. `legacy: true` produces an old-format
    /// package compatible with Anki <2.1.50.
    public static func exportAnkiPackage(
        deckId: DeckID,
        outPath: String,
        withScheduling: Bool,
        withDeckConfigs: Bool,
        withMedia: Bool,
        legacy: Bool
    ) -> Self {
        Self(
            serviceId: ServiceID.importExport,
            methodId: ImportExportMethod.exportAnkiPackage,
            encode: {
                var proto = Anki_ImportExport_ExportAnkiPackageRequest()
                proto.outPath = outPath

                var options = Anki_ImportExport_ExportAnkiPackageOptions()
                options.withScheduling = withScheduling
                options.withDeckConfigs = withDeckConfigs
                options.withMedia = withMedia
                options.legacy = legacy
                proto.options = options

                var limit = Anki_ImportExport_ExportLimit()
                limit.deckID = deckId.rawValue
                proto.limit = limit

                return try proto.serializedData()
            },
            decode: { bytes in
                let resp = try Anki_Generic_UInt32(serializedBytes: bytes)
                return resp.val
            }
        )
    }
}
