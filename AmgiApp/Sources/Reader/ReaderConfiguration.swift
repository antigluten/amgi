import AmgiReader
import Foundation
import Sharing

/// Reader needs to know which deck holds the user's books and how the
/// notetype's fields map onto book/chapter shapes. Both pieces are
/// persisted in UserDefaults (via `@Shared(.appStorage)`) using the
/// existing `ReaderPreferences.Keys`.
///
/// `loadConfiguration()` snapshots the prefs into a `ReaderLibraryConfiguration`
/// the `ReaderBookClient` can consume; views read prefs directly when they
/// need to bind input controls.
enum ReaderConfigurationLoader {
    /// Returns a configuration only if the user has actually filled in the
    /// non-optional pieces (deck name + the four required field names).
    /// Empty strings count as "not configured."
    static func loadConfiguration() -> ReaderLibraryConfiguration? {
        let defaults = UserDefaults.standard
        let deckName = defaults.string(forKey: "reader_pref_deck_name") ?? ""
        let bookID = defaults.string(forKey: ReaderPreferenceKey.bookIDField) ?? ""
        let bookTitle = defaults.string(forKey: ReaderPreferenceKey.bookTitleField) ?? ""
        let chapterTitle = defaults.string(forKey: ReaderPreferenceKey.chapterTitleField) ?? ""
        let chapterOrder = defaults.string(forKey: ReaderPreferenceKey.chapterOrderField) ?? ""
        let content = defaults.string(forKey: ReaderPreferenceKey.contentField) ?? ""

        guard !deckName.isEmpty,
              !bookID.isEmpty,
              !bookTitle.isEmpty,
              !chapterTitle.isEmpty,
              !chapterOrder.isEmpty,
              !content.isEmpty else {
            return nil
        }

        let cover = defaults.string(forKey: ReaderPreferenceKey.bookCoverField).flatMap { $0.isEmpty ? nil : $0 }
        let language = defaults.string(forKey: ReaderPreferenceKey.languageField).flatMap { $0.isEmpty ? nil : $0 }

        let notetypeID = defaults.object(forKey: ReaderPreferenceKey.notetypeID) as? Int64

        return ReaderLibraryConfiguration(
            deckName: deckName,
            notetypeID: notetypeID,
            fieldMapping: ReaderFieldMapping(
                bookIDField: bookID,
                bookTitleField: bookTitle,
                bookCoverField: cover,
                chapterTitleField: chapterTitle,
                chapterOrderField: chapterOrder,
                contentField: content,
                languageField: language
            )
        )
    }
}

/// String-keyed mirror of `ReaderPreferences.Keys` so this file can use
/// the same identifiers without re-importing the Settings module here.
/// Kept private — Settings views still go through `ReaderPreferences.Keys`.
enum ReaderPreferenceKey {
    static let deckName = "reader_pref_deck_name"
    static let notetypeID = ReaderPreferences.Keys.notetypeID
    static let bookIDField = ReaderPreferences.Keys.bookIDField
    static let bookTitleField = ReaderPreferences.Keys.bookTitleField
    static let bookCoverField = ReaderPreferences.Keys.bookCoverField
    static let chapterTitleField = ReaderPreferences.Keys.chapterTitleField
    static let chapterOrderField = ReaderPreferences.Keys.chapterOrderField
    static let contentField = ReaderPreferences.Keys.contentField
    static let languageField = ReaderPreferences.Keys.languageField
}
