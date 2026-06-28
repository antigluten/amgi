import Foundation

struct SyncLogEntry: Identifiable, Sendable, Equatable {
    let id: UUID
    let timestamp: Date
    let message: String
    let level: Level

    enum Level: String, Sendable {
        case info
        case warning
        case error
    }

    init(id: UUID = UUID(), timestamp: Date = .now, message: String, level: Level = .info) {
        self.id = id
        self.timestamp = timestamp
        self.message = message
        self.level = level
    }
}

struct SyncFullSyncRequirement: Sendable, Equatable {
    /// Brief explanation of why a full sync is required (e.g. "Schema mismatch", "Local collection empty").
    let reason: String

    /// True when the local collection appears empty — UI may default to download.
    let localIsEmpty: Bool
}
