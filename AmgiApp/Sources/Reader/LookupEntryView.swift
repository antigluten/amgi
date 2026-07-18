import AmgiReader
import AmgiTheme
import SwiftUI

/// Font sizes + layout toggles shared by every dictionary-entry view in
/// the lookup popup (root list, child panes, and previews). Defaults match
/// the popup's shipping baseline so a bare `LookupEntryStyling()` renders
/// like production.
struct LookupEntryStyling {
    var termFontSize: Double = 20
    var readingFontSize: Double = 15
    var frequencyFontSize: Double = 12
    var dictionaryNameFontSize: Double = 11
    var contentFontSize: Double = 17
    var collapseDictionaries: Bool = false
    var compactGlossaries: Bool = false
}

/// Term / reading / frequency badge plus the audio, TTS, and add-note
/// action buttons. Owns its own audio-resolving state so the row above it
/// stays stateless and the header can be previewed and reused on its own.
struct LookupEntryHeaderView: View {
    let term: String
    let reading: String?
    let frequency: String?
    let styling: LookupEntryStyling
    let audioTemplate: String
    let audioPlaybackMode: LookupAudioPlaybackMode
    let languageHint: String?
    let onMakeNote: () -> Void

    @State private var isResolvingAudio = false
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(term)
                .font(.system(size: styling.termFontSize, weight: .bold))
            if let reading, !reading.isEmpty, reading != term {
                Text(reading)
                    .font(.system(size: styling.readingFontSize))
                    .foregroundStyle(palette.textSecondary)
            }
            Spacer()
            if let frequency, !frequency.isEmpty {
                Text(frequency)
                    .font(.system(size: styling.frequencyFontSize))
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(palette.separator, in: Capsule())
            }
            Button {
                Task { await playAudio() }
            } label: {
                if isResolvingAudio {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: "speaker.wave.2.fill").amgiFont(.cardTitle)
                }
            }
            .buttonStyle(.plain)
            .disabled(isResolvingAudio)
            .accessibilityLabel("Play pronunciation")
            Button {
                ReaderTTS.shared.speak(term, languageHint: languageHint)
            } label: {
                Image(systemName: "waveform.badge.mic").amgiFont(.cardTitle)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Speak with TTS")
            Button {
                onMakeNote()
            } label: {
                Image(systemName: "plus.circle")
                    .amgiFont(.cardTitle)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Make note from this entry")
        }
    }

}

private extension LookupEntryHeaderView {
    func playAudio() async {
        isResolvingAudio = true
        defer { isResolvingAudio = false }
        guard let url = await LookupAudioResolver.resolve(
            term: term,
            reading: reading,
            template: audioTemplate
        ) else { return }
        await LookupAudioPlayer.shared.play(url: url, mode: audioPlaybackMode)
    }
}

/// A single dictionary-lookup entry: header row, deinflection trace, pitch,
/// then either Yomitan structured glossaries (one disclosure/section per
/// dictionary) or a plain-text fallback. Driven entirely by its inputs so
/// it can be reused by the root popup, child panes, and previews.
struct LookupEntryView: View {
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

    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: styling.compactGlossaries ? 2 : 6) {
            LookupEntryHeaderView(
                term: entry.term,
                reading: entry.reading,
                frequency: entry.frequency,
                styling: styling,
                audioTemplate: audioTemplate,
                audioPlaybackMode: audioPlaybackMode,
                languageHint: languageHint,
                onMakeNote: onMakeNote
            )

            if !entry.deinflectionTrace.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.triangle.2.circlepath").amgiFont(.micro)
                    Text(entry.deinflectionTrace.map(\.name).joined(separator: " → "))
                        .amgiFont(.caption)
                        .foregroundStyle(palette.textSecondary)
                        .lineLimit(1)
                }
            }

            if let pitch = entry.pitch, !pitch.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "waveform").amgiFont(.micro)
                    Text(pitch).amgiFont(.caption).foregroundStyle(palette.textSecondary)
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

private extension LookupEntryView {
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
                    .foregroundStyle(palette.textSecondary)
            }
        } else {
            VStack(alignment: .leading, spacing: styling.compactGlossaries ? 1 : 4) {
                if !group.dictionary.isEmpty {
                    Text(group.dictionary)
                        .font(.system(size: styling.dictionaryNameFontSize))
                        .foregroundStyle(palette.textSecondary)
                }
                inner
            }
        }
    }
}

// MARK: - Previews

/// Plain-glossary mock entry — renders the header + deinflection + pitch +
/// text fallback path, so previews stay self-contained (no WKWebView,
/// no dictionaryLookupClient dependency).
private func previewEntry(
    term: String = "勉強",
    reading: String? = "べんきょう",
    frequency: String? = "1023",
    pitch: String? = "[0]"
) -> DictionaryLookupEntry {
    DictionaryLookupEntry(
        term: term,
        reading: reading,
        deinflectionTrace: [
            .init(name: "勉強する"),
            .init(name: "勉強"),
        ],
        glossaries: ["study; diligence", "discount (in price)"],
        frequency: frequency,
        pitch: pitch
    )
}

#Preview("Entry — normal") {
    List {
        LookupEntryView(
            entry: previewEntry(),
            dictionaryStyles: [:],
            audioTemplate: "",
            audioPlaybackMode: .interrupt,
            styling: LookupEntryStyling(),
            collapsedDictionaries: [],
            onSetCollapsed: { _, _ in },
            languageHint: "ja",
            onMakeNote: {},
            onLookupRequested: { _ in }
        )
    }
    .listStyle(.plain)
}

#Preview("Entry — compact") {
    List {
        LookupEntryView(
            entry: previewEntry(term: "頑張る", reading: "がんばる", frequency: nil, pitch: nil),
            dictionaryStyles: [:],
            audioTemplate: "",
            audioPlaybackMode: .interrupt,
            styling: LookupEntryStyling(compactGlossaries: true),
            collapsedDictionaries: [],
            onSetCollapsed: { _, _ in },
            languageHint: "ja",
            onMakeNote: {},
            onLookupRequested: { _ in }
        )
    }
    .listStyle(.plain)
}

#Preview("Header only") {
    LookupEntryHeaderView(
        term: "勉強",
        reading: "べんきょう",
        frequency: "1023",
        styling: LookupEntryStyling(),
        audioTemplate: "",
        audioPlaybackMode: .interrupt,
        languageHint: "ja",
        onMakeNote: {}
    )
    .padding()
}
