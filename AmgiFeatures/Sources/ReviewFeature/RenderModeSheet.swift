//
//  RenderModeSheet.swift
//  ReviewFeature
//
//  Created by Vladimir Gusev on 20.07.2026.
//

import SwiftUI
package import AmgiCardWeb
import Theme
import AppCore
import Sharing
import ReviewCore

extension CardRenderEngine {
    package var displayName: String {
        switch self {
        case .auto: "Auto"
        case .alwaysNative: "Native"
        case .alwaysHTML: "HTML"
        }
    }

    package var summary: String {
        switch self {
        case .auto: "Use the built-in renderer for simple cards, and the card's own template for the rest."
        case .alwaysNative: "Use the built-in renderer wherever the card allows it."
        case .alwaysHTML: "Always use the card's own template."
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
            .onChange(of: engineRaw) { _, _ in onChanged() }
            .onChange(of: overridesRaw) { _, _ in onChanged() }
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
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(engine.displayName)
                        .foregroundStyle(palette.textPrimary)
                    Text(engine.summary)
                        .amgiFont(.caption)
                        .foregroundStyle(palette.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
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
