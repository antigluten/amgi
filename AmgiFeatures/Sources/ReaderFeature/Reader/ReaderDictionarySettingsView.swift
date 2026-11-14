//
//  ReaderDictionarySettingsView.swift
//  ReaderFeature
//
//  Created by Vladimir Gusev on 05.05.2026.
//

import Reader
import ReaderDictionary
import Theme
import AppCore
import Dependencies
import Sharing
package import SwiftUI
import UniformTypeIdentifiers

/// Dictionary library management surface. Lists term / frequency / pitch
/// dictionaries from `dictionaryLookupClient.loadState()`, lets the user
/// import Yomitan-format ZIP archives, toggle enabled-state, or delete.
///
/// While the lookup engine is still a stub, every action no-ops and the
/// list stays empty. The shape here is what the engine plugs into; no
/// view-side changes needed when the real runtime ports.
package struct ReaderDictionarySettingsView: View {
    package init() {}

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

    private var libraryFooter: String {
        let base = String(localized: "Import Yomitan-format dictionary ZIP archives. Reordering and update-on-version-change land when the lookup engine is fully wired.", bundle: .module)
        guard model.lacksFrequencyDictionary else { return base }
        return base + String(localized: " Add a frequency dictionary to sort common words first.", bundle: .module)
    }

    package var body: some View {
        Form {
            Section(String(localized: "Lookup behavior", bundle: .module)) {
                Stepper(String(localized: "Max results: \(maxResults)", bundle: .module), value: Binding($maxResults), in: 1...50)
                Stepper(String(localized: "Scan length: \(scanLength)", bundle: .module), value: Binding($scanLength), in: 4...64)
            }

            Section {
                Toggle(String(localized: "Autoplay audio", bundle: .module), isOn: Binding($audioAutoplay))
                Picker(String(localized: "Playback mode", bundle: .module), selection: Binding($audioPlaybackModeRaw)) {
                    ForEach(LookupAudioPlaybackMode.allCases) { mode in
                        Text(mode.label).tag(mode.rawValue)
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Source URL template", bundle: .module).amgiFont(.caption).foregroundStyle(palette.textSecondary)
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
                Text("Audio", bundle: .module)
            } footer: {
                Text("Use {term} and {reading} placeholders. Endpoint must return Yomichan-style audioSourceList JSON.", bundle: .module)
            }

            Section {
                Picker(String(localized: "Type", bundle: .module), selection: $model.selectedKind) {
                    Text("Term", bundle: .module).tag(AppDictionaryKind.term)
                    Text("Frequency", bundle: .module).tag(AppDictionaryKind.frequency)
                    Text("Pitch", bundle: .module).tag(AppDictionaryKind.pitch)
                }
                .pickerStyle(.segmented)
            }

            Section {
                if model.dictionaries.isEmpty {
                    Text("No \(model.selectedKind.label) dictionaries imported yet.", bundle: .module)
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
                    Label(String(localized: "Import \(model.selectedKind.label) archive…", bundle: .module), systemImage: "square.and.arrow.down")
                }
                .disabled(model.isBusy)

                Button {
                    Task { await model.refresh() }
                } label: {
                    Label(String(localized: "Reload library", bundle: .module), systemImage: "arrow.clockwise")
                }
                .disabled(model.isBusy)
            } header: {
                Text("Library", bundle: .module)
            } footer: {
                Text(libraryFooter)
            }

            if model.isBusy {
                Section {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text("Working…", bundle: .module)
                    }
                }
            }
        }
        .navigationTitle(String(localized: "Dictionaries", bundle: .module))
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
            String(localized: "Dictionary", bundle: .module),
            isPresented: Binding(
                get: { model.actionError != nil },
                set: { if !$0 { model.actionError = nil } }
            ),
            presenting: model.actionError
        ) { _ in
            Button(String(localized: "OK", bundle: .module), role: .cancel) {}
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
                    Text("rev \(info.index.revision)", bundle: .module)
                        .amgiFont(.caption)
                        .foregroundStyle(palette.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Toggle("", isOn: Binding(get: { info.isEnabled }, set: { _ in onToggle() }))
                .labelsHidden()
                .disabled(isBusy)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label(String(localized: "Delete", bundle: .module), systemImage: "trash")
            }
            .disabled(isBusy)
        }
    }
}

private extension AppDictionaryKind {
    var label: String {
        switch self {
        case .term: return String(localized: "term", bundle: .module)
        case .frequency: return String(localized: "frequency", bundle: .module)
        case .pitch: return String(localized: "pitch", bundle: .module)
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
