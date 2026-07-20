import SwiftUI
import AmgiCardWeb
import AmgiTheme
import Sharing

/// R11 "Card Rendering" settings: global engine picker plus a link to the
/// per-template overrides list. Lives under the Review section until the
/// R24 Settings restructure re-homes it.
struct CardRenderingSettingsView: View {
    @Shared(.appStorage(ReviewPreferences.Keys.cardRenderEngine))
    private var engineRaw: String = CardRenderEngine.auto.rawValue

    @Shared(.appStorage(ReviewPreferences.Keys.templateRenderOverrides))
    private var overridesRaw: String = "{}"

    @Environment(\.palette) private var palette

    var body: some View {
        Form {
            Section {
                Picker("Engine", selection: engineBinding) {
                    ForEach(CardRenderEngine.allCases, id: \.self) { engine in
                        Text(engine.displayName).tag(engine)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } footer: {
                Text(selectedEngine.summary)
            }

            Section {
                NavigationLink {
                    TemplateOverridesView()
                } label: {
                    HStack {
                        Text("Per-template overrides…")
                        Spacer()
                        Text("\(overrideCount) set")
                            .foregroundStyle(palette.textSecondary)
                    }
                }
            } footer: {
                Text("Overrides pick an engine for every card of one template and beat the global choice. Stored on this device only.")
            }
        }
        .navigationTitle("Card Rendering")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var selectedEngine: CardRenderEngine {
        CardRenderEngine(rawValue: engineRaw) ?? .auto
    }

    private var overrideCount: Int {
        TemplateRenderOverrides.entries(in: overridesRaw).count
    }

    private var engineBinding: Binding<CardRenderEngine> {
        Binding(
            get: { selectedEngine },
            set: { newValue in $engineRaw.withLock { $0 = newValue.rawValue } }
        )
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        CardRenderingSettingsView()
    }
}
#endif
