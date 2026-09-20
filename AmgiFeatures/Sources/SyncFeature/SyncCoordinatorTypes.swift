//
//  SyncCoordinatorTypes.swift
//  SyncFeature
//
//  Created by Vladimir Gusev on 02.05.2026.
//

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
    let reason: String

    /// True when the local collection appears empty — UI may default to download.
    let localIsEmpty: Bool
}

extension SyncFullSyncRequirement {
    static let diverged = SyncFullSyncRequirement(
        reason: "Your local and server collections have diverged. Choose how to reconcile them \u{2014} Merge is the safest option.",
        localIsEmpty: false
    )

    static let serverEmpty = SyncFullSyncRequirement(
        reason: "The server's collection is empty. Merge or \u{201C}Replace server\u{201D} keeps your cards; \u{201C}Replace local\u{201D} would erase them.",
        localIsEmpty: false
    )
}
