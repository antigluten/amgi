//
//  NotetypesLiveTests.swift
//  AnkiProtoBridgeTests
//
//  Created by Vladimir Gusev on 13.09.2026.
//

import Foundation
import Testing
import AnkiKit
@testable import AnkiProtoBridge
@testable import AnkiBackend

@Suite struct NotetypesLiveTests {
    @Test func notetype_carriesFieldsAndTemplates() throws {
        try withScratchCollection("notetypes-read") { backend, _ in
            let names = try backend.invoke(.notetypeNames)
            let basic = try #require(names.first { $0.name == "Basic" })

            let notetype = try backend.invoke(.notetype(for: basic.id))
            #expect(notetype.id == basic.id)
            #expect(notetype.name == "Basic")
            #expect(notetype.fields.map(\.name) == ["Front", "Back"])
            #expect(notetype.templates.count == 1)
            #expect(!notetype.config.css.isEmpty, "stock notetypes ship a .card stylesheet")
        }
    }

    @Test func updateNotetype_thenRemoveNotetype() throws {
        try withScratchCollection("notetypes-write") { backend, _ in
            let names = try backend.invoke(.notetypeNames)
            let reversed = try #require(names.first { $0.name == "Basic (and reversed card)" })

            var notetype = try backend.invoke(.notetype(for: reversed.id))
            notetype.name = "Probed"
            notetype.fields[0].name = "Recto"
            try backend.invoke(.updateNotetype(notetype))

            let reloaded = try backend.invoke(.notetype(for: reversed.id))
            #expect(reloaded.name == "Probed")
            #expect(reloaded.fields[0].name == "Recto")
            #expect(try backend.invoke(.notetypeNames).contains { $0.name == "Probed" })

            try backend.invoke(.removeNotetype(id: reversed.id))
            #expect(try backend.invoke(.notetypeNames).allSatisfy { $0.id != reversed.id })
        }
    }
}
