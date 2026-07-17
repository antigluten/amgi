import AmgiReader
import AmgiReaderDictionary
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
    @Dependency(\.dictionaryLookupClient) var dictionary

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

    @State private var libraryState: AppDictionaryLibraryState = .empty
    @State private var selectedKind: AppDictionaryKind = .term
    @State private var isBusy = false
    @State private var showImporter = false
    @State private var actionError: String?

    private static let zipType = UTType(filenameExtension: "zip") ?? .data

    private var dictionaries: [AppDictionaryInfo] {
        switch selectedKind {
        case .term: return libraryState.termDictionaries
        case .frequency: return libraryState.frequencyDictionaries
        case .pitch: return libraryState.pitchDictionaries
        }
    }

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
                    Text("Source URL template").font(.caption).foregroundStyle(.secondary)
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
                Picker("Type", selection: $selectedKind) {
                    Text("Term").tag(AppDictionaryKind.term)
                    Text("Frequency").tag(AppDictionaryKind.frequency)
                    Text("Pitch").tag(AppDictionaryKind.pitch)
                }
                .pickerStyle(.segmented)
            }

            Section {
                if dictionaries.isEmpty {
                    Text("No \(selectedKind.label) dictionaries imported yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(dictionaries) { dict in
                        DictionaryRow(
                            info: dict,
                            isBusy: isBusy,
                            onToggle: { Task { await toggle(dict) } },
                            onDelete: { Task { await delete(dict) } }
                        )
                    }
                    .onMove { source, destination in
                        Task { await move(from: source, to: destination) }
                    }
                }

                Button {
                    showImporter = true
                } label: {
                    Label("Import \(selectedKind.label) archive…", systemImage: "square.and.arrow.down")
                }
                .disabled(isBusy)

                Button {
                    Task { await refresh() }
                } label: {
                    Label("Reload library", systemImage: "arrow.clockwise")
                }
                .disabled(isBusy)
            } header: {
                Text("Library")
            } footer: {
                Text("Import Yomitan-format dictionary ZIP archives. Reordering and update-on-version-change land when the lookup engine is fully wired.")
            }

            if isBusy {
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
            handleImport(result)
        }
        .alert(
            "Dictionary",
            isPresented: Binding(
                get: { actionError != nil },
                set: { if !$0 { actionError = nil } }
            ),
            presenting: actionError
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { Text($0) }
        .task { await refresh() }
    }

    // MARK: - Actions

    private func refresh() async {
        do {
            libraryState = try await dictionary.loadState()
        } catch {
            actionError = "Failed to load library: \(error.localizedDescription)"
        }
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            Task { await importArchives(urls) }
        case .failure(let error):
            actionError = "Could not select files: \(error.localizedDescription)"
        }
    }

    private func importArchives(_ urls: [URL]) async {
        isBusy = true
        defer { isBusy = false }
        do {
            // The engine takes the URLs and copies/extracts as needed —
            // host-side security-scoped resource access is its concern,
            // mirroring how DreamAfar's importer drives FileManager.
            libraryState = try await dictionary.importArchives(urls, selectedKind)
        } catch {
            actionError = "Import failed: \(error.localizedDescription)"
        }
    }

    private func toggle(_ info: AppDictionaryInfo) async {
        isBusy = true
        defer { isBusy = false }
        do {
            libraryState = try await dictionary.setEnabled(selectedKind, info.id, !info.isEnabled)
        } catch {
            actionError = "Failed to update: \(error.localizedDescription)"
        }
    }

    private func delete(_ info: AppDictionaryInfo) async {
        isBusy = true
        defer { isBusy = false }
        do {
            libraryState = try await dictionary.delete(selectedKind, info.id)
        } catch {
            actionError = "Failed to delete: \(error.localizedDescription)"
        }
    }

    private func move(from source: IndexSet, to destination: Int) async {
        var ids = dictionaries.map(\.id)
        ids.move(fromOffsets: source, toOffset: destination)
        isBusy = true
        defer { isBusy = false }
        do {
            libraryState = try await dictionary.reorder(selectedKind, ids)
        } catch {
            actionError = "Failed to reorder: \(error.localizedDescription)"
        }
    }
}

private struct DictionaryRow: View {
    let info: AppDictionaryInfo
    let isBusy: Bool
    let onToggle: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(info.title).font(.body)
                if !info.index.revision.isEmpty {
                    Text("rev \(info.index.revision)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
