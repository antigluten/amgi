public import AmgiReader
public import AnkiKit
import Foundation

/// Lookup-derived data the user wants to fold into a new Anki note.
/// Pure value type — the popup builds one of these from a
/// `DictionaryLookupEntry` and the chapter context, then a template
/// projects it onto the user's chosen notetype field names.
public struct ReaderLookupNotePayload: Sendable, Hashable {
    public var term: String
    public var reading: String?
    public var sentence: String?
    public var definitions: [String]
    public var dictionaries: String?
    public var frequency: String?
    public var pitch: String?
    public var deinflection: String?
    public var matched: String?
    public var source: String?
    public var rules: String?

    public init(
        term: String,
        reading: String? = nil,
        sentence: String? = nil,
        definitions: [String] = [],
        dictionaries: String? = nil,
        frequency: String? = nil,
        pitch: String? = nil,
        deinflection: String? = nil,
        matched: String? = nil,
        source: String? = nil,
        rules: String? = nil
    ) {
        self.term = term
        self.reading = reading
        self.sentence = sentence
        self.definitions = definitions
        self.dictionaries = dictionaries
        self.frequency = frequency
        self.pitch = pitch
        self.deinflection = deinflection
        self.matched = matched
        self.source = source
        self.rules = rules
    }

    public var normalizedDefinitions: [String] {
        definitions
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    /// Collapses a lookup's per-dictionary glossary list into one
    /// definition-string per dictionary. Preserves dictionary order
    /// (deduped) and joins multi-sense definitions inside each
    /// dictionary with newlines — matches DreamAfar's output shape so
    /// the same field-mapping templates work across forks.
    public static func definitionsByDictionary(from glossaries: [DictionaryLookupGlossary]) -> [String] {
        var orderedDictionaries: [String] = []
        var grouped: [String: [String]] = [:]

        for glossary in glossaries {
            let key = glossary.dictionary.trimmingCharacters(in: .whitespacesAndNewlines)
            let definitions = glossary.definitions
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            guard !definitions.isEmpty else { continue }
            if grouped[key] == nil {
                orderedDictionaries.append(key)
                grouped[key] = []
            }
            grouped[key, default: []].append(contentsOf: definitions)
        }

        return orderedDictionaries.compactMap { key in
            let merged = grouped[key, default: []]
            return merged.isEmpty ? nil : merged.joined(separator: "\n")
        }
    }
}

/// User-configured mapping from lookup-payload slots to the field names
/// of their chosen notetype. Stored as JSON in Reader settings; survives
/// notetype renames as long as the field names are stable.
public struct ReaderLookupNoteTemplate: Codable, Hashable, Sendable {
    public var deckID: Int64?
    public var notetypeID: Int64?
    public var termField: String
    public var readingField: String
    public var sentenceField: String
    public var definition1Field: String
    public var definition2Field: String
    public var definition3Field: String
    public var dictionariesField: String
    public var frequencyField: String
    public var pitchField: String
    public var deinflectionField: String
    public var matchedField: String
    public var sourceField: String
    public var rulesField: String

    public static let empty = Self()

    public init(
        deckID: Int64? = nil,
        notetypeID: Int64? = nil,
        termField: String = "",
        readingField: String = "",
        sentenceField: String = "",
        definition1Field: String = "",
        definition2Field: String = "",
        definition3Field: String = "",
        dictionariesField: String = "",
        frequencyField: String = "",
        pitchField: String = "",
        deinflectionField: String = "",
        matchedField: String = "",
        sourceField: String = "",
        rulesField: String = ""
    ) {
        self.deckID = deckID
        self.notetypeID = notetypeID
        self.termField = termField
        self.readingField = readingField
        self.sentenceField = sentenceField
        self.definition1Field = definition1Field
        self.definition2Field = definition2Field
        self.definition3Field = definition3Field
        self.dictionariesField = dictionariesField
        self.frequencyField = frequencyField
        self.pitchField = pitchField
        self.deinflectionField = deinflectionField
        self.matchedField = matchedField
        self.sourceField = sourceField
        self.rulesField = rulesField
    }

    public var hasMappedFields: Bool {
        let fields = [
            termField, readingField, sentenceField,
            definition1Field, definition2Field, definition3Field,
            dictionariesField, frequencyField, pitchField,
            deinflectionField, matchedField, sourceField, rulesField
        ]
        return fields.contains { !$0.isEmpty }
    }

    enum CodingKeys: String, CodingKey {
        case deckID, notetypeID
        case termField, readingField, sentenceField
        case definition1Field, definition2Field, definition3Field
        case dictionariesField, frequencyField, pitchField
        case deinflectionField, matchedField, sourceField, rulesField
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        deckID = try c.decodeIfPresent(Int64.self, forKey: .deckID)
        notetypeID = try c.decodeIfPresent(Int64.self, forKey: .notetypeID)
        termField = try c.decodeIfPresent(String.self, forKey: .termField) ?? ""
        readingField = try c.decodeIfPresent(String.self, forKey: .readingField) ?? ""
        sentenceField = try c.decodeIfPresent(String.self, forKey: .sentenceField) ?? ""
        definition1Field = try c.decodeIfPresent(String.self, forKey: .definition1Field) ?? ""
        definition2Field = try c.decodeIfPresent(String.self, forKey: .definition2Field) ?? ""
        definition3Field = try c.decodeIfPresent(String.self, forKey: .definition3Field) ?? ""
        dictionariesField = try c.decodeIfPresent(String.self, forKey: .dictionariesField) ?? ""
        frequencyField = try c.decodeIfPresent(String.self, forKey: .frequencyField) ?? ""
        pitchField = try c.decodeIfPresent(String.self, forKey: .pitchField) ?? ""
        deinflectionField = try c.decodeIfPresent(String.self, forKey: .deinflectionField) ?? ""
        matchedField = try c.decodeIfPresent(String.self, forKey: .matchedField) ?? ""
        sourceField = try c.decodeIfPresent(String.self, forKey: .sourceField) ?? ""
        rulesField = try c.decodeIfPresent(String.self, forKey: .rulesField) ?? ""
    }

    public func encodedString() -> String {
        guard let data = try? JSONEncoder().encode(self),
              let s = String(data: data, encoding: .utf8) else { return "" }
        return s
    }

    public static func decode(from string: String) -> Self {
        guard let data = string.data(using: .utf8),
              let value = try? JSONDecoder().decode(Self.self, from: data) else { return .empty }
        return value
    }

    /// Drop any field name that no longer matches one of the notetype's
    /// real fields. Called when the user changes notetype to clean up
    /// orphans without forcing a full reset.
    public mutating func clearInvalidFields(validFields: [String]) {
        let valid = Set(validFields)
        if !valid.contains(termField) { termField = "" }
        if !valid.contains(readingField) { readingField = "" }
        if !valid.contains(sentenceField) { sentenceField = "" }
        if !valid.contains(definition1Field) { definition1Field = "" }
        if !valid.contains(definition2Field) { definition2Field = "" }
        if !valid.contains(definition3Field) { definition3Field = "" }
        if !valid.contains(dictionariesField) { dictionariesField = "" }
        if !valid.contains(frequencyField) { frequencyField = "" }
        if !valid.contains(pitchField) { pitchField = "" }
        if !valid.contains(deinflectionField) { deinflectionField = "" }
        if !valid.contains(matchedField) { matchedField = "" }
        if !valid.contains(sourceField) { sourceField = "" }
        if !valid.contains(rulesField) { rulesField = "" }
    }

    public func makeDraft(
        payload: ReaderLookupNotePayload,
        fallbackDeckID: Int64?,
        sourceDescription: String
    ) -> AddNoteDraft {
        var fieldValues: [String: String] = [:]
        let definitions = payload.normalizedDefinitions

        func assign(_ fieldName: String, _ value: String?) {
            guard !fieldName.isEmpty,
                  let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !trimmed.isEmpty else { return }
            fieldValues[fieldName] = trimmed
        }

        assign(termField, payload.term)
        assign(readingField, payload.reading)
        assign(sentenceField, payload.sentence)
        assign(definition1Field, definitions[safe: 0])
        assign(definition2Field, definitions[safe: 1])
        assign(definition3Field, definitions[safe: 2])
        assign(dictionariesField, payload.dictionaries)
        assign(frequencyField, payload.frequency)
        assign(pitchField, payload.pitch)
        assign(deinflectionField, payload.deinflection)
        assign(matchedField, payload.matched)
        assign(sourceField, payload.source)
        assign(rulesField, payload.rules)

        // No mapping configured yet: best-effort fallback to common
        // basic-notetype field names so the user still gets *some* note,
        // not an empty one. Once they set up the mapping properly the
        // assigned-by-name path above takes over.
        if fieldValues.isEmpty {
            let resolvedSentence = payload.sentence?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .nilIfBlank ?? payload.term
            fieldValues = [
                "Front": payload.term,
                "Text": payload.term,
                "Expression": payload.term,
                "Sentence": resolvedSentence,
                "Back": sourceDescription,
                "Source": sourceDescription,
                "Extra": sourceDescription,
            ]
        }

        return AddNoteDraft(
            deckID: deckID ?? fallbackDeckID,
            notetypeID: notetypeID,
            fieldValues: fieldValues
        )
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
