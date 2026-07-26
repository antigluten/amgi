import AnkiKit

/// Sheet payload identifying which notetype/template the editor should open.
struct TemplateEditorTarget: Identifiable {
    let id: NotetypeID
    let initialTemplateIndex: Int
}

/// Where the editor was launched from. Affects toolbar copy and whether the
/// user can pick a different card template inside the editor.
enum TemplateEditorMode {
    case manager
    case currentCard

    var title: String {
        "Edit template"
    }

    var allowsTemplateSelection: Bool {
        switch self {
        case .manager:
            return true
        case .currentCard:
            return false
        }
    }
}

/// Segmented-picker selection inside `TemplateEditorView`.
enum TemplateEditorTab: CaseIterable {
    case front
    case back
    case css
    case preview

    var label: String {
        switch self {
        case .front:
            return "Front template"
        case .back:
            return "Back template"
        case .css:
            return "CSS"
        case .preview:
            return "Preview"
        }
    }
}
