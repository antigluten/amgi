import AmgiReader
import SwiftUI

/// The plain list of dictionary entries shared by the root lookup popup and
/// every pushed child pane. Both used to inline an identical
/// `List { ForEach(result.entries) { LookupEntryView(...) } }`; this is that
/// body, parameterised by the per-entry callbacks each caller supplies.
struct LookupResultList: View {
    let result: DictionaryLookupResult
    let styling: LookupEntryStyling
    let audioTemplate: String
    let audioPlaybackMode: LookupAudioPlaybackMode
    let collapsedDictionaries: Set<String>
    let onSetCollapsed: (String, Bool) -> Void
    let languageHint: String?
    let onMakeNote: (DictionaryLookupEntry) -> Void
    let onLookupRequested: (String) -> Void

    var body: some View {
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
                    onLookupRequested: onLookupRequested
                )
            }
        }
        .listStyle(.plain)
    }
}

// MARK: - Preview

#Preview("Result list") {
    LookupResultList(
        result: DictionaryLookupResult(
            query: "勉強",
            entries: [
                DictionaryLookupEntry(
                    term: "勉強",
                    reading: "べんきょう",
                    glossaries: ["study; diligence"],
                    frequency: "1023",
                    pitch: "[0]"
                ),
                DictionaryLookupEntry(
                    term: "勉強会",
                    reading: "べんきょうかい",
                    glossaries: ["study group; study meeting"],
                    frequency: "8841"
                ),
            ]
        ),
        styling: LookupEntryStyling(),
        audioTemplate: "",
        audioPlaybackMode: .interrupt,
        collapsedDictionaries: [],
        onSetCollapsed: { _, _ in },
        languageHint: "ja",
        onMakeNote: { _ in },
        onLookupRequested: { _ in }
    )
}
