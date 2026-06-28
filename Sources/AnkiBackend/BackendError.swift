public import AnkiProto
public import Foundation
import SwiftProtobuf

public struct BackendError: Error, LocalizedError, CustomStringConvertible, Sendable {
    public let kind: Anki_Backend_BackendError.Kind
    public let message: String

    public init(kind: Anki_Backend_BackendError.Kind, message: String) {
        self.kind = kind
        self.message = message
    }

    public init(errorBytes: Data) {
        if let parsed = try? Anki_Backend_BackendError(serializedBytes: errorBytes) {
            self.kind = parsed.kind
            self.message = parsed.message
        } else {
            self.kind = .ioError
            self.message = "Unknown backend error"
        }
    }

    public var isSyncAuthError: Bool { kind == .syncAuthError }
    public var isNetworkError: Bool { kind == .networkError }

    /// Lets `error.localizedDescription` and SwiftUI's default error
    /// presenters surface the actual Rust-side message instead of
    /// rendering the opaque struct (e.g. "AnkiBackend.BackendError 1").
    public var errorDescription: String? {
        message.isEmpty ? "Anki backend: \(kindLabel)" : message
    }

    public var description: String {
        message.isEmpty ? "BackendError(\(kindLabel))" : "BackendError(\(kindLabel)): \(message)"
    }

    private var kindLabel: String {
        switch kind {
        case .invalidInput: return "invalid input"
        case .undoEmpty: return "undo empty"
        case .interrupted: return "interrupted"
        case .templateParse: return "template parse"
        case .ioError: return "io error"
        case .dbError: return "database error"
        case .networkError: return "network error"
        case .syncAuthError: return "sync auth"
        case .syncServerMessage: return "sync server message"
        case .syncOtherError: return "sync error"
        case .jsonError: return "json error"
        case .protoError: return "proto error"
        case .notFoundError: return "not found"
        case .exists: return "already exists"
        case .filteredDeckError: return "filtered deck"
        case .searchError: return "search error"
        case .customStudyError: return "custom study"
        case .importError: return "import error"
        case .deleted: return "deleted"
        case .cardTypeError: return "card type"
        case .ankidroidPanicError: return "ankidroid panic"
        case .osError: return "os error"
        case .schedulerUpgradeRequired: return "scheduler upgrade required"
        case .invalidCertificateFormat: return "invalid certificate"
        case .UNRECOGNIZED(let n): return "kind=\(n)"
        }
    }
}
