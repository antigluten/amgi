//
//  CollectionChanges+Proto.swift
//  AnkiProtoBridge
//
//  Created by Vladimir Gusev on 05.07.2026.
//

package import AnkiKit
package import AnkiProto

extension CollectionChanges {
    package init(_ proto: Anki_Collection_OpChanges) {
        self.init(
            card: proto.card,
            note: proto.note,
            deck: proto.deck,
            tag: proto.tag,
            notetype: proto.notetype,
            studyQueues: proto.studyQueues
        )
    }
}
