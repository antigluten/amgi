//
//  AmgiIntentError.swift
//  IntentsFeature
//
//  Created by Vladimir Gusev on 19.09.2026.
//

import AppIntents
import Foundation

enum AmgiIntentError: Error, CustomLocalizedStringResourceConvertible {
    case noSnapshot
    case badDeckId
    case syncFailed(String)

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .noSnapshot:
            "Open Amgi once so it can publish its deck counts, then try again."
        case .badDeckId:
            "That deck is no longer available."
        case .syncFailed(let message):
            "Sync failed: \(message)"
        }
    }
}
