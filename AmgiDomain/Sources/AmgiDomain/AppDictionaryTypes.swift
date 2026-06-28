import Foundation

public enum AppDictionaryKind: String, CaseIterable, Codable, Identifiable, Sendable {
    case term
    case frequency
    case pitch

    public var id: String { rawValue }
}

public struct AppDictionaryIndex: Codable, Hashable, Sendable {
    public var title: String
    public var format: Int
    public var revision: String
    public var isUpdatable: Bool
    public var indexURL: String
    public var downloadURL: String

    public init(
        title: String,
        format: Int = 0,
        revision: String = "",
        isUpdatable: Bool = false,
        indexURL: String = "",
        downloadURL: String = ""
    ) {
        self.title = title
        self.format = format
        self.revision = revision
        self.isUpdatable = isUpdatable
        self.indexURL = indexURL
        self.downloadURL = downloadURL
    }

    enum CodingKeys: String, CodingKey {
        case title
        case format
        case revision
        case isUpdatable
        case indexURL = "indexUrl"
        case downloadURL = "downloadUrl"
    }
}

public struct AppDictionaryInfo: Identifiable, Codable, Hashable, Sendable {
    public var fileName: String
    public var index: AppDictionaryIndex
    public var isEnabled: Bool
    public var order: Int

    public var id: String { fileName }

    public var title: String {
        index.title.isEmpty ? fileName : index.title
    }

    public init(
        fileName: String,
        index: AppDictionaryIndex,
        isEnabled: Bool = true,
        order: Int = 0
    ) {
        self.fileName = fileName
        self.index = index
        self.isEnabled = isEnabled
        self.order = order
    }
}

public struct AppDictionaryConfig: Codable, Hashable, Sendable {
    public struct Entry: Codable, Hashable, Sendable {
        public var fileName: String
        public var isEnabled: Bool
        public var order: Int

        public init(fileName: String, isEnabled: Bool, order: Int) {
            self.fileName = fileName
            self.isEnabled = isEnabled
            self.order = order
        }
    }

    public var termDictionaries: [Entry]
    public var frequencyDictionaries: [Entry]
    public var pitchDictionaries: [Entry]

    public init(
        termDictionaries: [Entry] = [],
        frequencyDictionaries: [Entry] = [],
        pitchDictionaries: [Entry] = []
    ) {
        self.termDictionaries = termDictionaries
        self.frequencyDictionaries = frequencyDictionaries
        self.pitchDictionaries = pitchDictionaries
    }
}

public struct AppDictionaryLibraryState: Codable, Hashable, Sendable {
    public var termDictionaries: [AppDictionaryInfo]
    public var frequencyDictionaries: [AppDictionaryInfo]
    public var pitchDictionaries: [AppDictionaryInfo]

    public init(
        termDictionaries: [AppDictionaryInfo] = [],
        frequencyDictionaries: [AppDictionaryInfo] = [],
        pitchDictionaries: [AppDictionaryInfo] = []
    ) {
        self.termDictionaries = termDictionaries
        self.frequencyDictionaries = frequencyDictionaries
        self.pitchDictionaries = pitchDictionaries
    }

    public static let empty = Self()

    public var isEmpty: Bool {
        termDictionaries.isEmpty && frequencyDictionaries.isEmpty && pitchDictionaries.isEmpty
    }
}
