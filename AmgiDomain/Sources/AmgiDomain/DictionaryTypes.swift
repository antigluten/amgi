public struct DictionaryLookupDeinflectionStep: Sendable, Hashable, Codable {
    public var name: String
    public var description: String?

    public init(name: String, description: String? = nil) {
        self.name = name
        self.description = description
    }
}

public struct DictionaryLookupGlossary: Sendable, Hashable, Codable {
    public var dictionary: String
    public var content: String
    public var definitions: [String]
    public var definitionTags: String?
    public var termTags: String?

    public init(
        dictionary: String,
        content: String = "",
        definitions: [String] = [],
        definitionTags: String? = nil,
        termTags: String? = nil
    ) {
        self.dictionary = dictionary
        self.content = content
        self.definitions = definitions
        self.definitionTags = definitionTags
        self.termTags = termTags
    }
}

public struct DictionaryLookupFrequencyValue: Sendable, Hashable, Codable {
    public var value: Int
    public var displayValue: String?

    public init(value: Int, displayValue: String? = nil) {
        self.value = value
        self.displayValue = displayValue
    }
}

public struct DictionaryLookupFrequency: Sendable, Hashable, Codable {
    public var dictionary: String
    public var frequencies: [DictionaryLookupFrequencyValue]

    public init(dictionary: String, frequencies: [DictionaryLookupFrequencyValue] = []) {
        self.dictionary = dictionary
        self.frequencies = frequencies
    }
}

public struct DictionaryLookupPitch: Sendable, Hashable, Codable {
    public var dictionary: String
    public var positions: [Int]

    public init(dictionary: String, positions: [Int] = []) {
        self.dictionary = dictionary
        self.positions = positions
    }
}

public struct DictionaryLookupEntry: Sendable, Hashable, Identifiable, Codable {
    public var term: String
    public var reading: String?
    public var matched: String?
    public var rules: [String]
    public var deinflectionTrace: [DictionaryLookupDeinflectionStep]
    public var structuredGlossaries: [DictionaryLookupGlossary]
    public var structuredFrequencies: [DictionaryLookupFrequency]
    public var structuredPitches: [DictionaryLookupPitch]
    public var glossaries: [String]
    public var frequency: String?
    public var pitch: String?
    public var source: String?

    public var id: String {
        [term, reading ?? "", source ?? ""].joined(separator: "|")
    }

    public init(
        term: String,
        reading: String? = nil,
        matched: String? = nil,
        rules: [String] = [],
        deinflectionTrace: [DictionaryLookupDeinflectionStep] = [],
        structuredGlossaries: [DictionaryLookupGlossary] = [],
        structuredFrequencies: [DictionaryLookupFrequency] = [],
        structuredPitches: [DictionaryLookupPitch] = [],
        glossaries: [String] = [],
        frequency: String? = nil,
        pitch: String? = nil,
        source: String? = nil
    ) {
        self.term = term
        self.reading = reading
        self.matched = matched
        self.rules = rules
        self.deinflectionTrace = deinflectionTrace
        self.structuredGlossaries = structuredGlossaries
        self.structuredFrequencies = structuredFrequencies
        self.structuredPitches = structuredPitches
        self.glossaries = glossaries
        self.frequency = frequency
        self.pitch = pitch
        self.source = source
    }
}

public struct DictionaryLookupResult: Sendable, Hashable, Codable {
    public var query: String
    public var entries: [DictionaryLookupEntry]
    public var isPlaceholder: Bool
    public var dictionaryStyles: [String: String]

    public init(
        query: String,
        entries: [DictionaryLookupEntry] = [],
        isPlaceholder: Bool = false,
        dictionaryStyles: [String: String] = [:]
    ) {
        self.query = query
        self.entries = entries
        self.isPlaceholder = isPlaceholder
        self.dictionaryStyles = dictionaryStyles
    }
}
