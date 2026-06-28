public import Foundation

/// A snapshot of where the user is inside a book — which chapter and how
/// far down it. `progress` is a 0..1 fraction; `updatedAt` is the wall-clock
/// time the snapshot was last written, used by sync layers to pick a winner
/// when multiple sources disagree.
public struct ReaderSavedProgress: Codable, Equatable, Sendable {
    public var chapterID: Int64
    public var progress: Double
    public var updatedAt: Date

    public init(chapterID: Int64, progress: Double, updatedAt: Date) {
        self.chapterID = chapterID
        self.progress = progress
        self.updatedAt = updatedAt
    }
}

/// Local, single-device persistence for per-book reading progress. Stores
/// each book's `ReaderSavedProgress` as a JSON-encoded value in a
/// `UserDefaults` instance under a sanitized key.
///
/// Deliberately scoped to local persistence only. Cross-device sync via
/// the Anki collection config — and any legacy media-folder migrations —
/// belong in an Anki-side adapter that wraps this store; keeping them
/// out of `AmgiReader` is what lets this package stay free of Anki
/// dependencies.
// `UserDefaults` is thread-safe but not formally `Sendable`. The struct is
// otherwise value-only, so `@unchecked Sendable` is honest here.
public struct ReaderProgressStore: @unchecked Sendable {
    private let userDefaults: UserDefaults
    private let keyNamespace: String

    public init(
        userDefaults: UserDefaults = .standard,
        keyNamespace: String = "amgi.reader.progress"
    ) {
        self.userDefaults = userDefaults
        self.keyNamespace = keyNamespace
    }

    public func load(bookID: String) -> ReaderSavedProgress? {
        guard let data = userDefaults.data(forKey: storageKey(for: bookID)) else {
            return nil
        }
        return try? JSONDecoder().decode(ReaderSavedProgress.self, from: data)
    }

    public func save(bookID: String, chapterID: Int64, progress: Double, now: Date = .now) {
        let payload = ReaderSavedProgress(
            chapterID: chapterID,
            // Clamp to [0,1] so callers can pass raw scroll fractions
            // without having to range-check.
            progress: min(max(progress, 0), 1),
            updatedAt: now
        )
        save(bookID: bookID, payload: payload)
    }

    public func save(bookID: String, payload: ReaderSavedProgress) {
        guard let data = try? JSONEncoder().encode(payload) else { return }
        userDefaults.set(data, forKey: storageKey(for: bookID))
    }

    public func clear(bookID: String) {
        userDefaults.removeObject(forKey: storageKey(for: bookID))
    }

    private func storageKey(for bookID: String) -> String {
        "\(keyNamespace).\(Self.sanitize(bookID))"
    }

    /// Strip anything that isn't `[A-Za-z0-9._-]` so `UserDefaults` keys
    /// stay portable across the Apple sandbox layers (and so future code
    /// can't be tripped up by separators inside a book ID).
    private static func sanitize(_ bookID: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_."))
        return String(bookID.unicodeScalars.map { scalar in
            allowed.contains(scalar) ? Character(scalar) : "_"
        })
    }
}
