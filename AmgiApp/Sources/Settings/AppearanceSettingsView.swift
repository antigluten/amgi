import SwiftUI
import AmgiTheme

struct AppearanceSettingsView: View {
    @Bindable var manager: ThemeManager
    @AppStorage("appFont") private var appFontRaw: String = AppFont.system.rawValue

    var body: some View {
        Form {
            Section("Theme") {
                themePickerRow
            }

            Section("Appearance") {
                Picker("Appearance", selection: $manager.appearance) {
                    Text("System").tag(Appearance.system)
                    Text("Light").tag(Appearance.light)
                    Text("Dark").tag(Appearance.dark)
                }
                .pickerStyle(.segmented)
            }

            Section {
                Picker("Font", selection: $appFontRaw) {
                    Text("System").tag(AppFont.system.rawValue)
                    Text("Serif").tag(AppFont.serif.rawValue)
                }
            } header: {
                Text("App font")
            } footer: {
                Text("Changes the font used throughout the app. Card-template content and hero numbers stay in their own typeface.")
            }

            Section("Preview") {
                PreviewCard()
                    .listRowBackground(Color.clear)
            }
        }
        .navigationTitle("Appearance")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var themePickerRow: some View {
        let themes = ThemeRegistry.shared.allThemes()
        VStack(spacing: AmgiSpacing.md) {
            ForEach(themes, id: \.id) { data in
                let id = ThemeID(rawValue: data.id)
                ThemeCard(
                    themeID: id,
                    label: data.displayName,
                    isSelected: manager.themeID == id
                ) {
                    manager.themeID = id
                }
            }
        }
        .padding(.vertical, AmgiSpacing.xs)
    }
}

private struct ThemeCard: View {
    let themeID: ThemeID
    let label: String
    let isSelected: Bool
    let onTap: () -> Void

    @Environment(\.colorScheme) private var systemScheme

    var body: some View {
        let preview = ThemeRegistry.shared.palette(id: themeID, scheme: systemScheme)
        Button(action: onTap) {
            HStack(spacing: AmgiSpacing.md) {
                VStack(spacing: 4) {
                    bar(color: preview.background)
                    bar(color: preview.surface)
                    bar(color: preview.accent)
                }
                .padding(AmgiSpacing.sm)
                .background(preview.surface, in: RoundedRectangle(cornerRadius: 8))
                .frame(width: 80)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                }
                Text(label).bold()
                Spacer()
            }
            .padding(AmgiSpacing.md)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? preview.accent : preview.border, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private extension ThemeCard {
    func bar(color: Color) -> some View {
        RoundedRectangle(cornerRadius: 3).fill(color).frame(height: 10)
    }
}

private struct PreviewCard: View {
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: AmgiSpacing.sm) {
            Text("Preview")
                .amgiFont(.cardTitle)
                .foregroundStyle(palette.textPrimary)
            Text("Body text in the active palette.")
                .amgiFont(.body)
                .foregroundStyle(palette.textSecondary)

            HStack(spacing: AmgiSpacing.sm) {
                badge("Positive", color: palette.positive)
                badge("Warning", color: palette.warning)
                badge("Danger", color: palette.danger)
            }

            Button("Primary action") {}
                .buttonStyle(AmgiPrimaryButtonStyle())
        }
        .padding(AmgiSpacing.lg)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: 12))
    }
}

private extension PreviewCard {
    func badge(_ text: String, color: Color) -> some View {
        Text(text)
            .amgiFont(.captionBold)
            .foregroundStyle(color)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(color.opacity(0.15), in: Capsule())
    }
}

#Preview("Vivid Light") {
    NavigationStack { AppearanceSettingsView(manager: ThemeManager(defaults: UserDefaults(suiteName: "preview-vivid-light")!)) }
        .environment(\.palette, ThemeRegistry.shared.palette(id: .vivid, scheme: .light))
        .preferredColorScheme(.light)
}

#Preview("Muted Dark") {
    NavigationStack { AppearanceSettingsView(manager: ThemeManager(defaults: UserDefaults(suiteName: "preview-muted-dark")!)) }
        .environment(\.palette, ThemeRegistry.shared.palette(id: .muted, scheme: .dark))
        .preferredColorScheme(.dark)
}
