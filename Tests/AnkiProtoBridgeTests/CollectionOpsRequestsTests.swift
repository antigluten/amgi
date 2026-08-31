import Testing
import AnkiKit
@testable import AnkiProtoBridge
@testable import AnkiBackend
import AnkiProto
import SwiftProtobuf

@Suite struct CollectionOpsRequestsTests {
    // Literals, not the catalog constants: these assert the *wire* IDs of
    // BackendCollectionService's delegated methods, which is exactly what a
    // typo in the catalog would break.
    @Test func checkDatabase_dispatches_and_decodes_problems() throws {
        var proto = Anki_Collection_CheckDatabaseResponse()
        proto.problems = ["Fixed invalid card properties", "Fixed missing deck"]

        let request: Request<[String]> = .checkDatabase
        #expect(request.serviceId == 3)
        #expect(request.methodId == 6)
        #expect(try request.body.isEmpty)
        #expect(try request.decode(proto.serializedData()) == proto.problems)
    }

    @Test func undoLastAction_dispatches_with_empty_body() throws {
        let envelope: Request<Void> = .undoLastAction
        #expect(envelope.serviceId == 3)
        #expect(envelope.methodId == 8)
        #expect(try envelope.body.isEmpty)
    }

    @Test func hasUndoableAction_dispatches_with_empty_body() throws {
        let envelope: Request<Bool> = .hasUndoableAction
        #expect(envelope.serviceId == 3)
        #expect(envelope.methodId == 7)
        #expect(try envelope.body.isEmpty)
    }

    @Test func hasUndoableAction_returns_true_when_undo_label_present() throws {
        var resp = Anki_Collection_UndoStatus()
        resp.undo = "Answer Card"
        let bytes = try resp.serializedData()
        let envelope: Request<Bool> = .hasUndoableAction
        #expect(try envelope.decode(bytes) == true)
    }

    @Test func hasUndoableAction_returns_false_when_undo_label_empty() throws {
        var resp = Anki_Collection_UndoStatus()
        resp.undo = ""
        let bytes = try resp.serializedData()
        let envelope: Request<Bool> = .hasUndoableAction
        #expect(try envelope.decode(bytes) == false)
    }
}
