import Foundation

public struct CardRecord: Sendable {
    public let id: Int64
    public var nid: Int64
    public var did: Int64
    public var ord: Int32
    public var mod: Int64
    public var usn: Int32
    public var type: Int16
    public var queue: Int16
    public var due: Int32
    public var ivl: Int32
    public var factor: Int32
    public var reps: Int32
    public var lapses: Int32
    public var left: Int32
    public var odue: Int32
    public var odid: Int64
    public var flags: Int32
    public var data: String

    public init(
        id: Int64, nid: Int64, did: Int64, ord: Int32 = 0,
        mod: Int64, usn: Int32 = -1, type: Int16 = 0, queue: Int16 = 0,
        due: Int32 = 0, ivl: Int32 = 0, factor: Int32 = 0, reps: Int32 = 0,
        lapses: Int32 = 0, left: Int32 = 0, odue: Int32 = 0, odid: Int64 = 0,
        flags: Int32 = 0, data: String = ""
    ) {
        self.id = id; self.nid = nid; self.did = did; self.ord = ord
        self.mod = mod; self.usn = usn; self.type = type; self.queue = queue
        self.due = due; self.ivl = ivl; self.factor = factor; self.reps = reps
        self.lapses = lapses; self.left = left; self.odue = odue; self.odid = odid
        self.flags = flags; self.data = data
    }
}
