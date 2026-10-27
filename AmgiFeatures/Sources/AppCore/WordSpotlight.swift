package import Foundation

package struct SpotlightWord: Codable, Equatable, Sendable {
    package var noteID: Int64
    package var term: String
    package var reading: String
    package var meaning: String

    package init(noteID: Int64, term: String, reading: String, meaning: String) {
        self.noteID = noteID
        self.term = term
        self.reading = reading
        self.meaning = meaning
    }
}

package struct WordSpotlightPreferences: Codable, Equatable, Sendable {
    package var deckID: Int64 = 0
    package var notetypeID: Int64 = 0
    package var termField = ""
    package var readingField = ""
    package var meaningField = ""
    package var notifications = false
    package var hour = 9
    package var minute = 0
    package var showWord = true
    // Optional so existing saved preferences still decode as daily rotation.
    package var intervalHours: Int?

    package var rotationHours: Int {
        [1, 3, 6, 12, 24].contains(intervalHours ?? 24) ? (intervalHours ?? 24) : 24
    }

    package init() {}

    package var isConfigured: Bool {
        deckID > 0 && notetypeID > 0 && !termField.isEmpty && !meaningField.isEmpty
    }

    package var sourceID: String {
        let fields = [String(deckID), String(notetypeID), termField, readingField, meaningField]
        return (try? JSONEncoder().encode(fields)).map { String(decoding: $0, as: UTF8.self) } ?? ""
    }
}

package struct WordSpotlightLink: Equatable, Sendable {
    package var profileID: String
    package var noteID: Int64

    package init(profileID: String, noteID: Int64) {
        self.profileID = profileID
        self.noteID = noteID
    }

    package init?(url: URL) {
        guard url.scheme == "amgi", url.host == "word",
              let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
              let profile = items.first(where: { $0.name == "profile" })?.value, !profile.isEmpty,
              let rawID = items.first(where: { $0.name == "note" })?.value,
              let noteID = Int64(rawID), noteID > 0 else { return nil }
        self.init(profileID: profile, noteID: noteID)
    }

    package var url: URL? {
        var components = URLComponents()
        components.scheme = "amgi"
        components.host = "word"
        components.queryItems = [
            URLQueryItem(name: "profile", value: profileID),
            URLQueryItem(name: "note", value: String(noteID)),
        ]
        return components.url
    }
}
