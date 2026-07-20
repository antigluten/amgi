import SwiftUI
import AmgiCardWeb
import AmgiTheme
import Sharing

extension CardRenderEngine {
    var displayName: String {
        switch self {
        case .auto: "Auto"
        case .alwaysNative: "Native"
        case .alwaysHTML: "HTML"
        }
    }

    var summary: String {
        switch self {
        case .auto: "Simple cards render natively, the rest use the template's HTML."
        case .alwaysNative: "Prefer native rendering wherever the card allows it."
        case .alwaysHTML: "Always render the template's HTML in the sandboxed web view."
        }
    }
}

/// R11 render-mode sheet: global engine radio (Auto / Native / HTML), a
/// "This card" explainer, and a per-template override row. Writes go to
/// appStorage; `onChanged` lets the reviewer re-resolve the current card.
struct RenderModeSheet: View {
    let explainer: String
    let template: ReviewSession.TemplateTarget?
    let templateName: String?
    let onChanged: () -> Void

    @Shared(.appStorage(ReviewPreferences.Keys.cardRenderEngine))
    private var engineRaw: String = CardRenderEngine.auto.rawValue

    @Shared(.appStorage(ReviewPreferences.Keys.templateRenderOverrides))
    private var overridesRaw: String = "{}"

    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(CardRenderEngine.allCases, id: \.self) { engine in
                        engineRow(engine)
                    }
                } footer: {
                    Text("This card: \(explainer)")
                }

                if let template {
                    Section {
                        Picker("Override", selection: overrideBinding(for: template)) {
                            Text("Default").tag(CardRenderEngine?.none)
                            Text("Native").tag(CardRenderEngine?.some(.alwaysNative))
                            Text("HTML").tag(CardRenderEngine?.some(.alwaysHTML))
                        }
                    } header: {
                        Text(templateName.map { "Template · \($0)" } ?? "This template")
                    } footer: {
                        Text("Overrides the global choice for every card of this template. Stored on this device only.")
                    }
                }
            }
            .navigationTitle("Card Rendering")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private var globalEngine: CardRenderEngine {
        CardRenderEngine(rawValue: engineRaw) ?? .auto
    }

    private func engineRow(_ engine: CardRenderEngine) -> some View {
        Button {
            $engineRaw.withLock { $0 = engine.rawValue }
            onChanged()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(engine.displayName)
                        .foregroundStyle(palette.textPrimary)
                    Text(engine.summary)
                        .amgiFont(.caption)
                        .foregroundStyle(palette.textSecondary)
                }
                Spacer()
                if engine == globalEngine {
                    Image(systemName: "checkmark")
                        .foregroundStyle(palette.accent)
                }
            }
        }
    }

    private func overrideBinding(for template: ReviewSession.TemplateTarget) -> Binding<CardRenderEngine?> {
        Binding(
            get: {
                TemplateRenderOverrides.engine(
                    for: template.notetypeId,
                    ord: template.ordinal,
                    in: overridesRaw
                )
            },
            set: { newValue in
                let updated = TemplateRenderOverrides.setting(
                    newValue,
                    mid: template.notetypeId,
                    ord: template.ordinal,
                    in: overridesRaw
                )
                $overridesRaw.withLock { $0 = updated }
                onChanged()
            }
        )
    }
}

#if DEBUG
#Preview {
    RenderModeSheet(
        explainer: "rendered natively — passes the simplicity check.",
        template: nil,
        templateName: "Card 1",
        onChanged: {}
    )
}
#endif
