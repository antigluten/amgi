//
//  BrowseDestination.swift
//  BrowseFeature
//
//  Created by Vladimir Gusev on 18.08.2026.
//

import Foundation
import CasePaths
import AnkiKit

/// Single source of truth for every modal axis on the browse screen: the two
/// add-note sheets, the batch-tag sheet, and the two delete dialogs.
///
/// Replaces four independent flags (`showAddNote`, `showAddImageOcclusion`,
/// `showTagSheet`, `showDeleteConfirm`) plus a loose `pendingSwipeDelete`,
/// which between them could encode states the screen has no rendering for —
/// two sheets asking to show at once, or the swipe-delete dialog raised over
/// the batch-delete one.
enum BrowseTool: Hashable {
    case duplicates
}

@CasePathable
enum BrowseDestination {
    case addNote
    case addImageOcclusion
    case batchTag
    case deleteSelected
    case deleteNote(NoteRecord)
}
