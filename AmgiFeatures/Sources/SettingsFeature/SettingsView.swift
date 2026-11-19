//
//  SettingsView.swift
//  SettingsFeature
//
//  Created by Vladimir Gusev on 28.04.2026.
//

package import SwiftUI
import Theme
package import AppCore
import AppShared
import BrowseFeature
import TemplatesFeature

/// Settings, following the `amgi-settings.jsx` screen in the Amgi design
/// project: native large-title navigation bar, grouped inset panels, tinted glyph
/// tiles, trailing values, hairline footer.
///
/// Row inventory is the app's real screens rather than the mock's — the
/// mock names four destinations that don't exist (Privacy & Data, a global
/// FSRS Scheduler, an auto-card-from-highlights toggle, onboarding replay)
/// and omits three that do (Backups, Media Check, Code Editor).
package struct SettingsView: View {
    private let onSwitchProfile: (AmgiAccount) async -> Void

    /// - Parameter onSwitchProfile: profile switching closes/reopens the
    ///   collection, cancels sync and flips the keychain anchor — composition-
    ///   root work that lives in `RootFeature/ProfileSwitching.swift`. Same
    ///   shape as `DeckListView.onSwitchProfile`.
    package init(onSwitchProfile: @escaping (AmgiAccount) async -> Void) {
        self.onSwitchProfile = onSwitchProfile
    }

    @Environment(\.palette) private var palette

    @Environment(\.dictionarySettings) private var dictionarySettings

    package var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                appearanceSection
                accountSection
                studySection
                readerSection
                maintenanceSection
                aboutSection
                footer
            }
            .padding(.bottom, AmgiSpacing.xl)
        }
        .background(palette.background)
        .navigationTitle(String(localized: "Settings", bundle: .module))
    }

    // MARK: - Sections

    private var appearanceSection: some View {
        Group {
            SettingsSectionHeader(title: String(localized: "Appearance", bundle: .module))
            SettingsGroup {
                SettingsRowLink(
                    title: String(localized: "Theme & Appearance", bundle: .module),
                    systemImage: "paintpalette",
                    tone: .mature,
                    detail: themeName
                ) {
                    AppearanceSettingsView(manager: .shared)
                }
                #if canImport(UIKit)
                SettingsSeparator()
                SettingsRowLink(
                    title: String(localized: "Reader Display", bundle: .module),
                    systemImage: "book",
                    tone: .learning
                ) {
                    ReaderSettingsView()
                }
                #endif
            }
        }
    }

    private var accountSection: some View {
        Group {
            SettingsSectionHeader(title: String(localized: "Account", bundle: .module))
            SettingsGroup {
                SettingsRowLink(
                    title: String(localized: "Profiles", bundle: .module),
                    systemImage: "person.crop.circle",
                    tone: .accent,
                    detail: AccountStore.shared.current.displayName
                ) {
                    AccountsSettingsView(onSwitchProfile: onSwitchProfile)
                }
                SettingsSeparator()
                SettingsRowLink(
                    title: String(localized: "Sync Server", bundle: .module),
                    systemImage: "arrow.triangle.2.circlepath",
                    tone: .info
                ) {
                    SyncSettingsView()
                }
            }
        }
    }

    private var studySection: some View {
        Group {
            SettingsSectionHeader(title: String(localized: "Study", bundle: .module))
            SettingsGroup {
                SettingsRowLink(
                    title: String(localized: "Word Spotlight", bundle: .module),
                    systemImage: "character.book.closed",
                    tone: .accent
                ) {
                    WordSpotlightSettingsView()
                }
                .accessibilityIdentifier("settings.wordSpotlight")
                SettingsSeparator()
                SettingsRowLink(
                    title: String(localized: "Review Behavior", bundle: .module),
                    systemImage: "timer",
                    tone: .review
                ) {
                    ReviewSettingsView()
                }
                SettingsSeparator()
                SettingsRowLink(
                    title: String(localized: "Card Rendering", bundle: .module),
                    systemImage: "textformat",
                    tone: .accent
                ) {
                    CardRenderingSettingsView()
                }
                SettingsSeparator()
                SettingsRowLink(
                    title: String(localized: "Manage Templates", bundle: .module),
                    systemImage: "doc.text",
                    tone: .learning
                ) {
                    DeckTemplateListView()
                }
                SettingsSeparator()
                SettingsRowLink(
                    title: String(localized: "Template Overrides", bundle: .module),
                    systemImage: "arrow.turn.down.right",
                    tone: .neutral
                ) {
                    TemplateOverridesView()
                }
                SettingsSeparator()
                SettingsRowLink(
                    title: String(localized: "Code Editor", bundle: .module),
                    systemImage: "chevron.left.forwardslash.chevron.right",
                    tone: .link
                ) {
                    CodeEditorSettingsView()
                }
            }
        }
    }

    private var readerSection: some View {
        Group {
            if let dictionarySettings {
                SettingsSectionHeader(title: String(localized: "Reader", bundle: .module))
                SettingsGroup {
                    SettingsRowLink(
                        title: String(localized: "Dictionaries", bundle: .module),
                        systemImage: "character.book.closed",
                        tone: .danger
                    ) {
                        dictionarySettings.settings()
                    }
                }
            }
        }
    }

    private var maintenanceSection: some View {
        Group {
            SettingsSectionHeader(title: String(localized: "Maintenance", bundle: .module))
            SettingsGroup {
                SettingsRowLink(
                    title: String(localized: "Manage Tags", bundle: .module),
                    systemImage: "tag",
                    tone: .neutral
                ) {
                    TagsView()
                }
                SettingsSeparator()
                SettingsRowLink(
                    title: String(localized: "Database", bundle: .module),
                    systemImage: "internaldrive",
                    tone: .info
                ) {
                    MaintenanceView()
                }
                SettingsSeparator()
                SettingsRowLink(
                    title: String(localized: "Empty Cards", bundle: .module),
                    systemImage: "square.dashed",
                    tone: .danger
                ) {
                    EmptyCardsView()
                }
                SettingsSeparator()
                SettingsRowLink(
                    title: String(localized: "Backups", bundle: .module),
                    systemImage: "clock.arrow.circlepath",
                    tone: .mature
                ) {
                    BackupView(username: AccountStore.shared.current.displayName)
                }
                SettingsSeparator()
                SettingsRowLink(
                    title: String(localized: "Media Check", bundle: .module),
                    systemImage: "photo",
                    tone: .learning
                ) {
                    MediaCheckResultView()
                }
            }
        }
    }

    private var aboutSection: some View {
        Group {
            SettingsSectionHeader(title: String(localized: "About", bundle: .module))
            SettingsGroup {
                SettingsRowLink(
                    title: String(localized: "About Amgi", bundle: .module),
                    systemImage: "info.circle",
                    tone: .accent,
                    detail: appVersion
                ) {
                    AboutView()
                }
            }
        }
    }

    private var footer: some View {
        Text("Amgi · v\(appVersion) · Built with care", bundle: .module)
            .amgiFont(.micro)
            .foregroundStyle(palette.textTertiary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 20)
            .padding(.bottom, AmgiSpacing.sm)
    }

    // MARK: - Trailing values

    /// Only values the screen can state with certainty are shown. The mock
    /// also puts a value on Reader Display, Sync Server and Dictionaries;
    /// those need state this screen doesn't own, so they stay blank rather
    /// than guess.
    private var themeName: String {
        let id = ThemeManager.shared.themeID.rawValue
        return ThemeRegistry.shared.allThemes()
            .first { $0.id == id }?
            .displayName ?? "—"
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }
}

#if DEBUG

#Preview {
    NavigationStack {
        SettingsView(onSwitchProfile: { _ in })
    }
}
#endif
