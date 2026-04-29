public struct AddNoteDraft: Sendable, Hashable {
    public var deckID: Int64?
    public var notetypeID: Int64?
    public var fieldValues: [String: String]
    public var tags: [String]

    public init(
        deckID: Int64? = nil,
        notetypeID: Int64? = nil,
        fieldValues: [String: String] = [:],
        tags: [String] = []
    ) {
        self.deckID = deckID
        self.notetypeID = notetypeID
        self.fieldValues = fieldValues
        self.tags = tags
    }
}
