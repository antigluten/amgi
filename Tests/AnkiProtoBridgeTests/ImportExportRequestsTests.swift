import Testing
import AnkiKit
@testable import AnkiProtoBridge
@testable import AnkiBackend
import AnkiProto
private import SwiftProtobuf

@Suite struct ImportExportRequestsTests {
    // MARK: - importAnkiPackage

    @Test func importAnkiPackage_dispatches_to_importExport_service() {
        let envelope: Request<ImportLogSummary> = .importAnkiPackage(path: "/tmp/x.apkg")
        #expect(envelope.serviceId == ServiceID.importExport)
        #expect(envelope.methodId == ImportExportMethod.importAnkiPackage)
    }

    @Test func importAnkiPackage_encodes_path() throws {
        let envelope: Request<ImportLogSummary> = .importAnkiPackage(path: "/tmp/deck.apkg")
        let proto = try Anki_ImportExport_ImportAnkiPackageRequest(serializedBytes: envelope.body)
        #expect(proto.packagePath == "/tmp/deck.apkg")
    }

    @Test func importAnkiPackage_decodes_log_counts() throws {
        var note = Anki_ImportExport_ImportResponse.Note()
        note.fields = ["a", "b"]
        var log = Anki_ImportExport_ImportResponse.Log()
        log.new = [note, note, note]
        log.updated = [note]
        log.duplicate = [note, note]
        var resp = Anki_ImportExport_ImportResponse()
        resp.log = log
        let bytes = try resp.serializedData()

        let envelope: Request<ImportLogSummary> = .importAnkiPackage(path: "/x")
        let result = try envelope.decode(bytes)

        #expect(result.newCount == 3)
        #expect(result.updatedCount == 1)
        #expect(result.duplicateCount == 2)
    }

    // MARK: - exportCollectionPackage

    @Test func exportCollectionPackage_dispatches_and_sets_fields() throws {
        let envelope: Request<Void> = .exportCollectionPackage(outPath: "/tmp/c.colpkg", includeMedia: true)
        #expect(envelope.serviceId == ServiceID.importExport)
        #expect(envelope.methodId == ImportExportMethod.exportCollectionPackage)
        let proto = try Anki_ImportExport_ExportCollectionPackageRequest(serializedBytes: envelope.body)
        #expect(proto.outPath == "/tmp/c.colpkg")
        #expect(proto.includeMedia)
        #expect(!proto.legacy)
    }

    // MARK: - exportAnkiPackage

    @Test func exportAnkiPackage_dispatches_to_exportAnkiPackage() {
        let envelope: Request<UInt32> = .exportAnkiPackage(
            deckId: DeckID(42), outPath: "/tmp/d.apkg",
            withScheduling: true, withDeckConfigs: false, withMedia: true, legacy: false
        )
        #expect(envelope.serviceId == ServiceID.importExport)
        #expect(envelope.methodId == ImportExportMethod.exportAnkiPackage)
    }

    @Test func exportAnkiPackage_encodes_options_and_limit() throws {
        let envelope: Request<UInt32> = .exportAnkiPackage(
            deckId: DeckID(99), outPath: "/tmp/d.apkg",
            withScheduling: true, withDeckConfigs: true, withMedia: false, legacy: true
        )
        let proto = try Anki_ImportExport_ExportAnkiPackageRequest(serializedBytes: envelope.body)
        #expect(proto.outPath == "/tmp/d.apkg")
        #expect(proto.options.withScheduling)
        #expect(proto.options.withDeckConfigs)
        #expect(!proto.options.withMedia)
        #expect(proto.options.legacy)
        #expect(proto.limit.deckID == 99)
    }

    @Test func exportAnkiPackage_decodes_count() throws {
        var resp = Anki_Generic_UInt32()
        resp.val = 1234
        let bytes = try resp.serializedData()

        let envelope: Request<UInt32> = .exportAnkiPackage(
            deckId: DeckID(1), outPath: "/x",
            withScheduling: false, withDeckConfigs: false, withMedia: false, legacy: false
        )
        #expect(try envelope.decode(bytes) == 1234)
    }
}
