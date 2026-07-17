import AmgiReader
import AmgiReaderDictionary
import AnkiClients
import AnkiKit
import Dependencies
import Sharing
import SwiftUI

/// Sheet that renders dictionary lookup results for a query. First-pass
/// scope: plain-text glossaries, frequency strings, pitch positions, and
/// deinflection trace — no Yomitan structured-content rendering yet.
/// Calls `dictionaryLookupClient.lookup` directly; while the engine is a
/// stub it returns an empty placeholder and the view shows the empty
/// state.
struct LookupPopupView: View {
    let initialQuery: String
    /// BCP-47 / loose hint forwarded into entry rows for TTS voice
    /// selection (`book.language`). Nil falls back to script sniffing.
    var languageHint: String? = nil
    let onDismiss: () -> Void

    @Dependency(\.dictionaryLookupClient) var dictionary

    @State private var query: String = ""
    @State private var result: DictionaryLookupResult?
    @State private var isLoading = false
    @State private var lookupError: String?
    @State private var pendingNoteDraft: NoteDraft?

    /// JSON-encoded `ReaderLookupNoteTemplate` stored in user prefs.
    /// Default is `.empty`, which makes `makeDraft` fall back to common
    /// Basic-notetype field names so the user still gets a usable draft
    /// before configuring the template.
    @Shared(.appStorage("reader_pref_lookup_note_template"))
    private var serializedTemplate: String = ""

    /// User-configurable in `ReaderDictionarySettingsView`. Defaults
    /// match DreamAfar (16 / 16) — large scan windows can stall lookups
    /// on big libraries, so we don't go higher without the user asking.
    @Shared(.appStorage(ReaderPreferences.Keys.dictionaryScanLength))
    private var scanLength: Int = 16
    @Shared(.appStorage(ReaderPreferences.Keys.dictionaryMaxResults))
    private var maxResults: Int = 16

    @Shared(.appStorage(ReaderPreferences.Keys.popupAudioSourceTemplate))
    private var audioTemplate: String = ""
    @Shared(.appStorage(ReaderPreferences.Keys.popupAudioPlaybackMode))
    private var audioPlaybackModeRaw: String = LookupAudioPlaybackMode.interrupt.rawValue
    @Shared(.appStorage(ReaderPreferences.Keys.popupAudioAutoplay))
    private var audioAutoplay: Bool = false

    // Styling prefs — see ReaderSettingsView for the controls.
    @Shared(.appStorage(ReaderPreferences.Keys.popupHeight))
    private var popupHeight: Double = 60          // % of screen
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

    /// JSON-encoded `[String]` of recent queries, newest first. Capped at
    /// 20 entries to keep the suggestions list scannable; older queries
    /// fall off the end. Populated by `recordHistory` after a non-empty
    /// lookup; rendered via `.searchSuggestions` while the search field
    /// has focus.
    @Shared(.appStorage(ReaderPreferences.Keys.popupSearchHistory))
    private var serializedSearchHistory: String = "[]"

    /// JSON-encoded `[String]` of dictionary names the user has explicitly
    /// collapsed. Per-dict toggle state survives popup re-presentations
    /// and app restarts; the default-collapsed pref still controls the
    /// initial state for dictionaries not in this list.
    @Shared(.appStorage(ReaderPreferences.Keys.popupCollapsedDictionaries))
    private var serializedCollapsedDictionaries: String = "[]"

    @State private var autoplayedEntryID: String?
    /// Stack of follow-up queries the user pushed by tapping a word in
    /// a definition. The root popup shows the search field + initial
    /// query result; each entry on the path renders as a pushed
    /// `LookupChildPane`. Native nav back-swipe pops one level.
    @State private var lookupPath: [LookupPathEntry] = []

    var body: some View {
        NavigationStack(path: $lookupPath) {
            content
                .navigationTitle("Lookup")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { onDismiss() }
                    }
                }
                .searchable(text: $query, prompt: "Word or phrase")
                .searchSuggestions {
                    ForEach(searchHistory.prefix(8), id: \.self) { recent in
                        Text(recent)
                            .searchCompletion(recent)
                    }
                }
                .onSubmit(of: .search) {
                    Task { await runLookup() }
                }
                .task {
                    query = initialQuery
                    await runLookup()
                }
                .navigationDestination(for: LookupPathEntry.self) { pushed in
                    LookupChildPane(
                        query: pushed.query,
                        languageHint: languageHint,
                        styling: childStyling,
                        audioTemplate: audioTemplate,
                        audioPlaybackMode: LookupAudioDefaults.resolvedPlaybackMode(audioPlaybackModeRaw),
                        scanLength: scanLength,
                        maxResults: maxResults,
                        collapsedDictionaries: collapsedDictionaries,
                        onSetCollapsed: { dict, collapsed in
                            setCollapsed(dict, collapsed: collapsed)
                        },
                        onMakeNote: { entry in
                            pendingNoteDraft = NoteDraft(draft: makeNoteDraft(for: entry))
                        },
                        onPushLookup: { phrase in
                            lookupPath.append(LookupPathEntry(query: phrase))
                        }
                    )
                }
        }
        .presentationDetents(detents)
        .presentationDragIndicator(popupSwipeToDismiss ? .visible : .hidden)
    }

    /// Reused styling block for child panes — derived from the same
    /// styling prefs so the visual baseline matches the root.
    private var childStyling: LookupEntryStyling {
        LookupEntryStyling(
            termFontSize: popupFontSize + 3,
            readingFontSize: popupKanaFontSize,
            frequencyFontSize: popupFrequencyFontSize,
            dictionaryNameFontSize: popupDictionaryNameFontSize,
            contentFontSize: popupContentFontSize,
            collapseDictionaries: popupCollapseDictionaries,
            compactGlossaries: popupCompactGlossaries
        )
    }

    private var detents: Set<PresentationDetent> {
        if popupFullWidth { return [.large] }
        let fraction = max(0.2, min(popupHeight / 100.0, 0.95))
        return [.fraction(fraction), .large]
    }

    @ViewBuilder
    private var content: some View {
        if isLoading {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let lookupError {
            ContentUnavailableView {
                Label("Lookup failed", systemImage: "exclamationmark.triangle")
            } description: {
                Text(lookupError)
            } actions: {
                Button("Retry") { Task { await runLookup() } }
            }
        } else if let result, !result.entries.isEmpty {
            List {
                ForEach(result.entries) { entry in
                    LookupEntryView(
                        entry: entry,
                        dictionaryStyles: result.dictionaryStyles,
                        audioTemplate: audioTemplate,
                        audioPlaybackMode: LookupAudioDefaults.resolvedPlaybackMode(audioPlaybackModeRaw),
                        styling: LookupEntryStyling(
                            termFontSize: popupFontSize + 3,
                            readingFontSize: popupKanaFontSize,
                            frequencyFontSize: popupFrequencyFontSize,
                            dictionaryNameFontSize: popupDictionaryNameFontSize,
                            contentFontSize: popupContentFontSize,
                            collapseDictionaries: popupCollapseDictionaries,
                            compactGlossaries: popupCompactGlossaries
                        ),
                        collapsedDictionaries: collapsedDictionaries,
                        onSetCollapsed: { dict, collapsed in
                            setCollapsed(dict, collapsed: collapsed)
                        },
                        languageHint: languageHint,
                        onMakeNote: {
                            pendingNoteDraft = NoteDraft(draft: makeNoteDraft(for: entry))
                        },
                        onLookupRequested: { tappedText in
                            lookupPath.append(LookupPathEntry(query: tappedText))
                        }
                    )
                }
            }
            .onAppear {
                // Autoplay first entry once per query — never re-fire
                // when the popup re-renders for SwiftUI state changes.
                if audioAutoplay,
                   let first = result.entries.first,
                   autoplayedEntryID != first.id {
                    autoplayedEntryID = first.id
                    Task {
                        await playAudio(term: first.term, reading: first.reading)
                    }
                }
            }
            .listStyle(.plain)
            .sheet(item: $pendingNoteDraft) { wrapped in
                AddNoteView(initialDraft: wrapped.draft) {
                    pendingNoteDraft = nil
                }
            }
        } else if result?.isPlaceholder == true {
            ContentUnavailableView {
                Label("Engine not ready", systemImage: "hourglass")
            } description: {
                Text("Dictionary lookup engine is still a placeholder — full hoshidicts integration is pending.")
            }
        } else {
            ContentUnavailableView.search(text: query)
        }
    }

    private func playAudio(term: String, reading: String?) async {
        guard let url = await LookupAudioResolver.resolve(
            term: term,
            reading: reading,
            template: audioTemplate
        ) else { return }
        await LookupAudioPlayer.shared.play(
            url: url,
            mode: LookupAudioDefaults.resolvedPlaybackMode(audioPlaybackModeRaw)
        )
    }

    private func runLookup() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            result = nil
            return
        }
        isLoading = true
        lookupError = nil
        autoplayedEntryID = nil
        defer { isLoading = false }
        do {
            result = try await dictionary.lookup(trimmed, maxResults, scanLength)
            if let result, !result.entries.isEmpty {
                recordHistory(trimmed)
            }
        } catch {
            lookupError = error.localizedDescription
            result = nil
        }
    }

    // MARK: Search history persistence

    private var searchHistory: [String] {
        guard let data = serializedSearchHistory.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([String].self, from: data)
        else { return [] }
        return decoded
    }

    private func recordHistory(_ entry: String) {
        var history = searchHistory.filter { $0 != entry }
        history.insert(entry, at: 0)
        if history.count > 20 { history = Array(history.prefix(20)) }
        guard let data = try? JSONEncoder().encode(history),
              let json = String(data: data, encoding: .utf8) else { return }
        $serializedSearchHistory.withLock { $0 = json }
    }

    // MARK: Per-dictionary collapsed-state persistence

    private var collapsedDictionaries: Set<String> {
        guard let data = serializedCollapsedDictionaries.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([String].self, from: data)
        else { return [] }
        return Set(decoded)
    }

    private func setCollapsed(_ dictionary: String, collapsed: Bool) {
        var current = collapsedDictionaries
        if collapsed { current.insert(dictionary) } else { current.remove(dictionary) }
        guard let data = try? JSONEncoder().encode(Array(current).sorted()),
              let json = String(data: data, encoding: .utf8) else { return }
        $serializedCollapsedDictionaries.withLock { $0 = json }
    }

    /// Builds an `AddNoteDraft` for an entry by projecting the lookup
    /// payload through the user's saved `ReaderLookupNoteTemplate`. When
    /// the template hasn't been configured the projection falls back to
    /// common Basic-notetype field names so the user still gets a
    /// usable draft.
    private func makeNoteDraft(for entry: DictionaryLookupEntry) -> AddNoteDraft {
        let template: ReaderLookupNoteTemplate = serializedTemplate.isEmpty
            ? .empty
            : ReaderLookupNoteTemplate.decode(from: serializedTemplate)

        let payload = ReaderLookupNotePayload(
            term: entry.term,
            reading: entry.reading,
            sentence: nil,
            definitions: entry.glossaries.isEmpty
                ? ReaderLookupNotePayload.definitionsByDictionary(from: entry.structuredGlossaries)
                : entry.glossaries,
            dictionaries: entry.structuredGlossaries
                .map(\.dictionary)
                .filter { !$0.isEmpty }
                .joined(separator: ", ")
                .nilIfBlank,
            frequency: entry.frequency,
            pitch: entry.pitch,
            deinflection: entry.deinflectionTrace.map(\.name).joined(separator: " → ").nilIfBlank,
            matched: entry.matched,
            source: entry.source,
            rules: entry.rules.joined(separator: ", ").nilIfBlank
        )

        return template.makeDraft(
            payload: payload,
            fallbackDeckID: nil,
            sourceDescription: "Reader lookup"
        )
    }
}

private struct NoteDraft: Identifiable {
    let id = UUID()
    let draft: AddNoteDraft
}

/// One entry in the popup's chained-lookup stack. UUID + query so two
/// pushes of the same word are still distinct in the navigation path
/// (Hashable identity).
struct LookupPathEntry: Hashable {
    let id = UUID()
    let query: String
}

/// Pushed view shown for follow-up lookups when the user taps a word
/// inside a definition. Owns its own lookup state so the root popup's
/// query stays intact — back-swipe restores it visually.
private struct LookupChildPane: View {
    let query: String
    let languageHint: String?
    let styling: LookupEntryStyling
    let audioTemplate: String
    let audioPlaybackMode: LookupAudioPlaybackMode
    let scanLength: Int
    let maxResults: Int
    let collapsedDictionaries: Set<String>
    let onSetCollapsed: (String, Bool) -> Void
    let onMakeNote: (DictionaryLookupEntry) -> Void
    let onPushLookup: (String) -> Void

    @Dependency(\.dictionaryLookupClient) private var dictionary
    @State private var result: DictionaryLookupResult?
    @State private var isLoading = false
    @State private var lookupError: String?

    var body: some View {
        Group {
            if isLoading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let lookupError {
                ContentUnavailableView {
                    Label("Lookup failed", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(lookupError)
                }
            } else if let result, !result.entries.isEmpty {
                List {
                    ForEach(result.entries) { entry in
                        LookupEntryView(
                            entry: entry,
                            dictionaryStyles: result.dictionaryStyles,
                            audioTemplate: audioTemplate,
                            audioPlaybackMode: audioPlaybackMode,
                            styling: styling,
                            collapsedDictionaries: collapsedDictionaries,
                            onSetCollapsed: onSetCollapsed,
                            languageHint: languageHint,
                            onMakeNote: { onMakeNote(entry) },
                            onLookupRequested: onPushLookup
                        )
                    }
                }
                .listStyle(.plain)
            } else {
                ContentUnavailableView.search(text: query)
            }
        }
        .navigationTitle(query)
        .navigationBarTitleDisplayMode(.inline)
        .task { await runLookup() }
    }

    private func runLookup() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            result = try await dictionary.lookup(trimmed, maxResults, scanLength)
        } catch {
            lookupError = error.localizedDescription
            result = nil
        }
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

struct LookupEntryStyling {
    var termFontSize: Double = 20
    var readingFontSize: Double = 15
    var frequencyFontSize: Double = 12
    var dictionaryNameFontSize: Double = 11
    var contentFontSize: Double = 17
    var collapseDictionaries: Bool = false
    var compactGlossaries: Bool = false
}

private struct LookupEntryView: View {
    let entry: DictionaryLookupEntry
    let dictionaryStyles: [String: String]
    let audioTemplate: String
    let audioPlaybackMode: LookupAudioPlaybackMode
    let styling: LookupEntryStyling
    /// Names of dictionaries the user has explicitly collapsed. The
    /// initial collapsed/expanded state for any given dictionary is the
    /// union of `styling.collapseDictionaries` (the default-collapsed
    /// pref) and membership in this set.
    let collapsedDictionaries: Set<String>
    let onSetCollapsed: (String, Bool) -> Void
    let languageHint: String?
    let onMakeNote: () -> Void
    let onLookupRequested: ((String) -> Void)?

    @State private var isResolvingAudio = false

    var body: some View {
        VStack(alignment: .leading, spacing: styling.compactGlossaries ? 2 : 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(entry.term)
                    .font(.system(size: styling.termFontSize, weight: .bold))
                if let reading = entry.reading, !reading.isEmpty, reading != entry.term {
                    Text(reading)
                        .font(.system(size: styling.readingFontSize))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let frequency = entry.frequency, !frequency.isEmpty {
                    Text(frequency)
                        .font(.system(size: styling.frequencyFontSize))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.15), in: Capsule())
                }
                Button {
                    Task { await playAudio() }
                } label: {
                    if isResolvingAudio {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "speaker.wave.2.fill").font(.title3)
                    }
                }
                .buttonStyle(.plain)
                .disabled(isResolvingAudio)
                .accessibilityLabel("Play pronunciation")
                Button {
                    ReaderTTS.shared.speak(entry.term, languageHint: languageHint)
                } label: {
                    Image(systemName: "waveform.badge.mic").font(.title3)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Speak with TTS")
                Button {
                    onMakeNote()
                } label: {
                    Image(systemName: "plus.circle")
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Make note from this entry")
            }

            if !entry.deinflectionTrace.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.triangle.2.circlepath").font(.caption2)
                    Text(entry.deinflectionTrace.map(\.name).joined(separator: " → "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            if let pitch = entry.pitch, !pitch.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "waveform").font(.caption2)
                    Text(pitch).font(.caption).foregroundStyle(.secondary)
                }
            }

            // Structured glossaries get rendered by the bundled Yomitan
            // popup.js inside a WKWebView so we get rich formatting:
            // ordered lists, nested tables, links, pitch diagrams, and
            // dictionary-bundled images. Group by dictionary so each
            // dictionary's CSS is scoped to its own entries.
            if !entry.structuredGlossaries.isEmpty {
                ForEach(groupedStructured, id: \.dictionary) { group in
                    structuredGroup(group)
                }
            } else {
                // Plain-text fallback for entries that ship no structured
                // content (rare — frequency/pitch-only dicts, or older
                // term dicts that store flat strings).
                ForEach(Array(entry.glossaries.enumerated()), id: \.offset) { _, gloss in
                    Text(gloss).font(.system(size: styling.contentFontSize))
                }
            }
        }
        .padding(.vertical, styling.compactGlossaries ? 1 : 4)
    }

    @ViewBuilder
    private func structuredGroup(_ group: StructuredGroup) -> some View {
        let inner = LookupStructuredContentView(
            dictionary: group.dictionary,
            glossaries: group.glossaries,
            dictionaryStyle: dictionaryStyles[group.dictionary] ?? "",
            onLookupRequested: onLookupRequested
        )
        .frame(maxWidth: .infinity, minHeight: 40)

        // Per-dictionary collapsed state: an explicit toggle in
        // `collapsedDictionaries` overrides the default. When neither
        // collapse-by-default nor explicit collapse is set, we render
        // a flat VStack instead of a DisclosureGroup so the section is
        // visible without an extra tap.
        let isExplicitlyCollapsed = collapsedDictionaries.contains(group.dictionary)
        let shouldShowDisclosure = styling.collapseDictionaries || isExplicitlyCollapsed
        if shouldShowDisclosure {
            DisclosureGroup(
                isExpanded: Binding(
                    get: { !isExplicitlyCollapsed },
                    set: { expanded in onSetCollapsed(group.dictionary, !expanded) }
                )
            ) {
                inner
            } label: {
                Text(group.dictionary.isEmpty ? "Definitions" : group.dictionary)
                    .font(.system(size: styling.dictionaryNameFontSize))
                    .foregroundStyle(.secondary)
            }
        } else {
            VStack(alignment: .leading, spacing: styling.compactGlossaries ? 1 : 4) {
                if !group.dictionary.isEmpty {
                    Text(group.dictionary)
                        .font(.system(size: styling.dictionaryNameFontSize))
                        .foregroundStyle(.secondary)
                }
                inner
            }
        }
    }

    private func playAudio() async {
        isResolvingAudio = true
        defer { isResolvingAudio = false }
        guard let url = await LookupAudioResolver.resolve(
            term: entry.term,
            reading: entry.reading,
            template: audioTemplate
        ) else { return }
        await LookupAudioPlayer.shared.play(url: url, mode: audioPlaybackMode)
    }

    private struct StructuredGroup {
        let dictionary: String
        let glossaries: [DictionaryLookupGlossary]
    }

    private var groupedStructured: [StructuredGroup] {
        var order: [String] = []
        var bucket: [String: [DictionaryLookupGlossary]] = [:]
        for g in entry.structuredGlossaries {
            if bucket[g.dictionary] == nil { order.append(g.dictionary) }
            bucket[g.dictionary, default: []].append(g)
        }
        return order.map { StructuredGroup(dictionary: $0, glossaries: bucket[$0] ?? []) }
    }
}
