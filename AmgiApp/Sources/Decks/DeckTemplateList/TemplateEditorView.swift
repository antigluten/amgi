import SwiftUI
import AmgiTheme
import AnkiKit

/// Notetype/template editor — front, back, and CSS panes plus a render
/// preview. Container owns the editable `Notetype`; the cosmetic subviews
/// (`TemplateEditorHeaderCard`, `InsertFieldSearchBox`) and presentation
/// modifier (`TemplateEditorPresentations`) live below.
struct TemplateEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.palette) private var palette

    let notetypeId: NotetypeID
    let previewNoteId: NoteID?
    let initialTemplateIndex: Int
    let mode: TemplateEditorMode
    var onSaved: (@Sendable () async -> Void)? = nil

    @AppStorage("codeEditor_fontSize") private var codeEditorFontSize: Double = 14.0
    @AppStorage("codeEditor_fontFamily") private var codeEditorFontFamilyRaw: String = "Menlo"

    @State private var model = TemplateEditorModel()
    @State private var showDiscardChangesConfirmation = false
    @State private var showSaveError = false
    @State private var editorTab: TemplateEditorTab = .front
    @State private var showFieldManager = false
    @State private var showPreviewSheet = false
    @State private var editorSearchText = ""

    init(
        notetypeId: NotetypeID,
        previewNoteId: NoteID? = nil,
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

    private var currentTemplateValidationMessage: String? {
        templateValidationMessage(for: model.notetype)
    }

    private var canSaveTemplate: Bool {
        model.notetype.templates.indices.contains(model.selectedTemplateIndex)
            && currentTemplateValidationMessage == nil
            && !model.isSaving
    }

    private var separatorBorderColor: Color {
        colorScheme == .light
            ? palette.border.opacity(0.8)
            : palette.border.opacity(0.5)
    }

    private var currentTemplateName: String {
        guard model.notetype.templates.indices.contains(model.selectedTemplateIndex) else {
            return "No template selected."
        }
        return model.notetype.templates[model.selectedTemplateIndex].name
    }

    var body: some View {
        NavigationStack {
            mainContent
                .background(palette.background)
                .navigationTitle(mode.title)
                .navigationBarTitleDisplayMode(.inline)
                .interactiveDismissDisabled(model.hasUnsavedChanges)
                .toolbar { toolbarContent }
                .modifier(TemplateEditorPresentations(
                    showSaveError: $showSaveError,
                    errorMessage: model.errorMessage,
                    showDiscardChangesConfirmation: $showDiscardChangesConfirmation,
                    onDiscard: { dismiss() },
                    showFieldManager: $showFieldManager,
                    fieldManager: { fieldManagerSheet },
                    showPreviewSheet: $showPreviewSheet,
                    preview: { previewSheet }
                ))
                .task { await model.loadNotetype(notetypeId: notetypeId, preferred: initialTemplateIndex) }
        }
    }

    private var fieldManagerSheet: some View {
        NavigationStack {
            NotetypeFieldManagerView(
                notetypeId: notetypeId,
                preferredName: model.notetype.name,
                onSaved: {
                    await model.loadNotetype(notetypeId: notetypeId)
                    if let onSaved {
                        await onSaved()
                    }
                }
            )
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        if model.isLoading {
            ProgressView()
        } else if let errorMessage = model.errorMessage {
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

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
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
            Button("Fields") { showFieldManager = true }
                .amgiToolbarTextButton(tone: .neutral)
                .disabled(model.isLoading)
        }
        ToolbarItem(placement: .topBarTrailing) {
            if model.isSaving {
                ProgressView()
            } else {
                Button("Save") {
                    Task {
                        if await model.saveTemplate(onSaved: onSaved) {
                            dismiss()
                        } else {
                            showSaveError = true
                        }
                    }
                }
                .amgiToolbarTextButton()
                .disabled(!canSaveTemplate)
            }
        }
    }

    private var editorContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                TemplateEditorHeaderCard(
                    currentTemplateName: currentTemplateName,
                    allowsTemplateSelection: mode.allowsTemplateSelection,
                    templates: model.notetype.templates,
                    selectedTemplateIndex: $model.selectedTemplateIndex,
                    editorTab: $editorTab,
                    onPreviewTab: { previousTab in
                        showPreviewSheet = true
                        editorTab = previousTab
                    },
                    borderColor: separatorBorderColor
                )

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
                    fontSize: codeEditorFontSize,
                    fontFamilyRaw: codeEditorFontFamilyRaw
                )
                .padding(16)
                .frame(minHeight: 420)
                .background(palette.surfaceElevated, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .stroke(separatorBorderColor, lineWidth: 1)
                }

                InsertFieldSearchBox(
                    searchText: $editorSearchText,
                    borderColor: separatorBorderColor
                )
            }
            .padding(20)
        }
        .background(palette.background)
    }

    private var previewSheet: some View {
        TemplatePreviewSheet(
            title: "Rendered preview",
            emptyMessage: "This card has no content to preview.",
            notetype: model.notetype,
            initialTemplateIndex: model.selectedTemplateIndex,
            loadSampleFields: {
                try await model.loadSampleFields(notetypeId: notetypeId, previewNoteId: previewNoteId)
            }
        )
    }

    private var currentFieldNames: [String] {
        editorTab == .css ? [] : model.notetype.fields.map(\.name)
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
                guard model.notetype.templates.indices.contains(model.selectedTemplateIndex) else { return "" }
                return model.notetype.templates[model.selectedTemplateIndex].config.qFormat
            },
            set: { newValue in
                guard model.notetype.templates.indices.contains(model.selectedTemplateIndex) else { return }
                var config = model.notetype.templates[model.selectedTemplateIndex].config
                config.qFormat = newValue
                model.notetype.templates[model.selectedTemplateIndex].config = config
            }
        )
    }

    private var aFormatBinding: Binding<String> {
        Binding(
            get: {
                guard model.notetype.templates.indices.contains(model.selectedTemplateIndex) else { return "" }
                return model.notetype.templates[model.selectedTemplateIndex].config.aFormat
            },
            set: { newValue in
                guard model.notetype.templates.indices.contains(model.selectedTemplateIndex) else { return }
                var config = model.notetype.templates[model.selectedTemplateIndex].config
                config.aFormat = newValue
                model.notetype.templates[model.selectedTemplateIndex].config = config
            }
        )
    }

    private var cssBinding: Binding<String> {
        Binding(
            get: { model.notetype.config.css },
            set: { newValue in
                var config = model.notetype.config
                config.css = newValue
                model.notetype.config = config
            }
        )
    }

}

private extension TemplateEditorView {
    func attemptDismiss() {
        if model.hasUnsavedChanges {
            showDiscardChangesConfirmation = true
        } else {
            dismiss()
        }
    }
}

struct TemplateEditorPresentations<FieldManager: View, Preview: View>: ViewModifier {
    @Binding var showSaveError: Bool
    let errorMessage: String?
    @Binding var showDiscardChangesConfirmation: Bool
    let onDiscard: () -> Void
    @Binding var showFieldManager: Bool
    @ViewBuilder let fieldManager: () -> FieldManager
    @Binding var showPreviewSheet: Bool
    @ViewBuilder let preview: () -> Preview

    func body(content: Content) -> some View {
        content
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
                Button("Discard", role: .destructive) { onDiscard() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("You have unsaved changes. Discard them?")
            }
            .sheet(isPresented: $showFieldManager) { fieldManager() }
            .sheet(isPresented: $showPreviewSheet) { preview() }
    }
}

// MARK: - Editor subviews

struct TemplateEditorHeaderCard: View {
    let currentTemplateName: String
    let allowsTemplateSelection: Bool
    let templates: [Notetype.Template]
    @Binding var selectedTemplateIndex: Int
    @Binding var editorTab: TemplateEditorTab
    let onPreviewTab: (TemplateEditorTab) -> Void
    let borderColor: Color

    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if allowsTemplateSelection, templates.count > 1 {
                HStack(spacing: 12) {
                    Text(currentTemplateName)
                        .amgiFont(.bodyEmphasis)
                        .foregroundStyle(palette.textSecondary)
                    Spacer()
                    templatePickerMenu
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
                    onPreviewTab(old)
                }
            }
        }
        .padding(16)
        .background(palette.surfaceElevated, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        }
    }

    private var templatePickerMenu: some View {
        Menu {
            ForEach(Array(templates.enumerated()), id: \.offset) { index, template in
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
                    .amgiFont(.caption)
                    .foregroundStyle(palette.textSecondary)
            }
            .amgiCapsuleControl(horizontalPadding: 12, verticalPadding: 8)
        }
    }
}

struct InsertFieldSearchBox: View {
    @Binding var searchText: String
    let borderColor: Color

    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Insert field")
                .amgiFont(.captionBold)
                .foregroundStyle(palette.textSecondary)

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(palette.textSecondary)
                TextField("Search fields", text: $searchText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(palette.surfaceElevated, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            }
        }
    }
}
