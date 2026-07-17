import AmgiReader
import AnkiBackend
import AnkiKit
import AnkiProto
public import Dependencies
import DependenciesMacros
import Foundation

private struct ReaderChapterRecord {
    let chapter: ReaderChapter
    let coverImagePath: String?
}

/// Reader books are derived from notes in a configurable deck. Each note
/// becomes a chapter; chapters with the same `bookIDField` value collapse
/// into a single `ReaderBook`. Field mapping is supplied per-call via
/// `ReaderLibraryConfiguration` so users can target their own notetype
/// schema without forking the client.
extension ReaderBookClient: DependencyKey {
    public static let liveValue: Self = {
        @Dependency(\.noteClient) var noteClient
        @Dependency(\.notetypesClient) var notetypesClient

        return Self(
            loadBooks: { configuration in
                let notes = try fetchNotes(for: configuration, noteClient: noteClient)
                return try buildBooks(
                    from: notes,
                    configuration: configuration,
                    notetypesClient: notetypesClient
                )
            },
            loadBook: { bookID, configuration in
                let notes = try fetchNotes(for: configuration, noteClient: noteClient)
                return try buildBooks(
                    from: notes,
                    configuration: configuration,
                    notetypesClient: notetypesClient
                )
                .first(where: { $0.id == bookID })
            }
        )
    }()
}

// MARK: - Note fetching

private func fetchNotes(
    for configuration: ReaderLibraryConfiguration,
    noteClient: NoteClient
) throws -> [NoteRecord] {
    let query = try validatedDeckQuery(configuration.deckName)
    // searchAll (not search) — we read `note.flds` immediately to build
    // chapters, so the lazy 50-real-rest-placeholder behavior of
    // `search` would silently drop chapter content past the first 50.
    var notes = try noteClient.searchAll(query, nil)
    if let notetypeID = configuration.notetypeID {
        notes = notes.filter { $0.mid == notetypeID }
    }
    return notes
}

private func validatedDeckQuery(_ deckName: String) throws -> String {
    let trimmed = deckName.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
        throw BackendError(kind: .invalidInput, message: "Reader deck name can't be empty")
    }
    let escaped = trimmed
        .replacingOccurrences(of: "\\", with: "\\\\")
        .replacingOccurrences(of: "\"", with: "\\\"")
    return "deck:\"\(escaped)\""
}

// MARK: - Book assembly

private func buildBooks(
    from notes: [NoteRecord],
    configuration: ReaderLibraryConfiguration,
    notetypesClient: NotetypesClient
) throws -> [ReaderBook] {
    var fieldNamesByNotetypeID: [Int64: [String]] = [:]
    var chaptersByBookID: [String: [ReaderChapter]] = [:]
    var coverImagePathByBookID: [String: String] = [:]

    for note in notes {
        // Guard against lazy/partial NoteRecord placeholders that
        // callers might hand us — `notetypesClient.getRaw(0)` would
        // crash the whole batch with a "no such notetype" backend
        // error. The eager fetcher above shouldn't produce these, but
        // belt-and-braces.
        guard note.mid != 0 else { continue }

        let fieldNames: [String]
        if let cached = fieldNamesByNotetypeID[note.mid] {
            fieldNames = cached
        } else {
            let notetype = try notetypesClient.getRaw(note.mid)
            let names = notetype.fields.map(\.name)
            fieldNamesByNotetypeID[note.mid] = names
            fieldNames = names
        }

        guard let record = makeChapterRecord(
            note: note,
            configuration: configuration,
            fieldNames: fieldNames
        ) else { continue }

        chaptersByBookID[record.chapter.bookID, default: []].append(record.chapter)
        if let cover = record.coverImagePath,
           coverImagePathByBookID[record.chapter.bookID] == nil {
            coverImagePathByBookID[record.chapter.bookID] = cover
        }
    }

    return chaptersByBookID.values
        .map { chapters in
            let sorted = chapters.sorted(by: chapterSort)
            return ReaderBook(
                id: sorted[0].bookID,
                title: sorted[0].bookTitle,
                coverImagePath: coverImagePathByBookID[sorted[0].bookID],
                language: sorted.compactMap(\.language).first,
                chapters: sorted
            )
        }
        .sorted { lhs, rhs in
            let cmp = lhs.title.localizedCaseInsensitiveCompare(rhs.title)
            if cmp != .orderedSame { return cmp == .orderedAscending }
            return lhs.id < rhs.id
        }
}

private func makeChapterRecord(
    note: NoteRecord,
    configuration: ReaderLibraryConfiguration,
    fieldNames: [String]
) -> ReaderChapterRecord? {
    let fieldMap = decodeFieldMap(note: note, fieldNames: fieldNames)
    let mapping = configuration.fieldMapping

    guard let bookID = trimmedFieldValue(mapping.bookIDField, in: fieldMap),
          let content = contentFieldValue(mapping.contentField, in: fieldMap) else {
        return nil
    }

    let bookTitle = trimmedFieldValue(mapping.bookTitleField, in: fieldMap) ?? bookID
    let chapterTitle = trimmedFieldValue(mapping.chapterTitleField, in: fieldMap) ?? bookTitle
    let chapterOrder = trimmedFieldValue(mapping.chapterOrderField, in: fieldMap)
    let language = mapping.languageField.flatMap { trimmedFieldValue($0, in: fieldMap) }
    let coverImagePath = coverFieldValue(mapping.bookCoverField, in: fieldMap)

    return ReaderChapterRecord(
        chapter: ReaderChapter(
            id: note.id,
            bookID: bookID,
            bookTitle: bookTitle,
            title: chapterTitle,
            order: chapterOrder,
            content: content,
            language: language
        ),
        coverImagePath: coverImagePath
    )
}

// MARK: - Field decoding

/// Anki stores note fields concatenated with U+001F (unit separator). The
/// notetype's field list defines the positional mapping back to names —
/// callers must pass `fieldNames` from the same notetype as the note.
private func decodeFieldMap(note: NoteRecord, fieldNames: [String]) -> [String: String] {
    let values = note.flds
        .split(separator: "\u{1f}", omittingEmptySubsequences: false)
        .map(String.init)

    var mapping: [String: String] = [:]
    mapping.reserveCapacity(fieldNames.count)
    for (index, name) in fieldNames.enumerated() {
        mapping[name] = index < values.count ? values[index] : ""
    }
    return mapping
}

private func trimmedFieldValue(_ fieldName: String, in fieldMap: [String: String]) -> String? {
    guard let raw = fieldMap[fieldName] else { return nil }
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
}

private func contentFieldValue(_ fieldName: String, in fieldMap: [String: String]) -> String? {
    guard let raw = fieldMap[fieldName], !raw.isEmpty else { return nil }
    return raw
}

private func coverFieldValue(_ fieldName: String?, in fieldMap: [String: String]) -> String? {
    guard let fieldName, let raw = fieldMap[fieldName] else { return nil }
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }

    if let imageSource = extractImageSource(from: trimmed)?
        .trimmingCharacters(in: .whitespacesAndNewlines),
       !imageSource.isEmpty {
        return imageSource
    }
    // Bare HTML without an <img src> isn't a usable cover path; treat as empty.
    if trimmed.contains("<"), trimmed.contains(">") { return nil }
    return trimmed
}

private func extractImageSource(from value: String) -> String? {
    let range = NSRange(value.startIndex..<value.endIndex, in: value)
    let pattern = #"<img[^>]*\bsrc\s*=\s*['"]?([^'" >]+)"#
    guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
          let match = regex.firstMatch(in: value, options: [], range: range),
          let sourceRange = Range(match.range(at: 1), in: value) else {
        return nil
    }
    return String(value[sourceRange])
}

// MARK: - Chapter sort

private func chapterSort(lhs: ReaderChapter, rhs: ReaderChapter) -> Bool {
    let lhsOrder = lhs.order.flatMap(Double.init)
    let rhsOrder = rhs.order.flatMap(Double.init)
    switch (lhsOrder, rhsOrder) {
    case let (l?, r?) where l != r: return l < r
    case (_?, nil): return true
    case (nil, _?): return false
    default:
        let cmp = lhs.title.localizedCaseInsensitiveCompare(rhs.title)
        if cmp != .orderedSame { return cmp == .orderedAscending }
        return lhs.id < rhs.id
    }
}
