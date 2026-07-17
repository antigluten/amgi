import AmgiReader
import AmgiReaderDictionary
import AmgiTheme
import Dependencies
import Sharing
import SwiftUI
import UniformTypeIdentifiers

/// Dictionary library management surface. Lists term / frequency / pitch
/// dictionaries from `dictionaryLookupClient.loadState()`, lets the user
/// import Yomitan-format ZIP archives, toggle enabled-state, or delete.
///
/// While the lookup engine is still a stub, every action no-ops and the
/// list stays empty. The shape here is what the engine plugs into; no
/// view-side changes needed when the real runtime ports.
struct ReaderDictionarySettingsView: View {
    @State private var model = ReaderDictionarySettingsModel()

    @Shared(.appStorage(ReaderPreferences.Keys.dictionaryMaxResults))
    private var maxResults: Int = 16
    @Shared(.appStorage(ReaderPreferences.Keys.dictionaryScanLength))
    private var scanLength: Int = 16

    @Shared(.appStorage(ReaderPreferences.Keys.popupAudioSourceTemplate))
    private var audioTemplate: String = ""
    @Shared(.appStorage(ReaderPreferences.Keys.popupAudioPlaybackMode))
    private var audioPlaybackModeRaw: String = LookupAudioPlaybackMode.interrupt.rawValue
    @Shared(.appStorage(ReaderPreferences.Keys.popupAudioAutoplay))
    private var audioAutoplay: Bool = false

    @State private var showImporter = false

    @Environment(\.palette) private var palette

    private static let zipType = UTType(filenameExtension: "zip") ?? .data

    var body: some View {
        Form {
            Section("Lookup behavior") {
                Stepper("Max results: \(maxResults)", value: Binding($maxResults), in: 1...50)
                Stepper("Scan length: \(scanLength)", value: Binding($scanLength), in: 4...64)
            }

            Section {
                Toggle("Autoplay audio", isOn: Binding($audioAutoplay))
                Picker("Playback mode", selection: Binding($audioPlaybackModeRaw)) {
                    ForEach(LookupAudioPlaybackMode.allCases) { mode in
                        Text(mode.label).tag(mode.rawValue)
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Source URL template").amgiFont(.caption).foregroundStyle(palette.textSecondary)
                    TextField(
                        LookupAudioDefaults.defaultTemplate,
                        text: Binding($audioTemplate),
                        axis: .vertical
                    )
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .lineLimit(1...3)
                    .font(.system(.footnote, design: .monospaced))
                }
            } header: {
                Text("Audio")
            } footer: {
                Text("Use {term} and {reading} placeholders. Endpoint must return Yomichan-style audioSourceList JSON.")
            }

            Section {
                Picker("Type", selection: $model.selectedKind) {
                    Text("Term").tag(AppDictionaryKind.term)
                    Text("Frequency").tag(AppDictionaryKind.frequency)
                    Text("Pitch").tag(AppDictionaryKind.pitch)
                }
                .pickerStyle(.segmented)
            }

            Section {
                if model.dictionaries.isEmpty {
                    Text("No \(model.selectedKind.label) dictionaries imported yet.")
                        .foregroundStyle(palette.textSecondary)
                } else {
                    ForEach(model.dictionaries) { dict in
                        DictionaryRow(
                            info: dict,
                            isBusy: model.isBusy,
                            onToggle: { Task { await model.toggle(dict) } },
                            onDelete: { Task { await model.delete(dict) } }
                        )
                    }
                    .onMove { source, destination in
                        Task { await model.move(from: source, to: destination) }
                    }
                }

                Button {
                    showImporter = true
                } label: {
                    Label("Import \(model.selectedKind.label) archive…", systemImage: "square.and.arrow.down")
                }
                .disabled(model.isBusy)

                Button {
                    Task { await model.refresh() }
                } label: {
                    Label("Reload library", systemImage: "arrow.clockwise")
                }
                .disabled(model.isBusy)
            } header: {
                Text("Library")
            } footer: {
                Text("Import Yomitan-format dictionary ZIP archives. Reordering and update-on-version-change land when the lookup engine is fully wired.")
            }

            if model.isBusy {
                Section {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text("Working…")
                    }
                }
            }
        }
        .navigationTitle("Dictionaries")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
            }
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [Self.zipType],
            allowsMultipleSelection: true
        ) { result in
            model.handleImport(result)
        }
        .alert(
            "Dictionary",
            isPresented: Binding(
                get: { model.actionError != nil },
                set: { if !$0 { model.actionError = nil } }
            ),
            presenting: model.actionError
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { Text($0) }
        .task { await model.refresh() }
    }
}

private struct DictionaryRow: View {
    let info: AppDictionaryInfo
    let isBusy: Bool
    let onToggle: () -> Void
    let onDelete: () -> Void

    @Environment(\.palette) private var palette

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(info.title).amgiFont(.body)
                if !info.index.revision.isEmpty {
                    Text("rev \(info.index.revision)")
                        .amgiFont(.caption)
                        .foregroundStyle(palette.textSecondary)
                }
            }
            Spacer()
            Toggle("", isOn: Binding(get: { info.isEnabled }, set: { _ in onToggle() }))
                .labelsHidden()
                .disabled(isBusy)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
            .disabled(isBusy)
        }
    }
}

private extension AppDictionaryKind {
    var label: String {
        switch self {
        case .term: return "term"
        case .frequency: return "frequency"
        case .pitch: return "pitch"
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    // Seed the library so the term-dictionary list renders populated; the
    // lookup-behavior and audio rows fall back to their appStorage defaults.
    let _ = prepareDependencies {
        $0.dictionaryLookupClient.loadState = {
            AppDictionaryLibraryState(
                termDictionaries: [
                    AppDictionaryInfo(
                        fileName: "jmdict.zip",
                        index: AppDictionaryIndex(title: "JMdict", revision: "2025-06-01"),
                        isEnabled: true
                    ),
                    AppDictionaryInfo(
                        fileName: "daijirin.zip",
                        index: AppDictionaryIndex(title: "大辞林", revision: "3.0"),
                        isEnabled: false
                    ),
                ]
            )
        }
    }
    return NavigationStack {
        ReaderDictionarySettingsView()
    }
}
#endif
