//
//  ImageOcclusionDestination.swift
//  BrowseFeature
//
//  Created by Vladimir Gusev on 15.08.2026.
//

import SwiftUI
import CasePaths

/// Single source of truth for every modal axis on the image-occlusion
/// workspace: the text editor, the custom-fill editor, and the discard
/// confirmation. Replaces the parallel `showTextEditor` / `showFillEditor` /
/// `showDiscardConfirmation` flags and the five loose `pendingText*` vars
/// that used to encode which editor was open and what it was editing.
@CasePathable
enum ImageOcclusionDestination {
    case textEditor(IOTextDraft)
    case fillEditor(IOFillDraft)
    case discardConfirmation
}

/// In-flight text mask edit. `target` doubles as the sheet's identity so
/// typing into the draft mutates the presented sheet instead of re-presenting it.
struct IOTextDraft: Identifiable {
    enum Target: Hashable {
        case insert(at: CGPoint)
        case edit(maskIndex: Int)
    }

    let target: Target
    var text: String
    var color: Color

    var id: Target { target }

    var isSubmittable: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

/// In-flight custom fill colour. Only one can ever be open, so the identity
/// is a constant.
struct IOFillDraft: Identifiable {
    let id = "fill"
    var color: Color
}
