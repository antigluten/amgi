import Testing
import AnkiKit
@testable import AnkiProtoBridge
@testable import AnkiBackend
import AnkiProto

@Suite struct NotetypeConversionsTests {
    // MARK: - Enum exhaustiveness

    @Test func NotetypeKind_round_trip_covers_all_cases() {
        for mirror in Notetype.Kind.allCases {
            #expect(Notetype.Kind(.init(mirror)) == mirror)
        }
    }

    @Test func CardRequirementKind_round_trip_covers_all_cases() {
        for mirror in Notetype.Config.CardRequirement.Kind.allCases {
            #expect(Notetype.Config.CardRequirement.Kind(.init(mirror)) == mirror)
        }
    }

    @Test func OriginalStockKind_round_trip_covers_all_cases() {
        for mirror in Notetype.Config.OriginalStockKind.allCases {
            #expect(Notetype.Config.OriginalStockKind(.init(mirror)) == mirror)
        }
    }

    @Test func UNRECOGNIZED_proto_kind_falls_back_to_default() {
        let unknown: Anki_Notetypes_Notetype.Config.Kind = .UNRECOGNIZED(99)
        #expect(Notetype.Kind(unknown) == .normal)
    }

    // MARK: - Field optional ord

    @Test func Field_unset_ord_decodes_to_nil() {
        let proto = Anki_Notetypes_Notetype.Field()
        let mirror = Notetype.Field(proto)
        #expect(mirror.ord == nil)
    }

    @Test func Field_set_ord_decodes_and_round_trips() {
        var proto = Anki_Notetypes_Notetype.Field()
        var ord = Anki_Generic_UInt32()
        ord.val = 3
        proto.ord = ord
        let mirror = Notetype.Field(proto)
        #expect(mirror.ord == 3)

        let reproto = mirror.toProto()
        #expect(reproto.hasOrd)
        #expect(reproto.ord.val == 3)
    }

    // MARK: - Field.Config optional id/tag

    @Test func Field_Config_optional_id_and_tag_round_trip() {
        var proto = Anki_Notetypes_Notetype.Field.Config()
        proto.id = 1234
        proto.tag = 7
        proto.fontName = "Helvetica"
        proto.description_p = "Front of card"

        let mirror = Notetype.Field.Config(proto)
        #expect(mirror.id == 1234)
        #expect(mirror.tag == 7)
        #expect(mirror.description == "Front of card")

        let reproto = mirror.toProto()
        #expect(reproto.hasID)
        #expect(reproto.id == 1234)
        #expect(reproto.hasTag)
        #expect(reproto.tag == 7)
        #expect(reproto.description_p == "Front of card")
    }

    @Test func Field_Config_unset_optionals_decode_to_nil() {
        let proto = Anki_Notetypes_Notetype.Field.Config()
        let mirror = Notetype.Field.Config(proto)
        #expect(mirror.id == nil)
        #expect(mirror.tag == nil)
    }

    // MARK: - Notetype round-trip

    @Test func full_Notetype_round_trip_preserves_fields_and_templates() throws {
        var proto = Anki_Notetypes_Notetype()
        proto.id = 9
        proto.name = "Basic"
        proto.config.kind = .normal
        proto.config.css = ".card { color: red; }"
        proto.config.originalStockKind = .basic

        var field = Anki_Notetypes_Notetype.Field()
        var ord = Anki_Generic_UInt32(); ord.val = 0
        field.ord = ord
        field.name = "Front"
        proto.fields = [field]

        var template = Anki_Notetypes_Notetype.Template()
        template.name = "Card 1"
        template.config.qFormat = "{{Front}}"
        template.config.aFormat = "{{Front}}<br>{{Back}}"
        proto.templates = [template]

        let mirror = Notetype(proto)
        #expect(mirror.id == NotetypeID(9))
        #expect(mirror.config.kind == .normal)
        #expect(mirror.config.originalStockKind == .basic)
        #expect(mirror.fields.count == 1)
        #expect(mirror.fields[0].name == "Front")
        #expect(mirror.templates.count == 1)
        #expect(mirror.templates[0].config.qFormat == "{{Front}}")

        let reproto = mirror.toProto()
        #expect(reproto.id == 9)
        #expect(reproto.fields.count == 1)
        #expect(reproto.fields[0].name == "Front")
        #expect(reproto.templates[0].config.aFormat == "{{Front}}<br>{{Back}}")
    }

    // MARK: - Request factories

    @Test func notetypeNames_dispatches_correctly() {
        let envelope: Request<[NotetypeNameId]> = .notetypeNames
        #expect(envelope.serviceId == ServiceID.notetypes)
        #expect(envelope.methodId == NotetypesMethod.getNotetypeNames)
    }

    @Test func notetype_for_dispatches_correctly() {
        let envelope: Request<Notetype> = .notetype(for: NotetypeID(42))
        #expect(envelope.serviceId == ServiceID.notetypes)
        #expect(envelope.methodId == NotetypesMethod.getNotetype)
    }

    @Test func updateNotetype_dispatches_correctly() {
        let envelope: Request<Void> = .updateNotetype(Notetype())
        #expect(envelope.serviceId == ServiceID.notetypes)
        #expect(envelope.methodId == NotetypesMethod.updateNotetype)
    }

    @Test func removeNotetype_dispatches_correctly() {
        let envelope: Request<Void> = .removeNotetype(id: NotetypeID(7))
        #expect(envelope.serviceId == ServiceID.notetypes)
        #expect(envelope.methodId == NotetypesMethod.removeNotetype)
    }
}
