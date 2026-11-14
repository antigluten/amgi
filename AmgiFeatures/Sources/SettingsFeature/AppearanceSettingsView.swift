//
//  AppearanceSettingsView.swift
//  SettingsFeature
//
//  Created by Vladimir Gusev on 28.04.2026.
//

import SwiftUI
import AppCore
import Theme
import UI
import Sharing

struct AppearanceSettingsView: View {
    @Bindable var manager: ThemeManager
    @Shared(.appStorage(AppearancePreferences.Keys.appFont))
    private var appFontRaw: String = AppFont.system.rawValue

    var body: some View {
        SettingsPage {
            SettingsSectionHeader(title: String(localized: "Theme", bundle: .module))
            themePickerRow

            #if os(iOS)
            SettingsSectionHeader(title: String(localized: "App Icon", bundle: .module))
            AppIconPicker()
            #endif

            SettingsSectionHeader(title: String(localized: "Appearance", bundle: .module))
            SettingsGroup {
                Picker(String(localized: "Appearance", bundle: .module), selection: $manager.appearance) {
                    Text("System", bundle: .module).tag(Appearance.system)
                    Text("Light", bundle: .module).tag(Appearance.light)
                    Text("Dark", bundle: .module).tag(Appearance.dark)
                }
                .pickerStyle(.segmented)
                .padding(AmgiSpacing.md)
            }

            SettingsSectionHeader(title: String(localized: "App Font", bundle: .module))
            SettingsGroup {
                SettingsPickerRow(
                    title: String(localized: "Font", bundle: .module),
                    systemImage: "textformat",
                    tone: .accent,
                    selection: Binding($appFontRaw)
                ) {
                    Text("System", bundle: .module).tag(AppFont.system.rawValue)
                    Text("Serif", bundle: .module).tag(AppFont.serif.rawValue)
                }
            }
            SettingsFootnote(String(localized: "Changes the font used throughout the app. Card-template content and hero numbers stay in their own typeface.", bundle: .module))

            SettingsSectionHeader(title: String(localized: "Preview", bundle: .module))
            PreviewCard()
                .padding(.horizontal, AmgiSpacing.lg)
        }
        .navigationTitle(String(localized: "Appearance", bundle: .module))
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Theme cards draw their own selected/unselected frame, so they sit
    /// directly on the page — nesting them in a `SettingsGroup` would put a
    /// second border around every card.
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
        .padding(.horizontal, AmgiSpacing.lg)
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
                .background(preview.surface, in: RoundedRectangle(cornerRadius: AmgiRadius.small))
                .frame(width: 80)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                }
                Text(label).bold()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(AmgiSpacing.md)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: AmgiRadius.inset)
                    .stroke(isSelected ? preview.accent : preview.border, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.pressScale)
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
            Text("Preview", bundle: .module)
                .amgiFont(.cardTitle)
                .foregroundStyle(palette.textPrimary)
            Text("Body text in the active palette.", bundle: .module)
                .amgiFont(.body)
                .foregroundStyle(palette.textSecondary)

            HStack(spacing: AmgiSpacing.sm) {
                badge(String(localized: "Positive", bundle: .module), color: palette.positive)
                badge(String(localized: "Warning", bundle: .module), color: palette.warning)
                badge(String(localized: "Danger", bundle: .module), color: palette.danger)
            }

            Button(String(localized: "Primary action", bundle: .module)) {}
                .buttonStyle(AmgiPrimaryButtonStyle())
        }
        .padding(AmgiSpacing.lg)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: AmgiRadius.inset))
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

#if DEBUG

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
#endif
