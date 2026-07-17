import Sharing
import SwiftUI

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

    var body: some View {
        Form {
            Section("Reader Tab") {
                Toggle("Show Reader tab", isOn: Binding($showTab))
            }

            Section("Lookup") {
                Toggle("Tap word to look up", isOn: Binding($tapLookup))
            }

            Section("Display") {
                Picker("Font", selection: Binding($selectedFontRaw)) {
                    ForEach(ReaderFontOption.allCases) { option in
                        Text(option.title).tag(option.rawValue)
                    }
                }
                LabeledContent("Font size") {
                    Stepper("\(Int(fontSize))pt", value: Binding($fontSize), in: 12...32, step: 1)
                }
                LabeledContent("Line height") {
                    Stepper(String(format: "%.1f", lineHeight), value: Binding($lineHeight), in: 1.0...2.5, step: 0.1)
                }
                LabeledContent("Horizontal padding") {
                    Stepper("\(Int(horizontalPadding))pt", value: Binding($horizontalPadding), in: 0...64, step: 2)
                }
                LabeledContent("Vertical padding") {
                    Stepper("\(Int(verticalPadding))pt", value: Binding($verticalPadding), in: 0...64, step: 2)
                }
                Toggle("Justify text", isOn: Binding($justifyText))
                LabeledContent("Letter spacing") {
                    Stepper(
                        String(format: "%.2fem", characterSpacing / 100),
                        value: Binding($characterSpacing),
                        in: -5...20,
                        step: 1
                    )
                }
                Toggle("Avoid breaking paragraphs", isOn: Binding($avoidPageBreak))
                Toggle("Hide furigana / ruby", isOn: Binding($hideFurigana))
                Toggle("Vertical writing (CJK)", isOn: Binding($verticalLayout))
            }

            Section("Theme") {
                Picker("Theme", selection: Binding($themeModeRaw)) {
                    ForEach(ReaderThemeMode.allCases) { mode in
                        Text(mode.label).tag(mode.rawValue)
                    }
                }

                if themeModeRaw == ReaderThemeMode.custom.rawValue {
                    // Hex string ↔ Color bridge: ColorPicker writes a
                    // Color, we round-trip through #RRGGBB so the value
                    // persists in @Shared and slots into the chapter
                    // reader's CSS without further conversion.
                    ColorPicker(
                        "Text colour",
                        selection: hexBinding(for: $customTextColorHex, fallback: .primary),
                        supportsOpacity: false
                    )
                    ColorPicker(
                        "Background colour",
                        selection: hexBinding(for: $customBackgroundColorHex, fallback: Color(.systemBackground)),
                        supportsOpacity: false
                    )
                    if !hideFurigana {
                        ColorPicker(
                            "Furigana / hint colour",
                            selection: hexBinding(for: $customHintColorHex, fallback: .secondary),
                            supportsOpacity: false
                        )
                    }
                }
            }

            Section("Toolbar") {
                Toggle("Show chapter title", isOn: Binding($showTitle))
                Toggle("Show percentage", isOn: Binding($showPercentage))
                Toggle("Top progress bar", isOn: Binding($showProgressTop))
                Toggle("Debug overlay", isOn: Binding($debugInfoEnabled))
            }

            Section("Lookup popup") {
                Toggle("Full-screen popup", isOn: Binding($popupFullWidth))
                if !popupFullWidth {
                    LabeledContent("Popup height") {
                        Stepper("\(Int(popupHeight))%", value: Binding($popupHeight), in: 30...95, step: 5)
                    }
                }
                Toggle("Swipe-down handle", isOn: Binding($popupSwipeToDismiss))
                Toggle("Collapse dictionaries", isOn: Binding($popupCollapseDictionaries))
                Toggle("Compact glossaries", isOn: Binding($popupCompactGlossaries))
                LabeledContent("Body font") {
                    Stepper("\(Int(popupFontSize))pt", value: Binding($popupFontSize), in: 11...28, step: 1)
                }
                LabeledContent("Definition font") {
                    Stepper("\(Int(popupContentFontSize))pt", value: Binding($popupContentFontSize), in: 11...28, step: 1)
                }
                LabeledContent("Reading font") {
                    Stepper("\(Int(popupKanaFontSize))pt", value: Binding($popupKanaFontSize), in: 9...24, step: 1)
                }
                LabeledContent("Frequency font") {
                    Stepper("\(Int(popupFrequencyFontSize))pt", value: Binding($popupFrequencyFontSize), in: 8...20, step: 1)
                }
                LabeledContent("Dictionary header") {
                    Stepper("\(Int(popupDictionaryNameFontSize))pt", value: Binding($popupDictionaryNameFontSize), in: 8...20, step: 1)
                }
            }
        }
        .navigationTitle("Reader Display")
        .navigationBarTitleDisplayMode(.inline)
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
