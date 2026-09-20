//
//  NoteRecord.swift
//  AnkiKit
//
//  Created by Vladimir Gusev on 27.03.2026.
//

public struct NoteRecord: Sendable, Hashable, Identifiable {
    public let id: NoteID
    public var guid: String
    public var mid: NotetypeID
    public var mod: Int64
    public var usn: Int32
    public var tags: String
    public var flds: String
    public var sfld: String
    public var csum: Int64
    public var flags: Int32
    public var data: String

    public init(
        id: NoteID, guid: String, mid: NotetypeID, mod: Int64,
        usn: Int32 = -1, tags: String = "", flds: String,
        sfld: String, csum: Int64, flags: Int32 = 0, data: String = ""
    ) {
        self.id = id; self.guid = guid; self.mid = mid; self.mod = mod
        self.usn = usn; self.tags = tags; self.flds = flds
        self.sfld = sfld; self.csum = csum; self.flags = flags; self.data = data
    }

    /// Image-occlusion notes carry an `image-occlusion:` marker in their field
    /// blob; they need the mask editor rather than the plain note editor.
    public var isImageOcclusionNote: Bool {
        flds.contains("image-occlusion:")
    }
}
