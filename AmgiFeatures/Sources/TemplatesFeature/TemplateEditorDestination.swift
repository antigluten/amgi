//
//  TemplateEditorDestination.swift
//  TemplatesFeature
//
//  Created by Vladimir Gusev on 18.08.2026.
//

import Foundation
import CasePaths

/// Single source of truth for every modal axis on the template editor: the
/// save-failure alert, the discard-changes dialog, the field manager, and the
/// render preview.
///
/// Replaces four independent flags (`showSaveError`,
/// `showDiscardChangesConfirmation`, `showFieldManager`, `showPreviewSheet`),
/// which between them could encode states the screen has no rendering for —
/// the preview sheet and the field manager asking to show at once, or a
/// discard prompt raised behind either.
@CasePathable
enum TemplateEditorDestination {
    case saveError
    case discardChanges
    case fieldManager
    case preview
}
