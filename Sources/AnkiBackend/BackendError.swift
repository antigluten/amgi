import AnkiProto
public import Foundation
import SwiftProtobuf

public struct BackendError: Error, LocalizedError, CustomStringConvertible, Sendable {
    /// Mirror of `Anki_Backend_BackendError.Kind` — keeps AnkiProto out
    /// of consumer modules' import graph. New backend cases land here
    /// as well; unknown wire values surface as `.unrecognized(Int)`.
    public enum Kind: Sendable, Equatable {
        case invalidInput
        case undoEmpty
        case interrupted
        case templateParse
        case ioError
        case dbError
        case networkError
        case syncAuthError
        case syncServerMessage
        case syncOtherError
        case jsonError
        case protoError
        case notFoundError
        case exists
        case filteredDeckError
        case searchError
        case customStudyError
        case importError
        case deleted
        case cardTypeError
        case ankidroidPanicError
        case osError
        case schedulerUpgradeRequired
        case invalidCertificateFormat
        case unrecognized(Int)
    }

    public let kind: Kind
    public let message: String

    public init(kind: Kind, message: String) {
        self.kind = kind
        self.message = message
    }

    public init(errorBytes: Data) {
        if let parsed = try? Anki_Backend_BackendError(serializedBytes: errorBytes) {
            self.kind = Kind(parsed.kind)
            self.message = parsed.message
        } else {
            self.kind = .ioError
            self.message = "Unknown backend error"
        }
    }

    public var isSyncAuthError: Bool { kind == .syncAuthError }

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
        case .unrecognized(let n): return "kind=\(n)"
        }
    }
}

// MARK: - Proto → mirror

extension BackendError.Kind {
    init(_ proto: Anki_Backend_BackendError.Kind) {
        switch proto {
        case .invalidInput:             self = .invalidInput
        case .undoEmpty:                self = .undoEmpty
        case .interrupted:              self = .interrupted
        case .templateParse:            self = .templateParse
        case .ioError:                  self = .ioError
        case .dbError:                  self = .dbError
        case .networkError:             self = .networkError
        case .syncAuthError:            self = .syncAuthError
        case .syncServerMessage:        self = .syncServerMessage
        case .syncOtherError:           self = .syncOtherError
        case .jsonError:                self = .jsonError
        case .protoError:               self = .protoError
        case .notFoundError:            self = .notFoundError
        case .exists:                   self = .exists
        case .filteredDeckError:        self = .filteredDeckError
        case .searchError:              self = .searchError
        case .customStudyError:         self = .customStudyError
        case .importError:              self = .importError
        case .deleted:                  self = .deleted
        case .cardTypeError:            self = .cardTypeError
        case .ankidroidPanicError:      self = .ankidroidPanicError
        case .osError:                  self = .osError
        case .schedulerUpgradeRequired: self = .schedulerUpgradeRequired
        case .invalidCertificateFormat: self = .invalidCertificateFormat
        case .UNRECOGNIZED(let v):      self = .unrecognized(v)
        }
    }
}
