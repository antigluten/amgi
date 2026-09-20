//
//  TagsDestination.swift
//  BrowseFeature
//
//  Created by Vladimir Gusev on 15.08.2026.
//

import Foundation
import CasePaths

/// Single source of truth for every modal axis on the tags screen: the
/// new-tag sheet, the delete and rename alerts, and the per-tag action
/// dialog shown in note mode.
///
/// Replaces three flag+payload pairs (`showAddTag`/`newTagName`,
/// `showDeleteConfirm`/`selectedTag`, `showRenameTag`/`tagToRename`/
/// `renameTagName`) plus a loose `tagActionTag`, which between them could
/// encode states the screen has no rendering for — a rename flag raised with
/// no tag to rename, or two alerts asking to be shown at once.
@CasePathable
enum TagsDestination {
    case addTag(String)
    case deleteTag(String)
    case renameTag(TagRename)
    case noteAction(String)
}

/// In-flight rename. `original` is the tag being renamed; `newName` is what
/// the alert's text field edits.
struct TagRename {
    let original: String
    var newName: String

    init(original: String) {
        self.original = original
        self.newName = original
    }
}
