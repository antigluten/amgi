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
