//
//  DeckDetailDestination.swift
//  DecksFeature
//
//  Created by Vladimir Gusev on 14.05.2026.
//

import Foundation
import CasePaths

/// Single source of truth for every modal axis on the deck-detail screen:
/// full-screen review, sheets, and alerts. (There was a fourth, `importer`,
/// until import was consolidated into the Library toolbar on 2026-09-18.)
@CasePathable
enum DeckDetailDestination {
    case review
    case alert(DeckDetailAlert)
    case sheet(DeckDetailSheet)
}

@CasePathable
enum DeckDetailSheet: Identifiable {
    case addNote
    case showDeckOptions
    case exportFile(URL)
    case createSubdeck
    case extendLimit(DeckLimitKind)

    var id: String {
        switch self {
        case .addNote: "addNote"
        case .showDeckOptions: "showDeckOptions"
        case .exportFile(let url): "exportFile-\(url.absoluteString)"
        case .createSubdeck: "createSubdeck"
        case .extendLimit(let kind): "extendLimit-\(kind.noun)"
        }
    }
}

@CasePathable
enum DeckDetailAlert {
    case empty
    case error(title: String, message: String)
}

/// Which of today's two per-deck caps a custom-study extension raises.
enum DeckLimitKind {
    case new
    case review

    var noun: String {
        switch self {
        case .new: "New"
        case .review: "Review"
        }
    }

    /// Whole sentences per kind rather than `noun` spliced into one
    /// template, so each language can word them naturally.
    var promptTitle: String {
        switch self {
        case .new: String(localized: "Increase Today's New Limit", bundle: .module)
        case .review: String(localized: "Increase Today's Review Limit", bundle: .module)
        }
    }

    var promptFooter: String {
        switch self {
        case .new: String(localized: "Extra new cards to show today, on top of this deck's daily limit. Resets tomorrow.", bundle: .module)
        case .review: String(localized: "Extra review cards to show today, on top of this deck's daily limit. Resets tomorrow.", bundle: .module)
        }
    }
}
