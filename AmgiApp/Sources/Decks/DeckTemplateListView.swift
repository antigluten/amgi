import SwiftUI
import AmgiTheme
import AnkiClients
import AnkiServices
import AnkiKit
import AnkiProto
import Dependencies

struct DeckTemplateListView: View {
    @Dependency(\.notetypesClient) var notetypesClient
    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette

    @State private var entries: [Anki_Notetypes_NotetypeNameId] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var searchText = ""
    @State private var editorTarget: TemplateEditorTarget?
    @State private var renameTarget: Anki_Notetypes_NotetypeNameId?
    @State private var renameText = ""
    @State private var showRenamePrompt = false
    @State private var deleteTarget: Anki_Notetypes_NotetypeNameId?
    @State private var showDeleteConfirm = false
    @State private var actionError: String?
    @State private var showActionError = false

    private var filteredEntries: [Anki_Notetypes_NotetypeNameId] {
        filterDeckTemplateEntries(entries, searchText: searchText)
    }

    var body: some View {
        mainContent
            .background(palette.background)
            .navigationTitle("Card Templates")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search notetypes")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .amgiToolbarTextButton()
                }
            }
            .sheet(item: $editorTarget) { target in
                TemplateEditorView(
                    notetypeId: target.id,
                    initialTemplateIndex: target.initialTemplateIndex,
                    mode: .manager,
                    onSaved: { await loadTemplates() }
                )
            }
            .alert("Rename notetype", isPresented: $showRenamePrompt) {
                TextField("New name", text: $renameText)
                Button("Cancel", role: .cancel) {}
                Button("Save") {
                    Task { await renameNotetype() }
                }
            } message: {
                Text(renameTarget?.name ?? "")
            }
            .alert("Delete notetype", isPresented: $showDeleteConfirm) {
                Button("Delete", role: .destructive) {
                    Task { await deleteNotetype() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                if let name = deleteTarget?.name {
                    Text("Delete \"\(name)\"? Cards using this notetype will be removed too.")
                }
            }
            .alert("Error", isPresented: $showActionError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(actionError ?? "An unknown error occurred.")
            }
            .task {
                await loadTemplates()
            }
    }

    // MARK: - Extracted Sub-views

    @ViewBuilder
    private var mainContent: some View {
        if isLoading {
            ProgressView()
        } else if let errorMessage {
            AmgiStatusMessageView(
                title: "Could not load templates",
                message: errorMessage,
                systemImage: "exclamationmark.triangle",
                tone: .warning
            )
        } else if entries.isEmpty {
            ContentUnavailableView(
                "No notetypes",
                systemImage: "square.stack.3d.up.slash",
                description: Text("No notetypes match this search.")
            )
        } else if filteredEntries.isEmpty {
            ContentUnavailableView.search(text: searchText)
        } else {
            templateList
        }
    }

    private var templateList: some View {
        List(filteredEntries, id: \.id) { entry in
            Button {
                editorTarget = TemplateEditorTarget(id: entry.id, initialTemplateIndex: 0)
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "square.stack.3d.up")
                        .foregroundStyle(palette.accent)
                    VStack(alignment: .leading, spacing: AmgiSpacing.xxs) {
                        Text(entry.name)
                            .amgiFont(.body)
                            .foregroundStyle(palette.textPrimary)
                        Text("ID: \(entry.id)")
                            .amgiFont(.caption)
                            .foregroundStyle(palette.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(AmgiFont.caption.font)
                        .foregroundStyle(palette.textTertiary)
                }
            }
            .buttonStyle(.plain)
            .padding(.vertical, 2)
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button(role: .destructive) {
                    deleteTarget = entry
                    showDeleteConfirm = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }

                Button {
                    renameTarget = entry
                    renameText = entry.name
                    showRenamePrompt = true
                } label: {
                    Label("Rename", systemImage: "pencil")
                }
                .tint(palette.accent)
            }
        }
        .scrollContentBackground(.hidden)
        .background(palette.background)
        .listStyle(.plain)
    }

    private func loadTemplates() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let allEntries = try notetypesClient.listAll()
            entries = sortDeckTemplateEntries(allEntries)
            errorMessage = nil
        } catch {
            entries = []
            errorMessage = error.localizedDescription
        }
    }

    private func renameNotetype() async {
        guard let renameTarget else { return }

        let newName = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !newName.isEmpty, newName != renameTarget.name else { return }

        do {
            var notetype: Anki_Notetypes_Notetype = try notetypesClient.getRaw(renameTarget.id)
            notetype.name = newName
            try notetypesClient.update(notetype)
            await loadTemplates()
        } catch {
            actionError = "Rename failed: \(error.localizedDescription)"
            showActionError = true
        }
    }

    private func deleteNotetype() async {
        guard let deleteTarget else { return }

        do {
            try notetypesClient.remove(deleteTarget.id)
            await loadTemplates()
        } catch {
            actionError = "Delete failed: \(error.localizedDescription)"
            showActionError = true
        }
    }
}

// MARK: - Supporting types

private struct TemplateEditorTarget: Identifiable {
    let id: Int64
    let initialTemplateIndex: Int
}

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

private enum TemplateEditorTab: CaseIterable {
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

// MARK: - Template Editor View

struct TemplateEditorView: View {
    @Dependency(\.notetypesClient) var notetypesClient
    @Dependency(\.noteClient) var noteClient
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.palette) private var palette

    let notetypeId: Int64
    let previewNoteId: Int64?
    let initialTemplateIndex: Int
    let mode: TemplateEditorMode
    var onSaved: (@Sendable () async -> Void)? = nil

    @AppStorage("codeEditor_fontSize") private var codeEditorFontSize: Double = 14.0

    @State private var notetype: Anki_Notetypes_Notetype = .init()
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var originalNotetype: Anki_Notetypes_Notetype?
    @State private var showDiscardChangesConfirmation = false
    @State private var showSaveError = false
    @State private var selectedTemplateIndex = 0
    @State private var editorTab: TemplateEditorTab = .front
    @State private var showFieldManager = false
    @State private var showPreviewSheet = false
    @State private var editorSearchText = ""

    init(
        notetypeId: Int64,
        previewNoteId: Int64? = nil,
        initialTemplateIndex: Int,
        mode: TemplateEditorMode,
        onSaved: (@Sendable () async -> Void)? = nil
    ) {
        self.notetypeId = notetypeId
        self.previewNoteId = previewNoteId
        self.initialTemplateIndex = initialTemplateIndex
        self.mode = mode
        self.onSaved = onSaved
    }

    private var hasUnsavedChanges: Bool {
        guard let originalNotetype else { return false }
        return originalNotetype != notetype
    }

    private var currentTemplateValidationMessage: String? {
        templateValidationMessage(for: notetype)
    }

    private var canSaveTemplate: Bool {
        notetype.templates.indices.contains(selectedTemplateIndex)
            && currentTemplateValidationMessage == nil
            && !isSaving
    }

    private var separatorBorderColor: Color {
        colorScheme == .light
            ? palette.border.opacity(0.8)
            : palette.border.opacity(0.5)
    }

    private var currentTemplateName: String {
        guard notetype.templates.indices.contains(selectedTemplateIndex) else {
            return "No template selected."
        }
        return notetype.templates[selectedTemplateIndex].name
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                } else if let errorMessage {
                    AmgiStatusMessageView(
                        title: "Could not load templates",
                        message: errorMessage,
                        systemImage: "exclamationmark.triangle",
                        tone: .warning
                    )
                } else {
                    editorContent
                }
            }
            .background(palette.background)
            .navigationTitle(mode.title)
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(hasUnsavedChanges)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { attemptDismiss() }
                        .amgiToolbarTextButton(tone: .neutral)
                }
                ToolbarItem(placement: .principal) {
                    Text(mode.title)
                        .amgiFont(.bodyEmphasis)
                        .foregroundStyle(palette.textPrimary)
                        .lineLimit(1)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fields") {
                        showFieldManager = true
                    }
                    .amgiToolbarTextButton(tone: .neutral)
                    .disabled(isLoading)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Save") {
                            Task { await saveTemplate() }
                        }
                        .amgiToolbarTextButton()
                        .disabled(!canSaveTemplate)
                    }
                }
            }
            .alert("Save failed", isPresented: $showSaveError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "An unknown error occurred.")
            }
            .confirmationDialog(
                "Unsaved changes",
                isPresented: $showDiscardChangesConfirmation,
                titleVisibility: .visible
            ) {
                Button("Discard", role: .destructive) {
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("You have unsaved changes. Discard them?")
            }
            .sheet(isPresented: $showFieldManager) {
                NavigationStack {
                    NotetypeFieldManagerView(
                        notetypeId: notetypeId,
                        preferredName: notetype.name,
                        onSaved: {
                            await loadNotetype()
                            if let onSaved {
                                await onSaved()
                            }
                        }
                    )
                }
            }
            .sheet(isPresented: $showPreviewSheet) {
                previewSheet
            }
            .task {
                await loadNotetype()
            }
        }
    }

    private var editorContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 14) {
                    if mode.allowsTemplateSelection, notetype.templates.count > 1 {
                        HStack(spacing: 12) {
                            Text(currentTemplateName)
                                .amgiFont(.bodyEmphasis)
                                .foregroundStyle(palette.textSecondary)

                            Spacer()

                            Menu {
                                ForEach(Array(notetype.templates.enumerated()), id: \.offset) { index, template in
                                    Button {
                                        selectedTemplateIndex = index
                                    } label: {
                                        if selectedTemplateIndex == index {
                                            Label(template.name, systemImage: "checkmark")
                                        } else {
                                            Text(template.name)
                                        }
                                    }
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(AmgiFont.caption.font)
                                        .foregroundStyle(palette.textSecondary)
                                }
                                .amgiCapsuleControl(horizontalPadding: 12, verticalPadding: 8)
                            }
                        }
                    } else {
                        Text(currentTemplateName)
                            .amgiFont(.bodyEmphasis)
                            .foregroundStyle(palette.textSecondary)
                    }

                    Picker("Template Editor", selection: $editorTab) {
                        ForEach(TemplateEditorTab.allCases, id: \.self) { tab in
                            Text(tab.label).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .controlSize(.small)
                    .onChange(of: editorTab) { old, new in
                        if new == .preview {
                            showPreviewSheet = true
                            editorTab = old
                        }
                    }
                }
                .padding(16)
                .background(palette.surfaceElevated, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(separatorBorderColor, lineWidth: 1)
                }

                if let currentTemplateValidationMessage {
                    AmgiStatusMessageView(
                        title: "Template issue",
                        message: currentTemplateValidationMessage,
                        systemImage: "exclamationmark.triangle",
                        tone: .warning
                    )
                }

                TemplateSourceEditor(
                    text: currentEditorBinding,
                    fieldNames: currentFieldNames,
                    insertableTokens: currentInsertableTokens,
                    fieldButtonTitle: "Fields",
                    doneButtonTitle: "Done",
                    searchQuery: editorSearchText,
                    fontSize: codeEditorFontSize
                )
                .padding(16)
                .frame(minHeight: 420)
                .background(palette.surfaceElevated, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .stroke(separatorBorderColor, lineWidth: 1)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Insert field")
                        .amgiFont(.captionBold)
                        .foregroundStyle(palette.textSecondary)

                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(palette.textSecondary)
                        TextField("Search fields", text: $editorSearchText)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(palette.surfaceElevated, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(separatorBorderColor, lineWidth: 1)
                    }
                }
            }
            .padding(20)
        }
        .background(palette.background)
    }

    private var previewSheet: some View {
        TemplatePreviewSheet(
            title: "Rendered preview",
            emptyMessage: "This card has no content to preview.",
            notetype: notetype,
            initialTemplateIndex: selectedTemplateIndex,
            loadPreviewNote: {
                let noteClient = self.noteClient
                let notetypeId = self.notetypeId
                let previewNoteId = self.previewNoteId
                let notetype = self.notetype
                return try await Task.detached(priority: .userInitiated) {
                    if let previewNoteId,
                       let currentNote = try noteClient.fetch(previewNoteId) {
                        return buildCardPreviewNote(from: currentNote)
                    }
                    if let sampleNote = try noteClient.search("mid:\(notetypeId)", 1).first {
                        return buildCardPreviewNote(from: sampleNote)
                    }
                    return makeEmptyCardPreviewNote(
                        notetypeId: notetypeId,
                        fieldCount: notetype.fields.count
                    )
                }.value
            }
        )
    }

    private var currentFieldNames: [String] {
        editorTab == .css ? [] : notetype.fields.map(\.name)
    }

    private var currentInsertableTokens: [String] {
        switch editorTab {
        case .front, .back, .preview:
            return ["(", ")", ".", "=", "#", "<br>", "{{FrontSide}}"]
        case .css:
            return ["{", "}", ":", ";", ".", "#"]
        }
    }

    private var currentEditorBinding: Binding<String> {
        switch editorTab {
        case .front:
            return qFormatBinding
        case .back:
            return aFormatBinding
        case .css:
            return cssBinding
        case .preview:
            return qFormatBinding
        }
    }

    private var qFormatBinding: Binding<String> {
        Binding(
            get: {
                guard notetype.templates.indices.contains(selectedTemplateIndex) else { return "" }
                return notetype.templates[selectedTemplateIndex].config.qFormat
            },
            set: { newValue in
                guard notetype.templates.indices.contains(selectedTemplateIndex) else { return }
                var config = notetype.templates[selectedTemplateIndex].config
                config.qFormat = newValue
                notetype.templates[selectedTemplateIndex].config = config
            }
        )
    }

    private var aFormatBinding: Binding<String> {
        Binding(
            get: {
                guard notetype.templates.indices.contains(selectedTemplateIndex) else { return "" }
                return notetype.templates[selectedTemplateIndex].config.aFormat
            },
            set: { newValue in
                guard notetype.templates.indices.contains(selectedTemplateIndex) else { return }
                var config = notetype.templates[selectedTemplateIndex].config
                config.aFormat = newValue
                notetype.templates[selectedTemplateIndex].config = config
            }
        )
    }

    private var cssBinding: Binding<String> {
        Binding(
            get: { notetype.config.css },
            set: { newValue in
                var config = notetype.config
                config.css = newValue
                notetype.config = config
            }
        )
    }

    @MainActor
    private func loadNotetype() async {
        isLoading = true
        defer { isLoading = false }

        do {
            notetype = try notetypesClient.getRaw(notetypeId)
            originalNotetype = notetype
            normalizeTemplateIndex(preferred: initialTemplateIndex)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func attemptDismiss() {
        if hasUnsavedChanges {
            showDiscardChangesConfirmation = true
        } else {
            dismiss()
        }
    }

    @MainActor
    private func saveTemplate() async {
        isSaving = true
        defer { isSaving = false }

        do {
            try notetypesClient.update(notetype)
            if let onSaved {
                await onSaved()
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showSaveError = true
        }
    }

    private func normalizeTemplateIndex(preferred: Int? = nil) {
        guard !notetype.templates.isEmpty else {
            selectedTemplateIndex = 0
            return
        }
        if let preferred, notetype.templates.indices.contains(preferred) {
            selectedTemplateIndex = preferred
            return
        }
        if !notetype.templates.indices.contains(selectedTemplateIndex) {
            selectedTemplateIndex = 0
        }
    }
}

// MARK: - Sort / filter helpers

func sortDeckTemplateEntries(
    _ entries: [Anki_Notetypes_NotetypeNameId]
) -> [Anki_Notetypes_NotetypeNameId] {
    entries.sorted(by: { $0.name.localizedStandardCompare($1.name) == .orderedAscending })
}

func filterDeckTemplateEntries(
    _ entries: [Anki_Notetypes_NotetypeNameId],
    searchText: String
) -> [Anki_Notetypes_NotetypeNameId] {
    let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return entries }
    return entries.filter { $0.name.localizedCaseInsensitiveContains(trimmed) }
}

// MARK: - Template validation

private enum TemplateValidationIssue {
    case noFrontField(templateName: String)
    case noSuchField(templateName: String, fieldName: String)
    case missingCloze
}

private struct TemplateReference {
    let fieldName: String
    let filters: [String]
}

private let templateReferenceRegex = try! NSRegularExpression(pattern: #"\{\{([^{}]+)\}\}"#)
private let specialTemplateFieldNames: Set<String> = [
    "FrontSide",
    "Card",
    "CardFlag",
    "Deck",
    "Subdeck",
    "Tags",
    "Type",
    "CardID",
]

private func templateValidationMessage(for notetype: Anki_Notetypes_Notetype) -> String? {
    switch templateValidationIssue(for: notetype) {
    case .noFrontField:
        return "The front template must reference at least one field."
    case .noSuchField(_, let fieldName):
        return "Field \"\(fieldName)\" doesn't exist on this notetype."
    case .missingCloze:
        return "This template needs a {{cloze:...}} field."
    case .none:
        return nil
    }
}

private func templateValidationIssue(for notetype: Anki_Notetypes_Notetype) -> TemplateValidationIssue? {
    let availableFieldNames = Set(notetype.fields.map(\.name))

    for template in notetype.templates {
        let frontReferences = extractTemplateReferences(from: template.config.qFormat)
        let backReferences = extractTemplateReferences(from: template.config.aFormat)

        if frontReferences.isEmpty {
            return .noFrontField(templateName: template.name)
        }

        if let unknownField = (frontReferences + backReferences)
            .map(\.fieldName)
            .first(where: { fieldName in
                !fieldName.isEmpty
                    && !specialTemplateFieldNames.contains(fieldName)
                    && !availableFieldNames.contains(fieldName)
            }) {
            return .noSuchField(templateName: template.name, fieldName: unknownField)
        }
    }

    if notetype.config.kind == .cloze {
        guard let firstTemplate = notetype.templates.first else {
            return .missingCloze
        }

        let frontHasCloze = extractTemplateReferences(from: firstTemplate.config.qFormat)
            .contains(where: containsClozeFilter)
        let backHasCloze = extractTemplateReferences(from: firstTemplate.config.aFormat)
            .contains(where: containsClozeFilter)

        if !frontHasCloze || !backHasCloze {
            return .missingCloze
        }
    }

    return nil
}

private func extractTemplateReferences(from source: String) -> [TemplateReference] {
    let range = NSRange(source.startIndex..., in: source)
    return templateReferenceRegex.matches(in: source, range: range).compactMap { match in
        guard match.numberOfRanges > 1,
              let contentRange = Range(match.range(at: 1), in: source) else {
            return nil
        }

        var content = source[contentRange].trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else {
            return TemplateReference(fieldName: "", filters: [])
        }

        if let first = content.first, ["#", "^", "/"].contains(first) {
            content.removeFirst()
            content = content.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let components = content
            .split(separator: ":", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

        guard let fieldName = components.last else {
            return nil
        }

        return TemplateReference(
            fieldName: fieldName,
            filters: Array(components.dropLast())
        )
    }
}

private func containsClozeFilter(_ reference: TemplateReference) -> Bool {
    reference.filters.contains { $0.caseInsensitiveCompare("cloze") == .orderedSame }
}

// MARK: - Card preview helpers

func buildCardPreviewNote(from note: NoteRecord) -> Anki_Notes_Note {
    var preview = Anki_Notes_Note()
    preview.id = note.id
    preview.guid = note.guid
    preview.notetypeID = note.mid
    preview.mtimeSecs = UInt32(clamping: note.mod)
    preview.usn = note.usn
    preview.tags = note.tags
        .split(whereSeparator: { $0.isWhitespace })
        .map(String.init)
    preview.fields = note.flds
        .split(separator: "\u{1f}", omittingEmptySubsequences: false)
        .map(String.init)
    return preview
}

func makeEmptyCardPreviewNote(notetypeId: Int64, fieldCount: Int) -> Anki_Notes_Note {
    var preview = Anki_Notes_Note()
    preview.notetypeID = notetypeId
    preview.usn = -1
    preview.fields = Array(repeating: "", count: max(fieldCount, 0))
    return preview
}

// MARK: - NotetypeFieldManagerView (stub — full implementation in separate file)

/// Placeholder view for the notetype field manager.
/// Full implementation (add/remove/reorder fields) is a future port.
struct NotetypeFieldManagerView: View {
    let notetypeId: Int64
    let preferredName: String
    var onSaved: (@Sendable () async -> Void)? = nil

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Text("Field editor coming soon.")
                .foregroundStyle(.secondary)
            Button("Done") { dismiss() }
        }
        .navigationTitle(preferredName)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - TemplatePreviewSheet

/// Preview sheet for uncommitted (unsaved) card templates, using CardRenderingService.
private struct TemplatePreviewSheet: View {
    @Dependency(\.cardRenderingService) var cardRenderingService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette

    let title: String
    let emptyMessage: String
    let notetype: Anki_Notetypes_Notetype
    let loadPreviewNote: () async throws -> Anki_Notes_Note

    @State private var selectedTemplateIndex: Int
    @State private var previewSide: CardPreviewSide = .front
    @State private var previewNote: Anki_Notes_Note?
    @State private var renderedFrontHTML = ""
    @State private var renderedBackHTML = ""
    @State private var isLoading = false
    @State private var isEmptyCard = false
    @State private var errorMessage: String?

    init(
        title: String,
        emptyMessage: String,
        notetype: Anki_Notetypes_Notetype,
        initialTemplateIndex: Int = 0,
        loadPreviewNote: @escaping () async throws -> Anki_Notes_Note
    ) {
        self.title = title
        self.emptyMessage = emptyMessage
        self.notetype = notetype
        self.loadPreviewNote = loadPreviewNote
        let normalized = notetype.templates.indices.contains(initialTemplateIndex) ? initialTemplateIndex : 0
        _selectedTemplateIndex = State(initialValue: normalized)
    }

    private var currentTemplateName: String {
        guard notetype.templates.indices.contains(selectedTemplateIndex) else {
            return "No template selected."
        }
        return notetype.templates[selectedTemplateIndex].name
    }

    private var currentHTML: String {
        previewSide == .front ? renderedFrontHTML : renderedBackHTML
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: AmgiSpacing.sm) {
                    Text(currentTemplateName)
                        .amgiFont(.bodyEmphasis)
                        .foregroundStyle(palette.textSecondary)

                    Picker("Side", selection: $previewSide) {
                        ForEach(CardPreviewSide.allCases, id: \.self) { side in
                            Text(side.label).tag(side)
                        }
                    }
                    .pickerStyle(.segmented)
                    .controlSize(.small)
                }
                .padding()

                Group {
                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if let errorMessage {
                        VStack(spacing: AmgiSpacing.sm) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.title2)
                                .foregroundStyle(palette.warning)
                            Text(errorMessage)
                                .amgiFont(.body)
                                .foregroundStyle(palette.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding()
                    } else if isEmptyCard {
                        VStack(spacing: AmgiSpacing.sm) {
                            Image(systemName: "rectangle.slash")
                                .font(.title2)
                                .foregroundStyle(palette.textTertiary)
                            Text(emptyMessage)
                                .amgiFont(.body)
                                .foregroundStyle(palette.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding()
                    } else {
                        ScrollView {
                            Text(currentHTML)
                                .padding()
                        }
                    }
                }
            }
            .background(palette.surfaceElevated)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .amgiToolbarTextButton()
                }
            }
            .task {
                await loadAndRenderPreview()
            }
            .onChange(of: selectedTemplateIndex) {
                Task { await renderPreview() }
            }
        }
    }

    @MainActor
    private func loadAndRenderPreview() async {
        do {
            previewNote = try await loadPreviewNote()
            await renderPreview()
        } catch {
            isLoading = false
            isEmptyCard = false
            renderedFrontHTML = ""
            renderedBackHTML = ""
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func renderPreview() async {
        guard notetype.templates.indices.contains(selectedTemplateIndex) else {
            isLoading = false
            isEmptyCard = false
            errorMessage = "No template selected."
            renderedFrontHTML = ""
            renderedBackHTML = ""
            return
        }

        guard let previewNote else {
            await loadAndRenderPreview()
            return
        }

        isLoading = true
        defer { isLoading = false }

        let cardRenderingService = self.cardRenderingService
        let notetype = self.notetype
        let templateIndex = selectedTemplateIndex
        let sampleFields = previewNote.fields

        do {
            let rendered = try await Task.detached(priority: .userInitiated) {
                try cardRenderingService.renderUncommittedCard(
                    notetype,
                    templateIndex,
                    sampleFields
                )
            }.value

            renderedFrontHTML = rendered.frontHTML
            renderedBackHTML = rendered.backHTML
            isEmptyCard = rendered.frontHTML.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && rendered.backHTML.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            errorMessage = nil
        } catch {
            isEmptyCard = false
            renderedFrontHTML = ""
            renderedBackHTML = ""
            errorMessage = error.localizedDescription
        }
    }
}

private enum CardPreviewSide: CaseIterable {
    case front
    case back

    var label: String {
        switch self {
        case .front: return "Front"
        case .back: return "Back"
        }
    }
}
