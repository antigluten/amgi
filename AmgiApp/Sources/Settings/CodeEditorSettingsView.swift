import SwiftUI
import AmgiTheme

/// Font + family preferences for the HTML/CSS source editor used inside
/// `TemplateEditorView` (and any future code-editor surface). Both keys
/// are plain `@AppStorage` strings so they survive across rebuilds and
/// are readable from any editor file without a Sharing dependency.
struct CodeEditorSettingsView: View {
    @AppStorage("codeEditor_fontSize") private var fontSize: Double = 14.0
    @AppStorage("codeEditor_fontFamily") private var fontFamilyRaw: String = CodeFontFamily.menlo.rawValue

    @Environment(\.palette) private var palette

    private let minFontSize: Double = 10
    private let maxFontSize: Double = 32

    var body: some View {
        Form {
            Section("Font") {
                fontSizeRow
                previewRow
                fontFamilyPicker
            }
        }
        .navigationTitle("Code Editor")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var fontSizeRow: some View {
        HStack(spacing: 12) {
            Label("Size", systemImage: "textformat.size")
            Spacer()
            Button {
                fontSize = max(minFontSize, fontSize - 1)
            } label: {
                Image(systemName: "minus")
                    .frame(width: 28, height: 28)
                    .background(palette.surfaceElevated)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(fontSize <= minFontSize)
            .accessibilityLabel("Decrease font size")

            Text("\(Int(fontSize))")
                .font(.system(.body, design: .monospaced).weight(.semibold))
                .frame(minWidth: 32, alignment: .center)
                .monospacedDigit()

            Button {
                fontSize = min(maxFontSize, fontSize + 1)
            } label: {
                Image(systemName: "plus")
                    .frame(width: 28, height: 28)
                    .background(palette.surfaceElevated)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(fontSize >= maxFontSize)
            .accessibilityLabel("Increase font size")
        }
    }

    private var previewRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Preview")
                .font(.caption)
                .foregroundStyle(palette.textSecondary)
            Text("{{Front}}")
                .font(.system(size: fontSize, design: .monospaced))
                .padding(8)
                .background(palette.surfaceElevated)
                .clipShape(.rect(cornerRadius: 4))
        }
        .padding(.vertical, 4)
    }

    private var fontFamilyPicker: some View {
        Picker("Family", selection: $fontFamilyRaw) {
            ForEach(CodeFontFamily.allCases) { family in
                Text(family.displayName)
                    .font(.system(size: fontSize, design: .monospaced))
                    .tag(family.rawValue)
            }
        }
    }
}

/// Code-editor font family choices. Stored as `rawValue` in
/// `@AppStorage("codeEditor_fontFamily")`. Resolves to a SwiftUI
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

#Preview {
    NavigationStack {
        CodeEditorSettingsView()
    }
}
