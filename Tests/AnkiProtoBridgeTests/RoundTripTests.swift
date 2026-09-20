//
//  RoundTripTests.swift
//  AnkiProtoBridgeTests
//
//  Created by Vladimir Gusev on 13.05.2026.
//

import Testing
import AnkiKit
@testable import AnkiProtoBridge
@testable import AnkiBackend
import AnkiProto

@Suite struct RoundTripTests {
    // MARK: - NoteRecord

    @Test func NoteRecord_roundTrips_id_notetype_fields_tags() {
        let original = NoteRecord(
            id: NoteID(101),
            guid: "ignored-on-roundtrip",
            mid: NotetypeID(42),
            mod: 1700000000,
            usn: 7,
            tags: "korean vocab ch1",
            flds: "front\u{1f}back\u{1f}extra",
            sfld: "front",
            csum: 0
        )
        let roundTripped = NoteRecord(Anki_Notes_Note(original))
        #expect(roundTripped.id == original.id)
        #expect(roundTripped.mid == original.mid)
        #expect(roundTripped.tags == original.tags)
        #expect(roundTripped.flds == original.flds)
        #expect(roundTripped.sfld == "front")  // first field
    }

    @Test func NoteRecord_field_separator_survives_empty_segments() {
        let original = NoteRecord(
            id: NoteID(1), guid: "", mid: NotetypeID(1), mod: 0,
            tags: "",
            // Middle field is empty.
            flds: "a\u{1f}\u{1f}c",
            sfld: "a", csum: 0
        )
        let roundTripped = NoteRecord(Anki_Notes_Note(original))
        #expect(roundTripped.flds == "a\u{1f}\u{1f}c")
    }

    @Test func NoteRecord_tag_separator_splits_on_space() {
        let original = NoteRecord(
            id: NoteID(1), guid: "", mid: NotetypeID(1), mod: 0,
            tags: "alpha beta gamma",
            flds: "x", sfld: "x", csum: 0
        )
        let roundTripped = NoteRecord(Anki_Notes_Note(original))
        #expect(roundTripped.tags == "alpha beta gamma")
    }

    // MARK: - DeckConfig

    @Test func DeckConfig_roundTrips_identity_fields() {
        let original = DeckConfig(
            id: DeckConfigID(99),
            name: "Korean Vocab",
            mtimeSecs: 1700000000,
            usn: 12,
            config: DeckConfig.Config()  // defaults — covered in conversion tests
        )
        let roundTripped = DeckConfig(original.toProto())
        #expect(roundTripped.id == original.id)
        #expect(roundTripped.name == original.name)
        #expect(roundTripped.mtimeSecs == original.mtimeSecs)
        #expect(roundTripped.usn == original.usn)
    }

    // MARK: - Notetype

    @Test func Notetype_roundTrips_identity_and_top_level_fields() {
        let original = makeNotetype()
        let roundTripped = Notetype(original.toProto())
        #expect(roundTripped.id == original.id)
        #expect(roundTripped.name == original.name)
        #expect(roundTripped.mtimeSecs == original.mtimeSecs)
        #expect(roundTripped.usn == original.usn)
        #expect(roundTripped.fields.count == original.fields.count)
        #expect(roundTripped.templates.count == original.templates.count)
    }

    @Test func Notetype_field_names_and_ords_roundtrip() {
        let original = makeNotetype()
        let roundTripped = Notetype(original.toProto())
        for (originalField, rtField) in zip(original.fields, roundTripped.fields) {
            #expect(originalField.name == rtField.name)
            #expect(originalField.ord == rtField.ord)
        }
    }

    @Test func Notetype_template_names_and_formats_roundtrip() {
        let original = makeNotetype()
        let roundTripped = Notetype(original.toProto())
        for (originalTpl, rtTpl) in zip(original.templates, roundTripped.templates) {
            #expect(originalTpl.name == rtTpl.name)
            #expect(originalTpl.ord == rtTpl.ord)
            #expect(originalTpl.config.qFormat == rtTpl.config.qFormat)
            #expect(originalTpl.config.aFormat == rtTpl.config.aFormat)
        }
    }

    // MARK: - Helpers

    private func makeNotetype() -> Notetype {
        Notetype(
            id: NotetypeID(7),
            name: "Korean Vocab",
            mtimeSecs: 1700000000,
            usn: 3,
            config: Notetype.Config(
                kind: .normal,
                sortFieldIdx: 0,
                css: ".card { font-family: Sarasa; }",
                latexPre: "",
                latexPost: "",
                latexSvg: false,
                reqs: [],
                originalStockKind: .unknown
            ),
            fields: [
                Notetype.Field(ord: 0, name: "Front"),
                Notetype.Field(ord: 1, name: "Back"),
            ],
            templates: [
                Notetype.Template(
                    ord: 0,
                    name: "Card 1",
                    config: Notetype.Template.Config(
                        qFormat: "{{Front}}",
                        aFormat: "{{FrontSide}}<hr>{{Back}}"
                    )
                ),
            ]
        )
    }
}
