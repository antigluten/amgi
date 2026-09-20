//
//  AuxRequests.swift
//  AnkiProtoBridge
//
//  Created by Vladimir Gusev on 13.09.2026.
//

import Foundation
public import AnkiBackend
public import AnkiKit

// MARK: - findDuplicates

private struct FindDuplicatesResponse: Decodable {
    struct Group: Decodable {
        let notetypeId: Int64
        let value: String
        let noteIds: [Int64]

        enum CodingKeys: String, CodingKey {
            case notetypeId = "notetype_id"
            case value
            case noteIds = "note_ids"
        }
    }

    let groups: [Group]
}

extension Request where Response == [DuplicateGroup] {
    public static var findDuplicates: Self {
        .empty(
            serviceId: ServiceID.aux,
            methodId: AuxMethod.findDuplicates,
            decode: { data in
                try JSONDecoder().decode(FindDuplicatesResponse.self, from: data)
                    .groups
                    .map {
                        DuplicateGroup(
                            notetypeID: NotetypeID($0.notetypeId),
                            value: $0.value,
                            noteIDs: $0.noteIds.map { NoteID($0) }
                        )
                    }
            }
        )
    }
}
