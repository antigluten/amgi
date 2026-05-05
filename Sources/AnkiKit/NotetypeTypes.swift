public struct NotetypeInfo: Sendable {
    public let id: Int64
    public let name: String
    public let fieldNames: [String]

    package init(id: Int64, name: String, fieldNames: [String]) {
        self.id = id
        self.name = name
        self.fieldNames = fieldNames
    }
}

/// Per-field config info for a notetype field — used by typed-answer rendering.
public struct NotetypeFieldInfo: Sendable {
    public let name: String
    public let ordinal: Int
    public let fontName: String
    public let fontSize: Int

    package init(name: String, ordinal: Int, fontName: String, fontSize: Int) {
        self.name = name
        self.ordinal = ordinal
        self.fontName = fontName
        self.fontSize = fontSize
    }
}

public struct NewNoteTemplate: Sendable {
    public let notetypeId: Int64
    public var fields: [String]
    public var tags: [String]

    package init(notetypeId: Int64, fields: [String]) {
        self.notetypeId = notetypeId
        self.fields = fields
        self.tags = []
    }
}
