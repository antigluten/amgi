import Foundation
public import AnkiBackend
import AnkiKit
import AnkiProto
import SwiftProtobuf

// MARK: - checkDatabase

extension Request where Response == [String] {
    /// Runs Anki's database integrity pass and returns the problems it repaired.
    public static var checkDatabase: Self {
        .empty(
            serviceId: ServiceID.collection,
            methodId: CollectionOpsMethod.checkDatabase,
            decode: { bytes in
                try Anki_Collection_CheckDatabaseResponse(serializedBytes: bytes).problems
            }
        )
    }
}

// MARK: - undo / hasUndoableAction

extension Request where Response == Void {
    /// Undoes the last user-visible operation. No-op if the undo stack
    /// is empty (the backend returns an `undoEmpty` error which the
    /// service-level code is free to swallow).
    public static var undoLastAction: Self {
        .empty(
            serviceId: ServiceID.collection,
            methodId: CollectionOpsMethod.undo,
            decode: { _ in () }
        )
    }
}

extension Request where Response == Bool {
    /// Returns true when the next call to `.undoLastAction` would have
    /// something to undo. Surfaces `!UndoStatus.undo.isEmpty`.
    public static var hasUndoableAction: Self {
        .empty(
            serviceId: ServiceID.collection,
            methodId: CollectionOpsMethod.getUndoStatus,
            decode: { bytes in
                let proto = try Anki_Collection_UndoStatus(serializedBytes: bytes)
                return !proto.undo.isEmpty
            }
        )
    }
}
