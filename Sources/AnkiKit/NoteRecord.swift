public struct NoteRecord: Sendable, Hashable, Identifiable {
    public let id: Int64
    public var guid: String
    public var mid: Int64
    public var mod: Int64
    public var usn: Int32
    public var tags: String
    public var flds: String
    public var sfld: String
    public var csum: Int64
    public var flags: Int32
    public var data: String

    public init(
        id: Int64, guid: String, mid: Int64, mod: Int64,
        usn: Int32 = -1, tags: String = "", flds: String,
        sfld: String, csum: Int64, flags: Int32 = 0, data: String = ""
    ) {
        self.id = id; self.guid = guid; self.mid = mid; self.mod = mod
        self.usn = usn; self.tags = tags; self.flds = flds
        self.sfld = sfld; self.csum = csum; self.flags = flags; self.data = data
    }
}
