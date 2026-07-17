import AmgiTheme
import Sharing
import SwiftUI

/// Apple Books-style typography sheet. Surfaced from the `Aa` button in
/// `EPUBChapterReaderView`'s top chrome. Edits land in `@Shared(.appStorage)`
/// so the chapter VC's `styleTokens` recomputation fires immediately.
struct ReaderTypographySettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette

    @Shared(.appStorage(ReaderTypographyPreferences.Keys.fontFamily))
    private var fontFamilyRaw: String = ReaderTypographyPreferences.FontFamily.system.rawValue
    @Shared(.appStorage(ReaderTypographyPreferences.Keys.fontSize))
    private var fontSize: Int = 17
    @Shared(.appStorage(ReaderTypographyPreferences.Keys.lineHeight))
    private var lineHeight: Double = 1.55
    @Shared(.appStorage(ReaderTypographyPreferences.Keys.pageMargin))
    private var pageMarginRaw: String = ReaderTypographyPreferences.PageMargin.defaultMargin.rawValue
    @Shared(.appStorage(ReaderTypographyPreferences.Keys.theme))
    private var themeRaw: String = ReaderTypographyPreferences.Theme.default.rawValue
    @Shared(.appStorage(ReaderTypographyPreferences.Keys.justify))
    private var justify: Bool = true

    var body: some View {
        NavigationStack {
            Form {
                themeSection
                fontSizeSection
                fontFamilySection
                lineHeightSection
                pageMarginSection
                justifySection
            }
            .navigationTitle("Reading Style")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { doneButton }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Sections

    private var themeSection: some View {
        Section {
            HStack(spacing: 18) {
                ForEach(ReaderTypographyPreferences.Theme.allCases) { option in
                    ThemeSwatchButton(
                        theme: option,
                        isSelected: themeRaw == option.rawValue,
                        action: { $themeRaw.withLock { $0 = option.rawValue } }
                    )
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
        }
    }

    private var fontSizeSection: some View {
        Section {
            HStack {
                Button { decreaseFontSize() } label: {
                    Image(systemName: "textformat.size.smaller")
                        .font(.title3)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(fontSize <= 12)

                Text("\(fontSize) pt")
                    .font(.body.monospacedDigit())
                    .frame(width: 64)

                Button { increaseFontSize() } label: {
                    Image(systemName: "textformat.size.larger")
                        .font(.title3)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(fontSize >= 28)
            }
        } header: {
            Label("Font Size", systemImage: "textformat.size")
        }
    }

    private var fontFamilySection: some View {
        Section {
            Picker("Font", selection: fontFamilyBinding) {
                ForEach(ReaderTypographyPreferences.FontFamily.allCases) { option in
                    Text(option.label).tag(option)
                }
            }
            .pickerStyle(.segmented)
        } header: {
            Label("Font", systemImage: "textformat")
        }
    }

    private var lineHeightSection: some View {
        Section {
            Stepper(value: lineHeightBinding, in: 1.2...2.0, step: 0.1) {
                HStack {
                    Text("Line Height")
                    Spacer()
                    Text(String(format: "%.1f", lineHeight))
                        .font(.body.monospacedDigit())
                        .foregroundStyle(palette.textSecondary)
                }
            }
        } header: {
            Label("Spacing", systemImage: "arrow.up.and.down.text.horizontal")
        }
    }

    private var pageMarginSection: some View {
        Section {
            Picker("Margins", selection: pageMarginBinding) {
                ForEach(ReaderTypographyPreferences.PageMargin.allCases) { option in
                    Text(option.label).tag(option)
                }
            }
            .pickerStyle(.segmented)
        } header: {
            Label("Margins", systemImage: "rectangle.compress.vertical")
        }
    }

    private var justifySection: some View {
        Section {
            Toggle(isOn: justifyBinding) {
                Label("Justify Text", systemImage: "text.justify")
            }
        }
    }

    private var doneButton: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button("Done") { dismiss() }
                .fontWeight(.semibold)
        }
    }

    // MARK: - Bindings

    private var fontFamilyBinding: Binding<ReaderTypographyPreferences.FontFamily> {
        Binding(
            get: { ReaderTypographyPreferences.FontFamily(rawValue: fontFamilyRaw) ?? .system },
            set: { value in $fontFamilyRaw.withLock { $0 = value.rawValue } }
        )
    }

    private var pageMarginBinding: Binding<ReaderTypographyPreferences.PageMargin> {
        Binding(
            get: { ReaderTypographyPreferences.PageMargin(rawValue: pageMarginRaw) ?? .defaultMargin },
            set: { value in $pageMarginRaw.withLock { $0 = value.rawValue } }
        )
    }

    private var lineHeightBinding: Binding<Double> {
        Binding(
            get: { lineHeight },
            set: { value in $lineHeight.withLock { $0 = value } }
        )
    }

    private var justifyBinding: Binding<Bool> {
        Binding(
            get: { justify },
            set: { value in $justify.withLock { $0 = value } }
        )
    }
}

/// Single theme swatch button — a coloured circle with checkmark when
/// active, labelled below. Three of these sit in a horizontal row at the
/// top of the sheet, matching Apple Books' theme picker.
private struct ThemeSwatchButton: View {
    let theme: ReaderTypographyPreferences.Theme
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.palette) private var palette

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                swatch
                Text(theme.label)
                    .amgiFont(.caption)
                    .foregroundStyle(palette.textPrimary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(theme.label))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private var swatch: some View {
        ZStack {
            Circle()
                .fill(theme.backgroundColor)
                .frame(width: 44, height: 44)
                .overlay(
                    Circle().strokeBorder(
                        isSelected ? palette.accent : palette.textSecondary.opacity(0.3),
                        lineWidth: isSelected ? 2 : 1
                    )
                )
            Text("Aa")
                .font(.callout.weight(.semibold))
                .foregroundStyle(Color(hex: theme.foregroundHex) ?? palette.textPrimary)
        }
    }
}

private extension ReaderTypographySettingsView {
    func decreaseFontSize() {
        $fontSize.withLock { $0 = max(12, $0 - 1) }
    }

    func increaseFontSize() {
        $fontSize.withLock { $0 = min(28, $0 + 1) }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack { ReaderTypographySettingsView() }
}
