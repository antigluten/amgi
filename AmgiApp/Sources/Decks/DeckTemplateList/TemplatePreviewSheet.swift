import SwiftUI
import AmgiTheme
import AnkiClients
import AnkiKit
import Dependencies

/// Preview sheet for uncommitted (unsaved) card templates, using CardRenderingService.
struct TemplatePreviewSheet: View {
    @Dependency(\.cardRenderingService) var cardRenderingService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette

    let title: String
    let emptyMessage: String
    let notetype: Notetype
    let loadSampleFields: () async throws -> [String]

    @State private var selectedTemplateIndex: Int
    @State private var previewSide: CardPreviewSide = .front
    @State private var sampleFields: [String]?
    @State private var renderedFrontHTML = ""
    @State private var renderedBackHTML = ""
    @State private var isLoading = false
    @State private var isEmptyCard = false
    @State private var errorMessage: String?

    init(
        title: String,
        emptyMessage: String,
        notetype: Notetype,
        initialTemplateIndex: Int = 0,
        loadSampleFields: @escaping () async throws -> [String]
    ) {
        self.title = title
        self.emptyMessage = emptyMessage
        self.notetype = notetype
        self.loadSampleFields = loadSampleFields
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
                TemplatePreviewHeader(
                    currentTemplateName: currentTemplateName,
                    previewSide: $previewSide
                )
                TemplatePreviewBody(
                    isLoading: isLoading,
                    errorMessage: errorMessage,
                    isEmptyCard: isEmptyCard,
                    emptyMessage: emptyMessage,
                    html: currentHTML
                )
            }
            .background(palette.surfaceElevated)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .task { await loadAndRenderPreview() }
            .onChange(of: selectedTemplateIndex) {
                Task { await renderPreview() }
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button("Done") { dismiss() }
                .amgiToolbarTextButton()
        }
    }

}

private extension TemplatePreviewSheet {
    @MainActor
    func loadAndRenderPreview() async {
        do {
            sampleFields = try await loadSampleFields()
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
    func renderPreview() async {
        guard notetype.templates.indices.contains(selectedTemplateIndex) else {
            isLoading = false
            isEmptyCard = false
            errorMessage = "No template selected."
            renderedFrontHTML = ""
            renderedBackHTML = ""
            return
        }

        guard let fields = sampleFields else {
            await loadAndRenderPreview()
            return
        }

        isLoading = true
        defer { isLoading = false }

        let cardRenderingService = self.cardRenderingService
        let notetype = self.notetype
        let templateIndex = selectedTemplateIndex

        do {
            let rendered = try await Task.detached(priority: .userInitiated) {
                try cardRenderingService.renderUncommittedCard(
                    notetype,
                    templateIndex,
                    fields
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

enum CardPreviewSide: CaseIterable {
    case front
    case back

    var label: String {
        switch self {
        case .front: return "Front"
        case .back: return "Back"
        }
    }
}

struct TemplatePreviewHeader: View {
    let currentTemplateName: String
    @Binding var previewSide: CardPreviewSide

    @Environment(\.palette) private var palette

    var body: some View {
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
    }
}

struct TemplatePreviewBody: View {
    let isLoading: Bool
    let errorMessage: String?
    let isEmptyCard: Bool
    let emptyMessage: String
    let html: String

    @Environment(\.palette) private var palette

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage {
                placeholder(systemImage: "exclamationmark.triangle", text: errorMessage, tint: palette.warning)
            } else if isEmptyCard {
                placeholder(systemImage: "rectangle.slash", text: emptyMessage, tint: palette.textTertiary)
            } else {
                ScrollView {
                    Text(html).padding()
                }
            }
        }
    }

}

private extension TemplatePreviewBody {
    func placeholder(systemImage: String, text: String, tint: Color) -> some View {
        VStack(spacing: AmgiSpacing.sm) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(tint)
            Text(text)
                .amgiFont(.body)
                .foregroundStyle(palette.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
