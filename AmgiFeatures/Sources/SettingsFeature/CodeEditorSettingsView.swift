//
//  CodeEditorSettingsView.swift
//  SettingsFeature
//
//  Created by Vladimir Gusev on 14.05.2026.
//

import SwiftUI
import AppCore
import Theme
import Sharing

/// Font + family preferences for the HTML/CSS source editor used inside
/// `TemplateEditorView` (and any future code-editor surface). Both keys
/// live in `CodeEditorPreferences` so the editor reads the same storage.
struct CodeEditorSettingsView: View {
    @Shared(.appStorage(CodeEditorPreferences.Keys.fontSize))
    private var fontSize: Double = CodeEditorPreferences.defaultFontSize
    @Shared(.appStorage(CodeEditorPreferences.Keys.fontFamily))
    private var fontFamilyRaw: String = CodeEditorPreferences.defaultFontFamily

    @Environment(\.palette) private var palette

    private let minFontSize: Double = 10
    private let maxFontSize: Double = 32

    var body: some View {
        SettingsPage {
            SettingsSectionHeader(title: "Font")
            SettingsGroup {
                SettingsStepperRow(
                    title: "Size",
                    systemImage: "textformat.size",
                    tone: .accent,
                    value: Binding($fontSize),
                    range: minFontSize...maxFontSize,
                    step: 1
                ) { "\(Int($0))pt" }
                SettingsSeparator()
                SettingsPickerRow(
                    title: "Family",
                    systemImage: "textformat",
                    tone: .link,
                    selection: Binding($fontFamilyRaw)
                ) {
                    ForEach(CodeFontFamily.allCases) { family in
                        Text(family.displayName).tag(family.rawValue)
                    }
                }
            }

            SettingsSectionHeader(title: "Preview")
            SettingsGroup {
                previewRow
            }
        }
        .navigationTitle("Code Editor")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var previewRow: some View {
        Text("{{Front}}")
            .font(selectedFamily.font(size: fontSize))
            .foregroundStyle(palette.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AmgiSpacing.lg)
            .padding(.vertical, AmgiSpacing.md)
    }

    private var selectedFamily: CodeFontFamily {
        CodeFontFamily(rawValue: fontFamilyRaw) ?? .menlo
    }
}

/// Code-editor font family choices. Stored as `rawValue` under
/// `CodeEditorPreferences.Keys.fontFamily`. Resolves to a SwiftUI
/// `Font` via `font(_:)`.
enum CodeFontFamily: String, CaseIterable, Identifiable {
    case menlo = "Menlo"
    case courier = "Courier New"
    case monaco = "Monaco"
    case monospace = "Monospace"

    var id: String { rawValue }
    var displayName: String { rawValue }

    /// Returns a SwiftUI `Font` for the chosen family at the given size.
    /// `.monospace` maps to the system monospaced design (no specific
    /// face), the others use the named font with a monospaced fallback.
    func font(size: CGFloat) -> Font {
        switch self {
        case .monospace:
            return .system(size: size, design: .monospaced)
        case .menlo, .courier, .monaco:
            return .custom(rawValue, size: size)
        }
    }
}

#if DEBUG

#Preview {
    NavigationStack {
        CodeEditorSettingsView()
    }
}
#endif
