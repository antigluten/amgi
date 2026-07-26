package import AnkiKit
package import AnkiProto

/// Separator used to join note fields into the legacy single-string
/// `flds` representation (matches the Anki desktop convention).
package let noteFieldSeparator: Character = "\u{1f}"

// MARK: - Proto → mirror

package extension NoteRecord {
    init(_ proto: Anki_Notes_Note) {
        self.init(
            id: NoteID(proto.id),
            guid: proto.guid,
            mid: NotetypeID(proto.notetypeID),
            mod: Int64(proto.mtimeSecs),
            usn: proto.usn,
            tags: proto.tags.joined(separator: " "),
            flds: proto.fields.joined(separator: String(noteFieldSeparator)),
            sfld: proto.fields.first ?? "",
            csum: 0
        )
    }
}

extension NoteRecord: BridgeDecodable {
    package typealias Proto = Anki_Notes_Note
}

// MARK: - Mirror → proto

package extension Anki_Notes_Note {
    init(_ record: NoteRecord) {
        self.init()
        self.id = record.id.rawValue
        self.notetypeID = record.mid.rawValue
        self.fields = record.flds
            .split(separator: noteFieldSeparator, omittingEmptySubsequences: false)
            .map(String.init)
        self.tags = record.tags
            .split(separator: " ")
            .map(String.init)
    }
}
