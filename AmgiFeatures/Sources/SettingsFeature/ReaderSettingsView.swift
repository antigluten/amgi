//
//  ReaderSettingsView.swift
//  SettingsFeature
//
//  Created by Vladimir Gusev on 05.05.2026.
//

import Sharing
import SwiftUI
import Theme
import AppCore
import AppShared

/// Tight subset of DreamAfar's reader display preferences. Keys are
/// already declared in `ReaderPreferences.Keys`; this view binds the
/// most-used ones to controls. Popup styling, custom colours, vertical-
/// layout, and per-page padding details are deferred — they need their
/// own pass and weren't gating any current user flow.
struct ReaderSettingsView: View {
    @Shared(.appStorage(ReaderPreferences.Keys.showTab))
    private var showTab: Bool = true

    @Shared(.appStorage(ReaderPreferences.Keys.tapLookup))
    private var tapLookup: Bool = true

    // Display — chapter reader CSS pulls these via ChapterReaderStyle.
    @Shared(.appStorage(ReaderPreferences.Keys.selectedFont))
    private var selectedFontRaw: String = ReaderFontOption.defaultValue

    @Shared(.appStorage(ReaderPreferences.Keys.fontSize))
    private var fontSize: Double = 17

    @Shared(.appStorage(ReaderPreferences.Keys.lineHeight))
    private var lineHeight: Double = 1.5

    @Shared(.appStorage(ReaderPreferences.Keys.horizontalPadding))
    private var horizontalPadding: Double = 18

    @Shared(.appStorage(ReaderPreferences.Keys.verticalPadding))
    private var verticalPadding: Double = 16

    @Shared(.appStorage(ReaderPreferences.Keys.justifyText))
    private var justifyText: Bool = false

    @Shared(.appStorage(ReaderPreferences.Keys.themeMode))
    private var themeModeRaw: String = "system"

    @Shared(.appStorage(ReaderPreferences.Keys.customTextColor))
    private var customTextColorHex: String = "#1F2A26"

    @Shared(.appStorage(ReaderPreferences.Keys.customBackgroundColor))
    private var customBackgroundColorHex: String = "#FAF7F2"

    @Shared(.appStorage(ReaderPreferences.Keys.customHintColor))
    private var customHintColorHex: String = "#777777"

    @Shared(.appStorage(ReaderPreferences.Keys.characterSpacing))
    private var characterSpacing: Double = 0

    @Shared(.appStorage(ReaderPreferences.Keys.avoidPageBreak))
    private var avoidPageBreak: Bool = true

    @Shared(.appStorage(ReaderPreferences.Keys.hideFurigana))
    private var hideFurigana: Bool = false

    // Top bar.
    @Shared(.appStorage(ReaderPreferences.Keys.showTitle))
    private var showTitle: Bool = true

    @Shared(.appStorage(ReaderPreferences.Keys.showPercentage))
    private var showPercentage: Bool = true

    @Shared(.appStorage(ReaderPreferences.Keys.showProgressTop))
    private var showProgressTop: Bool = false

    @Shared(.appStorage(ReaderPreferences.Keys.verticalLayout))
    private var verticalLayout: Bool = false

    @Shared(.appStorage(ReaderPreferences.Keys.popupDebugInfoEnabled))
    private var debugInfoEnabled: Bool = false

    // Lookup popup styling.
    @Shared(.appStorage(ReaderPreferences.Keys.popupHeight))
    private var popupHeight: Double = 60
    @Shared(.appStorage(ReaderPreferences.Keys.popupFullWidth))
    private var popupFullWidth: Bool = false
    @Shared(.appStorage(ReaderPreferences.Keys.popupSwipeToDismiss))
    private var popupSwipeToDismiss: Bool = true
    @Shared(.appStorage(ReaderPreferences.Keys.popupCollapseDictionaries))
    private var popupCollapseDictionaries: Bool = false
    @Shared(.appStorage(ReaderPreferences.Keys.popupCompactGlossaries))
    private var popupCompactGlossaries: Bool = false
    @Shared(.appStorage(ReaderPreferences.Keys.popupFontSize))
    private var popupFontSize: Double = 17
    @Shared(.appStorage(ReaderPreferences.Keys.popupContentFontSize))
    private var popupContentFontSize: Double = 17
    @Shared(.appStorage(ReaderPreferences.Keys.popupKanaFontSize))
    private var popupKanaFontSize: Double = 15
    @Shared(.appStorage(ReaderPreferences.Keys.popupFrequencyFontSize))
    private var popupFrequencyFontSize: Double = 12
    @Shared(.appStorage(ReaderPreferences.Keys.popupDictionaryNameFontSize))
    private var popupDictionaryNameFontSize: Double = 11

    @Environment(\.palette) private var palette

    var body: some View {
        SettingsPage {
            readerTabSection
            displaySection
            themeSection
            toolbarSection
            popupSection
        }
        .navigationTitle("Reader Display")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Reader tab & lookup

    /// "Reader Tab" and "Lookup" were a section each for one toggle apiece;
    /// the design's grouping reads better with both under one header.
    private var readerTabSection: some View {
        Group {
            SettingsSectionHeader(title: "Reader")
            SettingsGroup {
                SettingsToggleRow(
                    title: "Show Reader tab",
                    systemImage: "book",
                    tone: .accent,
                    isOn: Binding($showTab)
                )
                SettingsSeparator()
                SettingsToggleRow(
                    title: "Tap word to look up",
                    systemImage: "hand.tap",
                    tone: .info,
                    isOn: Binding($tapLookup)
                )
            }
        }
    }

    // MARK: - Display

    private var displaySection: some View {
        Group {
            SettingsSectionHeader(title: "Display")
            SettingsGroup {
                SettingsPickerRow(
                    title: "Font",
                    systemImage: "textformat",
                    tone: .accent,
                    selection: Binding($selectedFontRaw)
                ) {
                    ForEach(ReaderFontOption.allCases) { option in
                        Text(option.title).tag(option.rawValue)
                    }
                }
                SettingsSeparator()
                SettingsStepperRow(
                    title: "Font size",
                    systemImage: "textformat.size",
                    tone: .accent,
                    value: Binding($fontSize),
                    range: 12...32,
                    step: 1
                ) { "\(Int($0))pt" }
                SettingsSeparator()
                SettingsStepperRow(
                    title: "Line height",
                    systemImage: "arrow.up.and.down.text.horizontal",
                    tone: .link,
                    value: Binding($lineHeight),
                    range: 1.0...2.5,
                    step: 0.1
                ) { String(format: "%.1f", $0) }
                SettingsSeparator()
                SettingsStepperRow(
                    title: "Horizontal padding",
                    systemImage: "arrow.left.and.right",
                    tone: .neutral,
                    value: Binding($horizontalPadding),
                    range: 0...64,
                    step: 2
                ) { "\(Int($0))pt" }
                SettingsSeparator()
                SettingsStepperRow(
                    title: "Vertical padding",
                    systemImage: "arrow.up.and.down",
                    tone: .neutral,
                    value: Binding($verticalPadding),
                    range: 0...64,
                    step: 2
                ) { "\(Int($0))pt" }
                SettingsSeparator()
                SettingsStepperRow(
                    title: "Letter spacing",
                    systemImage: "character",
                    tone: .link,
                    value: Binding($characterSpacing),
                    range: -5...20,
                    step: 1
                ) { String(format: "%.2fem", $0 / 100) }
                SettingsSeparator()
                SettingsToggleRow(
                    title: "Justify text",
                    systemImage: "text.justify",
                    tone: .mature,
                    isOn: Binding($justifyText)
                )
                SettingsSeparator()
                SettingsToggleRow(
                    title: "Avoid breaking paragraphs",
                    systemImage: "paragraphsign",
                    tone: .mature,
                    isOn: Binding($avoidPageBreak)
                )
                SettingsSeparator()
                SettingsToggleRow(
                    title: "Hide furigana / ruby",
                    systemImage: "eye.slash",
                    tone: .learning,
                    isOn: Binding($hideFurigana)
                )
                SettingsSeparator()
                SettingsToggleRow(
                    title: "Vertical writing (CJK)",
                    systemImage: "character.textbox",
                    tone: .learning,
                    isOn: Binding($verticalLayout)
                )
            }
        }
    }

    // MARK: - Theme

    private var themeSection: some View {
        Group {
            SettingsSectionHeader(title: "Theme")
            SettingsGroup {
                SettingsPickerRow(
                    title: "Theme",
                    systemImage: "circle.lefthalf.filled",
                    tone: .mature,
                    selection: Binding($themeModeRaw)
                ) {
                    ForEach(ReaderThemeMode.allCases) { mode in
                        Text(mode.label).tag(mode.rawValue)
                    }
                }

                if themeModeRaw == ReaderThemeMode.custom.rawValue {
                    // Hex string ↔ Color bridge: ColorPicker writes a
                    // Color, we round-trip through #RRGGBB so the value
                    // persists in @Shared and slots into the chapter
                    // reader's CSS without further conversion.
                    SettingsSeparator()
                    SettingsColorRow(
                        title: "Text colour",
                        systemImage: "paintbrush",
                        tone: .link,
                        color: hexBinding(for: $customTextColorHex, fallback: palette.textPrimary)
                    )
                    SettingsSeparator()
                    SettingsColorRow(
                        title: "Background colour",
                        systemImage: "paintpalette",
                        tone: .neutral,
                        color: hexBinding(for: $customBackgroundColorHex, fallback: palette.background)
                    )
                    if !hideFurigana {
                        SettingsSeparator()
                        SettingsColorRow(
                            title: "Furigana / hint colour",
                            systemImage: "eyedropper",
                            tone: .info,
                            color: hexBinding(for: $customHintColorHex, fallback: palette.textSecondary)
                        )
                    }
                }
            }
        }
    }

    // MARK: - Toolbar

    private var toolbarSection: some View {
        Group {
            SettingsSectionHeader(title: "Toolbar")
            SettingsGroup {
                SettingsToggleRow(
                    title: "Show chapter title",
                    systemImage: "textformat",
                    tone: .accent,
                    isOn: Binding($showTitle)
                )
                SettingsSeparator()
                SettingsToggleRow(
                    title: "Show percentage",
                    systemImage: "percent",
                    tone: .review,
                    isOn: Binding($showPercentage)
                )
                SettingsSeparator()
                SettingsToggleRow(
                    title: "Top progress bar",
                    systemImage: "rectangle.topthird.inset.filled",
                    tone: .review,
                    isOn: Binding($showProgressTop)
                )
                SettingsSeparator()
                SettingsToggleRow(
                    title: "Debug overlay",
                    systemImage: "ladybug",
                    tone: .danger,
                    isOn: Binding($debugInfoEnabled)
                )
            }
        }
    }

    // MARK: - Lookup popup

    private var popupSection: some View {
        Group {
            SettingsSectionHeader(title: "Lookup Popup")
            SettingsGroup {
                SettingsToggleRow(
                    title: "Full-screen popup",
                    systemImage: "arrow.up.left.and.arrow.down.right",
                    tone: .accent,
                    isOn: Binding($popupFullWidth)
                )
                if !popupFullWidth {
                    SettingsSeparator()
                    SettingsStepperRow(
                        title: "Popup height",
                        systemImage: "arrow.up.and.down",
                        tone: .accent,
                        value: Binding($popupHeight),
                        range: 30...95,
                        step: 5
                    ) { "\(Int($0))%" }
                }
                SettingsSeparator()
                SettingsToggleRow(
                    title: "Swipe-down handle",
                    systemImage: "hand.draw",
                    tone: .info,
                    isOn: Binding($popupSwipeToDismiss)
                )
                SettingsSeparator()
                SettingsToggleRow(
                    title: "Collapse dictionaries",
                    systemImage: "rectangle.compress.vertical",
                    tone: .neutral,
                    isOn: Binding($popupCollapseDictionaries)
                )
                SettingsSeparator()
                SettingsToggleRow(
                    title: "Compact glossaries",
                    systemImage: "list.bullet",
                    tone: .neutral,
                    isOn: Binding($popupCompactGlossaries)
                )
                SettingsSeparator()
                SettingsStepperRow(
                    title: "Body font",
                    systemImage: "textformat.size",
                    tone: .mature,
                    value: Binding($popupFontSize),
                    range: 11...28,
                    step: 1
                ) { "\(Int($0))pt" }
                SettingsSeparator()
                SettingsStepperRow(
                    title: "Definition font",
                    systemImage: "text.alignleft",
                    tone: .mature,
                    value: Binding($popupContentFontSize),
                    range: 11...28,
                    step: 1
                ) { "\(Int($0))pt" }
                SettingsSeparator()
                SettingsStepperRow(
                    title: "Reading font",
                    systemImage: "quote.bubble",
                    tone: .link,
                    value: Binding($popupKanaFontSize),
                    range: 9...24,
                    step: 1
                ) { "\(Int($0))pt" }
                SettingsSeparator()
                SettingsStepperRow(
                    title: "Frequency font",
                    systemImage: "number",
                    tone: .review,
                    value: Binding($popupFrequencyFontSize),
                    range: 8...20,
                    step: 1
                ) { "\(Int($0))pt" }
                SettingsSeparator()
                SettingsStepperRow(
                    title: "Dictionary header",
                    systemImage: "character.book.closed",
                    tone: .learning,
                    value: Binding($popupDictionaryNameFontSize),
                    range: 8...20,
                    step: 1
                ) { "\(Int($0))pt" }
            }
        }
    }
}

extension ReaderSettingsView {
    fileprivate func hexBinding(
        for shared: Shared<String>,
        fallback: Color
    ) -> Binding<Color> {
        Binding(
            get: { ReaderThemeColor.color(fromHex: shared.wrappedValue, fallback: fallback) },
            set: { newColor in shared.withLock { $0 = ReaderThemeColor.hex(from: newColor) } }
        )
    }
}

extension ReaderThemeMode {
    var label: String {
        switch self {
        case .system: return "Match system"
        case .eyeCare: return "Eye-care"
        case .sepia: return "Sepia"
        case .custom: return "Custom"
        }
    }
}

#if DEBUG

// MARK: - Preview

#Preview {
    NavigationStack { ReaderSettingsView() }
}
#endif
