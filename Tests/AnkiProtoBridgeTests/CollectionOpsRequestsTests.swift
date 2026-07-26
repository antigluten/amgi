import Testing
import AnkiKit
@testable import AnkiProtoBridge
@testable import AnkiBackend
import AnkiProto
import SwiftProtobuf

@Suite struct CollectionOpsRequestsTests {
    @Test func undoLastAction_dispatches_with_empty_body() throws {
        let envelope: Request<Void> = .undoLastAction
        #expect(envelope.serviceId == ServiceID.collectionOps)
        #expect(envelope.methodId == CollectionOpsMethod.undo)
        #expect(try envelope.body.isEmpty)
    }

    @Test func hasUndoableAction_dispatches_with_empty_body() throws {
        let envelope: Request<Bool> = .hasUndoableAction
        #expect(envelope.serviceId == ServiceID.collectionOps)
        #expect(envelope.methodId == CollectionOpsMethod.getUndoStatus)
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
