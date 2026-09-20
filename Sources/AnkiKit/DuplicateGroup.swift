//
//  DuplicateGroup.swift
//  AnkiKit
//
//  Created by Vladimir Gusev on 13.09.2026.
//

public struct DuplicateGroup: Sendable, Hashable, Identifiable {
    public let notetypeID: NotetypeID
    public let value: String
    public let noteIDs: [NoteID]

    public var id: String { "\(notetypeID.rawValue)\u{1f}\(value)" }

    public init(notetypeID: NotetypeID, value: String, noteIDs: [NoteID]) {
        self.notetypeID = notetypeID
        self.value = value
        self.noteIDs = noteIDs
    }
}
